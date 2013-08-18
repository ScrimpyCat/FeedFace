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

#import "FFIvarOld.h"
#import "ObjcOldRuntime32.h"
#import "ObjcOldRuntime64.h"
#import "FFProcess.h"
#import "FFMemory.h"

#import "PropertyImpMacros.h"

@implementation FFIvarOld
{
    FFMemory *nameData, *typeData;
}

-(mach_vm_address_t) offset
{
    const mach_vm_address_t Address = self.address + PROC_OFFSET_OF(old_ivar, ivar_offset);
    const uint32_t *Offset = [self.process dataAtAddress: Address OfSize: sizeof(uint32_t)].bytes;
    
    return Offset? *Offset : 0;
}

-(void) setOffset: (mach_vm_address_t)offset
{
    const mach_vm_address_t Address = self.address + PROC_OFFSET_OF(old_ivar, ivar_offset);
    [self.process writeData: &(uint32_t){ (uint32_t)offset } OfSize: sizeof(uint32_t) ToAddress: Address];
}

STRING_TYPE_PROPERTY(name, setName, Address = self.address + PROC_OFFSET_OF(old_ivar, ivar_name))
STRING_TYPE_PROPERTY(type, setType, Address = self.address + PROC_OFFSET_OF(old_ivar, ivar_type))

-(void) dealloc
{
    [nameData release]; nameData = nil;
    [typeData release]; typeData = nil;
    
    
    [super dealloc];
}

@end
