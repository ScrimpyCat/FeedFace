/*
 *  Copyright (c) 2012, Stefan Johnson                                                  
 *  All rights reserved.                                                                
 *                                                                                      
 *  Redistribution and use in source and binary forms, with or without modification,    
 *  are permitted provided that the following conditions are met:                       
 *                                                                                      
 *  1. Redistributions of source code must retain the above copyright notice, this list 
 *     of conditions and the following disclaimer.                                      
 *  2. Redistributions in binary form must reproduce the above copyright notice, this   
 *     list of conditions and the following disclaimer in the documentation and/or other
 *     materials provided with the distribution.                                        
 *  
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "FFProcessPrivate.h"
#import "FFRegion.h"
#import "FFClass.h"
#import "NSValue+MachVMAddress.h"
#import "FFImage.h"

#import <mach-o/loader.h>

static mach_vm_address_t FindClosestAddressInArray(NSArray *Array, mach_vm_address_t TargetAddress)
{
    /*
     Would make more sense to have as NSArray category and just make user do:
     [[foo findData: NULL OfSize: 0] addressClosestTo: ]
     but I want to try avoid cluttering non-FeedFace classes (to try avoid collisions) and since I may optimize ClosestTo's later, 
     so they don't do full scan.
     
     So this is just a temporary thing till then
     */
    
    __block mach_vm_address_t ClosestAddress = 0;
    __block int64_t Dist = INT64_MAX;
    const NSUInteger Count = [Array count];
    
    if (Count)
    {
        ClosestAddress = [[Array objectAtIndex: 0] addressValue];
        Dist = llabs(ClosestAddress - TargetAddress);
        [Array enumerateObjectsAtIndexes: [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(1, Count - 1)] options: 0 usingBlock: ^(id obj, NSUInteger idx, BOOL *stop){
            const mach_vm_address_t Address = [obj addressValue];
            const int64_t NewDist = llabs(Address - TargetAddress);
            if (NewDist < Dist)
            {
                ClosestAddress = Address;
                Dist = NewDist;
            }
        }];
    }
    
    else printf("Empty array, no address close to target\n");
    
    
    return ClosestAddress;
}

@implementation FFProcess (Scanning)

-(NSArray*) findData: (const void*)data OfSize: (NSUInteger)size
{
    if ((!data) || (!size)) return nil;
    
    NSMutableArray *Occurrences = [NSMutableArray array];
    NSArray *Regions = [self regions];
    
    for (FFRegion *Region in Regions)
    {
        /*
         Not sure if should "stitch" multiple region's maps together if they're 
         touching.
         */
        const void *Data = [Region map];
        if (Data)
        {
            for (NSUInteger Loop = 0, Count = Region.size - size > Region.size? 0 : Region.size - size; Loop < Count; Loop++)
            {
                if (!memcmp(Data + Loop, data, size))
                {
                    [Occurrences addObject: [NSValue valueWithAddress: (Region.address + Loop)]];
                }
            }
        }
    }
    
    return Occurrences;
}

-(NSArray*) find: (NSData*)data
{
    return [self findData: data.bytes OfSize: [data length]];
}

-(NSArray*) findLoadCommandForSegment: (NSString*)segment
{
    NSArray *Addresses = [self images];
    NSMutableArray *Occurrences = [NSMutableArray arrayWithCapacity: [Addresses count]];
    for (NSValue *Image in Addresses)
    {
        const mach_vm_address_t ImageAddress = [Image addressValue];
        mach_vm_address_t Addr;
        if (FFImageInProcessContainsSegment(self, ImageAddress, segment, &Addr, NULL))
        {
            [Occurrences addObject: [NSValue valueWithAddress: Addr]];
        }
        
    }
    
    return Occurrences;
}

-(NSArray*) findSegment: (NSString*)segment
{
    NSArray *Addresses = [self images];
    NSMutableArray *Occurrences = [NSMutableArray arrayWithCapacity: [Addresses count]];
    for (NSValue *Image in Addresses)
    {
        const mach_vm_address_t ImageAddress = [Image addressValue];
        mach_vm_address_t Addr;
        if (FFImageInProcessContainsSegment(self, ImageAddress, segment, NULL, &Addr))
        {
            [Occurrences addObject: [NSValue valueWithAddress: [self relocateAddress: Addr InImageAtAddress: ImageAddress]]];
        }
        
    }
    
    return Occurrences;
}

