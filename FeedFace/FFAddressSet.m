/*
 *  Copyright (c) 2013, Stefan Johnson                                                  
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

#import "FFAddressSet.h"
#import "NSValue+MachVMAddress.h"

/*
 A simple yet unoptimal implementation. Won't reorder/restructure the current addresses when more are added (so possibly duplicates), and will perform
 a naive comparison for the -containsAddress: method.
 */

@interface FFAddressSet ()

@property (nonatomic, readonly) NSMutableArray *addresses;

@end

@implementation FFAddressSet
{
    NSMutableArray *addresses;
}

@synthesize addresses;

+(id) addressSet
{
    return [[[self class] new] autorelease];
}

+(id) addressSetWithAddress: (mach_vm_address_t)addr
{
    return [[[[self class] alloc] initWithAddress: addr] autorelease];
}

+(id) addressSetWithAddressesInRange: (FFAddressRange)range
{
    return [[[[self class] alloc] initWithAddressesInRange: range] autorelease];
}

+(id) addressSetWithAddressSet: (FFAddressSet*)set
{
    return [[[[self class] alloc] initWithAddressSet: set] autorelease];
}

-(id) init
{
    if ((self = [super init]))
    {
        addresses = [NSMutableArray new];
    }
    
    return self;
}

-(id) initWithAddress: (mach_vm_address_t)addr
{
    if ([self init])
    {
        [addresses addObject: [NSValue valueWithAddress: addr]];
    }
    
    return self;
}

-(id) initWithAddressesInRange: (FFAddressRange)range
{
    if ([self init])
    {
        [addresses addObject: [NSValue valueWithBytes: &range objCType: @encode(FFAddressRange)]];
    }
    
    return self;
}

-(id) initWithAddressSet: (FFAddressSet*)set
{
    if ((self = [super init]))
    {
        addresses = [set.addresses mutableCopy];
    }
    
    return self;
}

-(id) copyWithZone: (NSZone*)zone
{
    return [[[self class] allocWithZone: zone] initWithAddressSet: self];
}

-(void) addAddress: (mach_vm_address_t)addr
{
    [addresses addObject: [NSValue valueWithAddress: addr]];
}

-(void) addAddressesInRange: (FFAddressRange)range
{
    [addresses addObject: [NSValue valueWithBytes: &range objCType: @encode(FFAddressRange)]];
}

-(_Bool) containsAddress: (mach_vm_address_t)addr
{
    for (NSValue *Current in addresses)
    {
        if (!strcmp([Current objCType], @encode(FFAddressRange)))
        {
            FFAddressRange Range;
            [Current getValue: &Range];
            
            if ((addr >= Range.start) && (addr <= Range.end)) return YES;
        }
        
        else if ([Current addressValue] == addr) return YES; //assume address
    }
    
    return NO;
}

-(void) dealloc
{
    [addresses release]; addresses = nil;
    
    [super dealloc];
}

@end
