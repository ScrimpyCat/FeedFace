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

#import "FFIvar.h"
#import "ObjcNewRuntime32.h"
#import "ObjcNewRuntime64.h"

#import "FFProcess.h"
#import "FFMemory.h"

#import "PropertyImpMacros.h"

@implementation FFIvar
{
    FFMemory *nameData, *typeData;
}

+(FFIvar*) ivarAtAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    return [[[FFIvar alloc] initWithIvarAtAddress: addr InProcess: proc] autorelease];
}

-(id) initWithIvarAtAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
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
    return [self initWithIvarAtAddress: addr InProcess: proc];
}

-(id) copyToAddress: (mach_vm_address_t)address InProcess: (FFProcess *)proc
{
    FFIvar *Ivar = [super copyToAddress: address InProcess: proc];
    
    Ivar.name = self.name;
    Ivar.type = self.type;
    
    //allocate space for offset
    FFMemory *Offset = [FFMemory allocateInProcess: proc WithSize: sizeof(uint64_t)];
    [proc writeAddress: Offset.address ToAddress: Ivar.address + PROC_OFFSET_OF(ivar_t, offset)];
    
    Ivar.offset = self.offset;
    
    
    return Ivar;
}

-(NSUInteger) dataSize
{
    return self.process.is64? sizeof(ivar_t64) : sizeof(ivar_t32);
}

-(mach_vm_address_t) offset
{
    const mach_vm_address_t Address = [self.process addressAtAddress: self.address + PROC_OFFSET_OF(ivar_t, offset)];
    const uint64_t *Offset = [self.process dataAtAddress: Address OfSize: sizeof(uint64_t)].bytes;
    
    return Offset? *Offset : 0;
}

-(void) setOffset: (mach_vm_address_t)offset
{
    const mach_vm_address_t Address = [self.process addressAtAddress: self.address + PROC_OFFSET_OF(ivar_t, offset)];
    [self.process writeData: &(uint64_t){ offset } OfSize: sizeof(uint64_t) ToAddress: Address];
}

STRING_TYPE_PROPERTY(name, setName, Address = self.address + PROC_OFFSET_OF(ivar_t, name))
STRING_TYPE_PROPERTY(type, setType, Address = self.address + PROC_OFFSET_OF(ivar_t, type))

-(uint32_t) alignment
{
    const uint32_t *Alignment = [self.process dataAtAddress: self.address + PROC_OFFSET_OF(ivar_t, alignment) OfSize: sizeof(uint32_t)].bytes;
    if (!Alignment) return 0;
    
    if (*Alignment == UINT32_MAX) return self.process.is64? 3 : 2;
    return 1 << *Alignment;
}

-(void) setAlignment: (uint32_t)alignment
{
    [self.process writeData: &alignment OfSize: sizeof(uint32_t) ToAddress: self.address + PROC_OFFSET_OF(ivar_t, alignment)];
}

DIRECT_TYPE_PROPERTY(uint32_t, size, setSize, Address = self.address + PROC_OFFSET_OF(ivar_t, size))

-(void) dealloc
{
    [nameData release]; nameData = nil;
    [typeData release]; typeData = nil;
    
    
    [super dealloc];
}

@end
