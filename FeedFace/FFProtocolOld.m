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

#import "FFProtocolOld.h"
#import "ObjcOldRuntime32.h"
#import "ObjcOldRuntime64.h"
#import "FFProcess.h"
#import "FFMemory.h"
#import "FFClassOld.h"
#import "FFMethod.h"

#import "PropertyImpMacros.h"

@implementation FFProtocolOld
{
    FFMemory *nameData;
}

#define ADDRESS_IN_PROTOCOL(member) Address = self.address + PROC_OFFSET_OF(old_protocol, member)

POINTER_TYPE_PROPERTY(FFClassOld, isa, setIsa, ADDRESS_IN_PROTOCOL(isa))
STRING_TYPE_PROPERTY(name, setName, ADDRESS_IN_PROTOCOL(protocol_name))

//protocol list

-(NSArray*) instanceMethods
{
    const mach_vm_address_t Address = self.address + PROC_OFFSET_OF(old_protocol, instance_methods);
    const mach_vm_address_t MethodDescriptionList = [self.process addressAtAddress: Address];
    if (!MethodDescriptionList) return nil;
    
    NSMutableArray *Methods = [NSMutableArray array];
    
    const uint32_t *MethodDescriptionCount = [self.process dataAtAddress: MethodDescriptionList + PROC_OFFSET_OF(objc_method_description_list, count) OfSize: sizeof(uint32_t)].bytes;
    if (!MethodDescriptionCount) return nil;
    
    const size_t MethodDescriptionSize = self.process.is64? sizeof(objc_method_description64) : sizeof(objc_method_description32);
    const mach_vm_address_t MethodDescriptions = MethodDescriptionList + PROC_OFFSET_OF(objc_method_description_list, list);
    for (size_t Loop = 0, Count = *MethodDescriptionCount; Loop < Count; Loop++)
    {
        [Methods addObject: [FFMethod methodAtAddress: MethodDescriptions + (Loop * MethodDescriptionSize) InProcess: self.process]];
    }
    
    
    return Methods;
}

//class methods

-(void) dealloc
{
    [nameData release]; nameData = nil;
    
    [super dealloc];
}

@end
