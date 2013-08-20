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
    FFMemory *protocolData;
    FFMemory *instanceMethodData, *classMethodData;
}

-(id) copyToAddress: (mach_vm_address_t)address InProcess: (FFProcess *)proc
{
    FFProtocolOld *Protocol = [super copyToAddress: address InProcess: proc];
    
    Protocol.isa = self.isa;
    Protocol.name = self.name;
    Protocol.protocols = self.protocols;
    Protocol.instanceMethods = self.instanceMethods;
    Protocol.classMethods = self.classMethods;
    
    return Protocol;
}

-(NSUInteger) dataSize
{
    return self.process.is64? sizeof(old_protocol64) : sizeof(old_protocol32);
}

#define ADDRESS_IN_PROTOCOL(member) Address = self.address + PROC_OFFSET_OF(old_protocol, member)

POINTER_TYPE_PROPERTY(FFClassOld, isa, setIsa, ADDRESS_IN_PROTOCOL(isa))
STRING_TYPE_PROPERTY(name, setName, ADDRESS_IN_PROTOCOL(protocol_name))

-(NSArray*) protocols
{
    NSMutableArray *Protocols = [NSMutableArray array];
    
    mach_vm_address_t Address = self.address + PROC_OFFSET_OF(old_protocol, protocol_list);
    mach_vm_address_t ProtocolList = [self.process addressAtAddress: Address];
    if (!ProtocolList) return nil;
    
    const size_t ProtocolSize = self.process.is64? sizeof(old_protocol64) : sizeof(old_protocol32);
    
    for ( ; ProtocolList; ProtocolList = [self.process addressAtAddress: ProtocolList + PROC_OFFSET_OF(old_protocol_list, next)])
    {
        const void *ProtocolCount = [self.process dataAtAddress: ProtocolList + PROC_OFFSET_OF(old_protocol_list, count) OfSize: self.process.is64? sizeof(uint64_t) : sizeof(uint32_t)].bytes;
        if (!ProtocolCount) continue;
        
        const mach_vm_address_t CurrentProtocol = [self.process addressAtAddress: ProtocolList + PROC_OFFSET_OF(old_protocol_list, list)];
        for (size_t Loop = 0, Count = self.process.is64? *(uint64_t*)ProtocolCount : *(uint32_t*)ProtocolCount; Loop < Count; Loop++)
        {
            [Protocols addObject: [FFProtocol protocolAtAddress: CurrentProtocol + (Loop * ProtocolSize) InProcess: self.process]];
        }
    }
    
    
    return Protocols;
}

-(void) setProtocols: (NSArray*)protocols
{
    const mach_vm_address_t Address = self.address + PROC_OFFSET_OF(old_protocol, protocol_list);
    
    if (!protocols)
    {
        [self.process writeAddress: 0 ToAddress: Address];
        return;
    }
    
    const NSUInteger Count = [protocols count];
    const _Bool Is64 = self.process.is64;
    if (!protocolData) protocolData = [FFMemory allocateInProcess: self.process WithSize: Is64? sizeof(old_protocol_list64) + (sizeof(old_protocol64) * Count) : sizeof(old_protocol_list32) + (sizeof(old_protocol32) * Count)];
    else protocolData.size = Is64? sizeof(old_protocol_list64) + (sizeof(old_protocol64) * Count) : sizeof(old_protocol_list32) + (sizeof(old_protocol32) * Count);
    
    const mach_vm_address_t ProtocolDataHeaderAddr = protocolData.address;
    const mach_vm_address_t ProtocolDataAddr = ProtocolDataHeaderAddr + PROC_OFFSET_OF(old_protocol_list, list);
    const size_t Entsize = Is64? sizeof(old_protocol64) : sizeof(old_protocol32);
    
    NSUInteger Index = 0;
    for (FFProtocol *Protocol in protocols)
    {
        if ([Protocol copyToAddress: ProtocolDataAddr + (Entsize * Index) InProcess: self.process]) Index++;
    }
    
    
    [self.process writeAddress: 0 ToAddress: ProtocolDataHeaderAddr + PROC_OFFSET_OF(old_protocol_list, next)];
    [self.process writeData: Is64? (void*)&(uint64_t){ (uint64_t)Index } : (void*)&(uint32_t){ (uint32_t)Index } OfSize: Is64? sizeof(uint64_t) : sizeof(uint32_t) ToAddress: ProtocolDataHeaderAddr + PROC_OFFSET_OF(old_protocol_list, count)];
    
    [self.process writeAddress: ProtocolDataHeaderAddr ToAddress: Address];
}

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