-(NSArray*) findLoadCommandForSegment: (NSString*)segment Section: (NSString*)section
{
    NSArray *Addresses = [self images];
    NSMutableArray *Occurrences = [NSMutableArray arrayWithCapacity: [Addresses count]];
    for (NSValue *Image in Addresses)
    {
        const mach_vm_address_t ImageAddress = [Image addressValue];
        mach_vm_address_t Addr;
        if (FFImageInProcessContainsSection(self, ImageAddress, segment, section, &Addr, NULL))
        {
            [Occurrences addObject: [NSValue valueWithAddress: Addr]];
        }
        
    }
    
    return Occurrences;
}

-(NSArray*) findSegment: (NSString*)segment Section: (NSString*)section
{
    NSArray *Addresses = [self images];
    NSMutableArray *Occurrences = [NSMutableArray arrayWithCapacity: [Addresses count]];
    for (NSValue *Image in Addresses)
    {
        const mach_vm_address_t ImageAddress = [Image addressValue];
        mach_vm_address_t Addr;
        if (FFImageInProcessContainsSection(self, ImageAddress, segment, section, NULL, &Addr))
        {
            [Occurrences addObject: [NSValue valueWithAddress: [self relocateAddress: Addr InImageAtAddress: ImageAddress]]];
        }
        
    }
    
    return Occurrences;
}

-(NSArray*) ownClasses
{
    NSMutableArray *ClassList = [NSMutableArray array];
    
    if (self.usesNewRuntime)
    {
        NSData *ClassListData = [self dataForSegment: @"__DATA" Section: @"__objc_classlist" InImage: self.name];
        if (self.is64)
        {
            const uint64_t *Classes = ClassListData.bytes;
            for (NSUInteger Loop = 0, Count = [ClassListData length] / sizeof(uint64_t); Loop < Count; Loop++)
            {
                [ClassList addObject: [NSValue valueWithAddress: Classes[Loop]]];
            }
        }
        
        else
        {
            const uint32_t *Classes = ClassListData.bytes;
            for (NSUInteger Loop = 0, Count = [ClassListData length] / sizeof(uint32_t); Loop < Count; Loop++)
            {
                [ClassList addObject: [NSValue valueWithAddress: Classes[Loop]]];
            }
        }
    }
    
    else
    {
        NSData *ClassListData = [self dataForSegment: @"__OBJC" Section: @"__symbols" InImage: self.name];
        if (self.is64)
        {
            const struct objc_symtab64 {
                uint32_t sel_ref_cnt;
                uint64_t refs;
                uint16_t cls_def_cnt;
                uint16_t cat_def_cnt;
                uint64_t defs;
            } *Symtab = ClassListData.bytes;
            
            for (int Loop = 0; Loop < Symtab->cls_def_cnt; Loop++)
            {
                [ClassList addObject: [NSValue valueWithAddress: ((uint64_t*)&Symtab->defs)[Loop]]];
            }
        }
        
        else
        {
            const struct objc_symtab32 {
                uint32_t sel_ref_cnt;
                uint32_t refs;
                uint16_t cls_def_cnt;
                uint16_t cat_def_cnt;
                uint32_t defs;
            } *Symtab = ClassListData.bytes;
            
            for (int Loop = 0; Loop < Symtab->cls_def_cnt; Loop++)
            {
                [ClassList addObject: [NSValue valueWithAddress: ((uint32_t*)&Symtab->defs)[Loop]]];
            }
        }
    }
    
    return ClassList;
}

-(NSArray*) referencedClasses
{
    NSMutableArray *ClassList = [NSMutableArray array];
    
    
    NSData *ClassListData = self.usesNewRuntime? [self dataForSegment: @"__DATA" Section: @"__objc_classrefs" InImage: self.name] : [self dataForSegment: @"__OBJC" Section: @"__cls_refs" InImage: self.name];
    if (self.is64)
    {
        const uint64_t *Classes = ClassListData.bytes;
        for (NSUInteger Loop = 0, Count = [ClassListData length] / sizeof(uint64_t); Loop < Count; Loop++)
        {
            [ClassList addObject: [NSValue valueWithAddress: Classes[Loop]]];
        }
    }
    
    else
    {
        const uint32_t *Classes = ClassListData.bytes;
        for (NSUInteger Loop = 0, Count = [ClassListData length] / sizeof(uint32_t); Loop < Count; Loop++)
        {
            [ClassList addObject: [NSValue valueWithAddress: Classes[Loop]]];
        }
    }
    
    return ClassList;
}

