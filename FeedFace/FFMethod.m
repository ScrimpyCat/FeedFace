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

#import "FFMethod.h"
#import "ObjcNewRuntime32.h"
#import "ObjcNewRuntime64.h"

#import "FFProcess.h"
#import "FFMemory.h"

#import "PropertyImpMacros.h"

@implementation FFMethod
{
    FFMemory *nameData, *typesData;
}

+(FFMethod*) methodAtAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    return [[[FFMethod alloc] initWithMethodAtAddress: addr InProcess: proc] autorelease];
}

-(id) initWithMethodAtAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    if (!addr)
    {
        [self release];
        return nil;
    }
    
    if ((self = [super initWithAddress: addr InProcess: proc]))
    {
        
    }
    
    return self;
}

-(id) initWithAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    return [self initWithMethodAtAddress: addr InProcess: proc];
}

-(id) copyToAddress: (mach_vm_address_t)address InProcess: (FFProcess *)proc
{
    FFMethod *Method = [super copyToAddress: address InProcess: proc];
    Method.name = self.name;
    Method.types = self.types;
    
    /*
     If process is same, then copying imp is simple, if process is a different kind then don't allow copying of the imp, if they're the same kind
     then attempt to copy the imp. Will need to think about best way to implement this, as trying to handle it all myself is difficult as the 
     function could be split about around the binary (jumping around), some may actually return in functions they call, think about how to fix up
     memory references, and a lot more etc.
     
     May be best to set up a global callback, for the user to implement how to copy?
     */
    
    return Method;
}

-(NSUInteger) dataSize
{
    return self.process.is64? sizeof(method_t64) : sizeof(method_t32);
}

-(NSString*) name
{
    return [self.process nullTerminatedStringAtAddress: [self.process addressAtAddress: self.address + PROC_OFFSET_OF(method_t, name)]];
}

-(void) setName: (NSString*)name
{
    mach_vm_address_t NameAddr = 0; //So if name is nil, it will be the same as setting the name member to NULL
    if (name)
    {
        NSUInteger Size = [name lengthOfBytesUsingEncoding: NSUTF8StringEncoding] + 1;
        if (!nameData) nameData = [FFMemory allocateInProcess: self.process WithSize: Size];
        else nameData.size = Size;
        
        [self.process writeData: [name UTF8String] OfSize: nameData.size ToAddress: nameData.address];
        NameAddr = nameData.address;
    }
    
    
    //NSLog(@"Not implemented");
    /*
     Need to inject a thread to call _sel_registerName(NameAddr), and pass back the pointer
     then write that pointer
     */
    //[self.process writeAddress: NameAddr ToAddress: self.address + PROC_OFFSET_OF(method_t, name)];
}

STRING_TYPE_PROPERTY(types, setTypes, Address = self.address + PROC_OFFSET_OF(method_t, types))
ADDRESS_TYPE_PROPERTY(imp, setImp, Address = self.address + PROC_OFFSET_OF(method_t, imp))

-(void) dealloc
{
    [nameData release]; nameData = nil;
    [typesData release]; typesData = nil;
    
    
    [super dealloc];
}

@end