-(void) setInstanceMethods: (NSArray*)instanceMethods
{
    const mach_vm_address_t Address = self.address + PROC_OFFSET_OF(old_protocol, instance_methods);
    
    if (!instanceMethods)
    {
        [self.process writeAddress: 0 ToAddress: Address];
        return;
    }
    
    const NSUInteger Count = [instanceMethods count];
    const _Bool Is64 = self.process.is64;
    if (!instanceMethodData) instanceMethodData = [FFMemory allocateInProcess: self.process WithSize: Is64? sizeof(objc_method_description_list64) + (sizeof(objc_method_description64) * Count) : sizeof(objc_method_description_list32) + (sizeof(objc_method_description32) * Count)];
    else instanceMethodData.size = Is64? sizeof(objc_method_description_list64) + (sizeof(objc_method_description64) * Count) : sizeof(objc_method_description_list32) + (sizeof(objc_method_description32) * Count);
    
    const mach_vm_address_t MethodDataHeaderAddr = instanceMethodData.address;
    const mach_vm_address_t MethodDataAddr = MethodDataHeaderAddr + PROC_OFFSET_OF(objc_method_description_list, list);
    const size_t Entsize = Is64? sizeof(objc_method_description64) : sizeof(objc_method_description32);
    
    NSUInteger Index = 0;
    for (FFMethod *Method in instanceMethods)
    {
        if ([Method copyToAddress: MethodDataAddr + (Entsize * Index) InProcess: self.process]) Index++;
    }
    
    
    [self.process writeData: &(uint32_t){ (uint32_t)Index } OfSize: sizeof(uint32_t) ToAddress: MethodDataHeaderAddr + PROC_OFFSET_OF(objc_method_description_list, count)];
    
    [self.process writeAddress: MethodDataHeaderAddr ToAddress: Address];
}

-(NSArray*) classMethods
{
    const mach_vm_address_t Address = self.address + PROC_OFFSET_OF(old_protocol, class_methods);
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

-(void) setClassMethods: (NSArray*)classMethods
{
    const mach_vm_address_t Address = self.address + PROC_OFFSET_OF(old_protocol, class_methods);
    
    if (!classMethods)
    {
        [self.process writeAddress: 0 ToAddress: Address];
        return;
    }
    
    const NSUInteger Count = [classMethods count];
    const _Bool Is64 = self.process.is64;
    if (!classMethodData) classMethodData = [FFMemory allocateInProcess: self.process WithSize: Is64? sizeof(objc_method_description_list64) + (sizeof(objc_method_description64) * Count) : sizeof(objc_method_description_list32) + (sizeof(objc_method_description32) * Count)];
    else classMethodData.size = Is64? sizeof(objc_method_description_list64) + (sizeof(objc_method_description64) * Count) : sizeof(objc_method_description_list32) + (sizeof(objc_method_description32) * Count);
    
    const mach_vm_address_t MethodDataHeaderAddr = classMethodData.address;
    const mach_vm_address_t MethodDataAddr = MethodDataHeaderAddr + PROC_OFFSET_OF(objc_method_description_list, list);
    const size_t Entsize = Is64? sizeof(objc_method_description64) : sizeof(objc_method_description32);
    
    NSUInteger Index = 0;
    for (FFMethod *Method in classMethods)
    {
        if ([Method copyToAddress: MethodDataAddr + (Entsize * Index) InProcess: self.process]) Index++;
    }
    
    
    [self.process writeData: &(uint32_t){ (uint32_t)Index } OfSize: sizeof(uint32_t) ToAddress: MethodDataHeaderAddr + PROC_OFFSET_OF(objc_method_description_list, count)];
    
    [self.process writeAddress: MethodDataHeaderAddr ToAddress: Address];
}

-(void) dealloc
{
    [nameData release]; nameData = nil;
    [protocolData release]; protocolData = nil;
    [instanceMethodData release]; instanceMethodData = nil;
    [classMethodData release]; classMethodData = nil;
    
    [super dealloc];
}

@end