-(NSArray*) classes
{
    /*
     Need to change it so it will get all available classes, this will require finding the realized classes.
     Since the hash table of them is private and not a symbol, then it's unlikely there will be an easy way of finding it. Which leaves
     two options, the first is to go through all code (down the list of functions, from the public to the private) till we reach one
     that uses it and then try and locate it there (e.g. going down to realizedClasses() and then finding address to 
     realized_class_hash). However that is unlikely to work well/difficult to implement.
     
     Second option is to inject code into the target to query the class list and then that data back to here.
     */
    
    /*
     Edit: added cheap hack to get more of the classes (making use of the subclass feature in class). As it would work it's way up to NSObject (or
     other root Classes from the referencedClasses) and then down to all subclasses. Though still not accurate as there could be those which aren't
     subclasses of NSObject or any of its subclasses, or subclasses of the other root classes that are referenced or subclassed.
     
     It also is expensive, as it will force the creation of FFClass's, which would otherwise be best to avoid unless user specifically forces
     FFClass creation/wants one.
     
     It's also not a viable approach for the old runtime, as they don't provide the functionality to query all subclasses.
     
     So only a temporary solution until thread injection is working.
     */
    
    for (NSValue *ClassAddress in [self referencedClasses]) [self classAtAddress: [ClassAddress addressValue]];
    
    NSMutableArray *Classes = [NSMutableArray array];
    for (FFClass *Cls in [FFClass classesExposedForProcess: self])
    {
        [Classes addObject: [NSValue valueWithAddress: Cls.address]];
    }
    
    
    return Classes;
}

-(id) classWithName: (NSString*)name WantMetaClass: (_Bool)wantMeta
{
    NSArray *Classes = [self classesWithName: name];
    const NSUInteger Index = [Classes indexOfObjectPassingTest: ^BOOL(FFClass *obj, NSUInteger idx, BOOL *stop){
        return obj.isMetaClass == wantMeta;
    }];
    
    return Index != NSNotFound? [Classes objectAtIndex: Index] : nil;
}

-(NSArray*) classesWithName: (NSString*)name
{
    NSMutableArray *Occurrences = [NSMutableArray array];
    for (NSValue *ClassAddress in [self findClass: name])
    {
        FFClass *Cls = [self classAtAddress: [ClassAddress addressValue]];
        if (Cls) [Occurrences addObject: Cls];
    }
    
    return Occurrences;
}

-(NSArray*) findClass: (NSString*)classname
{
    NSMutableArray *Occurrences = [NSMutableArray array];
    for (NSValue *ClassAddress in [self classes])
    {
        const mach_vm_address_t Address = [ClassAddress addressValue];
        if ([classname isEqualToString: [self nameOfObject: Address]]) [Occurrences addObject: ClassAddress];
    }
    
    return Occurrences;
}

-(NSArray*) findInstanceOfClass: (NSString*)classname
{    
    NSMutableArray *Occurrences = [NSMutableArray array];
    for (NSValue *ClassAddress in [self classes])
    {
        const mach_vm_address_t Address = [ClassAddress addressValue];
        if ([classname isEqualToString: [self nameOfObject: Address]])
        {
            for (NSValue *ObjectsOfClass in [self findData: &Address OfSize: sizeof(uint64_t)])
            {
                [Occurrences addObject: ObjectsOfClass];
            }
        }
    }
    
    return Occurrences;
}

-(NSArray*) findCString: (const char*)string
{
    return [self findData: string OfSize: strlen(string) + 1];
}

-(NSArray*) findAddress: (mach_vm_address_t)address
{
    const _Bool Is64 = self.is64;
    return [self find: [NSData dataWithBytes: Is64? (void*)&(uint64_t){ address } : (void*)&(uint32_t){ (uint32_t)address } length: Is64? sizeof(uint64_t) : sizeof(uint32_t)]];
}

-(mach_vm_address_t) findData: (const void*)data OfSize: (NSUInteger)size ClosestTo: (mach_vm_address_t)targetAddress
{
    return FindClosestAddressInArray([self findData: data OfSize: size], targetAddress);
}

-(mach_vm_address_t) findCString: (const char*)string ClosestTo: (mach_vm_address_t)targetAddress
{
    return FindClosestAddressInArray([self findCString: string], targetAddress);
}

@end
