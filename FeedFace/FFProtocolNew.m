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

#import "FFProtocolNew.h"
#import "ObjcNewRuntime32.h"
#import "ObjcNewRuntime64.h"

#import "FFProcess.h"
#import "FFMemory.h"
#import "FFClassNew.h"
#import "FFMethod.h"
#import "FFProperty.h"

#import "PropertyImpMacros.h"

@implementation FFProtocolNew
{
    FFMemory *nameData;
    FFMemory *protocolsData ,*instanceMethodsData, *classMethodsData, *optionalInstanceMethodsData, *optionalClassMethodsData, *instancePropertiesData;
    FFMemory *extendedMethodTypesStringData, *extendedMethodTypesData;
}

-(id) copyToAddress: (mach_vm_address_t)address InProcess: (FFProcess *)proc
{
    FFProtocolNew *Protocol = [super copyToAddress: address InProcess: proc];
    Protocol.isa = self.isa;
    Protocol.name = self.name;
    Protocol.protocols = self.protocols;
    Protocol.instanceMethods = self.instanceMethods;
    Protocol.classMethods = self.classMethods;
    Protocol.optionalInstanceMethods = self.optionalInstanceMethods;
    Protocol.optionalClassMethods = self.optionalClassMethods;
    Protocol.instanceProperties = self.instanceProperties;
    Protocol.extendedMethodTypes = self.extendedMethodTypes;
    
    return Protocol;
}

-(NSUInteger) dataSize
{
    return self.process.is64? sizeof(protocol_t64) : sizeof(protocol_t32);
}

#define ADDRESS_IN_PROTOCOL(member) Address = self.address + PROC_OFFSET_OF(protocol_t, member)

POINTER_TYPE_PROPERTY(FFClassNew, isa, setIsa, ADDRESS_IN_PROTOCOL(isa))
STRING_TYPE_PROPERTY(name, setName, ADDRESS_IN_PROTOCOL(name))

-(NSArray*) protocols
{
    mach_vm_address_t Address = self.address + PROC_OFFSET_OF(protocol_t, protocols);;
    const mach_vm_address_t ListAddr = [self.process addressAtAddress: Address];
    const protocol_list_t *List = ListAddr? [self.process dataAtAddress: ListAddr OfSize: sizeof(protocol_list_t)].bytes : NULL;
    
    if (!List) return nil;
    
    const uint32_t TypeSize = self.process.is64? sizeof(uint64_t) : sizeof(uint32_t);
    NSMutableArray *Types = [NSMutableArray array];
    
    for (uint32_t Loop = 0; Loop < List->count; Loop++)
    {
        const mach_vm_address_t TypeAddress = (Loop * TypeSize) + (ListAddr + sizeof(protocol_list_t));
        FFProtocol *Type = [FFProtocol protocolAtAddress: [self.process addressAtAddress: TypeAddress] InProcess: self.process];
        if (Type) [Types addObject: Type];
    }
    
    return Types;
}

-(void) setProtocols: (NSArray *)protocols
{
    mach_vm_address_t Address = 0, DataHeaderAddr = 0;
    Address = self.address + PROC_OFFSET_OF(protocol_t, protocols);
    if (protocols)
    {
        const NSUInteger Count = [protocols count];
        const size_t Entsize = self.process.is64? sizeof(uint64_t) : sizeof(uint32_t);
        if (!protocolsData) protocolsData = [FFMemory allocateInProcess: self.process WithSize: Count * Entsize];
        else protocolsData.size = Count * Entsize;
        
        NSUInteger Index = 0;
        DataHeaderAddr = protocolsData.address;
        const mach_vm_address_t DataAddr = DataHeaderAddr + sizeof(protocol_list_t);
        for (FFProtocol *Type in protocols)
        {
            if ((Type = [Type injectTo: self.process]))
            {
                [self.process writeAddress: Type.address ToAddress: DataAddr + (Entsize * Index++)];
            }
        }
        
        [self.process writeData: &(protocol_list_t){ .count = (uint32_t)Index } OfSize: sizeof(protocol_list_t) ToAddress: DataHeaderAddr];
    }
    
    [self.process writeAddress: DataHeaderAddr ToAddress: Address];
}

ARRAY_OF_POINTER_TYPE_PROPERTY(FFMethod, instanceMethods, setInstanceMethods, method_list_t, entsize_NEVER_USE & ~(uint32_t)3, entsize_NEVER_USE = (uint32_t)Entsize | 3, ADDRESS_IN_PROTOCOL(instanceMethods))
ARRAY_OF_POINTER_TYPE_PROPERTY(FFMethod, classMethods, setClassMethods, method_list_t, entsize_NEVER_USE & ~(uint32_t)3, entsize_NEVER_USE = (uint32_t)Entsize | 3, ADDRESS_IN_PROTOCOL(classMethods))
ARRAY_OF_POINTER_TYPE_PROPERTY(FFMethod, optionalInstanceMethods, setOptionalInstanceMethods, method_list_t, entsize_NEVER_USE & ~(uint32_t)3, entsize_NEVER_USE = (uint32_t)Entsize | 3, ADDRESS_IN_PROTOCOL(optionalInstanceMethods))
ARRAY_OF_POINTER_TYPE_PROPERTY(FFMethod, optionalClassMethods, setOptionalClassMethods, method_list_t, entsize_NEVER_USE & ~(uint32_t)3, entsize_NEVER_USE = (uint32_t)Entsize | 3, ADDRESS_IN_PROTOCOL(optionalClassMethods))
ARRAY_OF_POINTER_TYPE_PROPERTY(FFProperty, instanceProperties, setInstanceProperties, property_list_t, entsize, entsize = (uint32_t)Entsize, ADDRESS_IN_PROTOCOL(instanceProperties))
DIRECT_TYPE_PROPERTY(uint32_t, size, setSize, ADDRESS_IN_PROTOCOL(size))
DIRECT_TYPE_PROPERTY(uint32_t, flags, setFlags, ADDRESS_IN_PROTOCOL(flags))

-(NSArray*) extendedMethodTypes
{
    //if (self.size >= [self dataSize])
    {
        mach_vm_address_t Address = [self.process addressAtAddress: self.address + PROC_OFFSET_OF(protocol_t, extendedMethodTypes)];
        NSMutableArray *ExtendedMethodTypes = nil;
        if (Address)
        {
            ExtendedMethodTypes = [NSMutableArray array];
            
            const size_t PointerSize = self.process.is64? sizeof(uint64_t) : sizeof(uint32_t);
            for (NSUInteger Loop = 0, Total = [self.instanceMethods count] + [self.classMethods count] + [self.optionalInstanceMethods count] + [self.optionalClassMethods count]; Loop < Total; Loop++)
            {
                const mach_vm_address_t StrAddr = [self.process addressAtAddress: Address + (PointerSize * Loop)];
                [ExtendedMethodTypes addObject: StrAddr? [self.process nullTerminatedStringAtAddress: StrAddr] : [NSNull null]];
            }
        }
        
        return ExtendedMethodTypes;
    }
    
    return nil;
}

-(void) setExtendedMethodTypes: (NSArray*)extendedMethodTypes
{
    mach_vm_address_t ExtendedMethodTypesAddr = 0;
    if (extendedMethodTypes)
    {
        NSMutableData *Data = [NSMutableData data];
        NSUInteger Index = 0, Count = [extendedMethodTypes count];
        mach_vm_address_t Strings[Count];
        memchr(Strings, 0, Count);
        for (id Val in extendedMethodTypes)
        {
            if ([Val isKindOfClass: [NSString class]])
            {
                Strings[Index++] = [Data length] + 1;
                [Data appendBytes: [Val UTF8String] length: [Val lengthOfBytesUsingEncoding: NSUTF8StringEncoding] + 1];
            }
            
            else Strings[Index++] = 0;
        }
        
        const size_t PointerSize = self.process.is64? sizeof(uint64_t) : sizeof(uint32_t);
        const NSUInteger Size = Count * PointerSize;
        if (!extendedMethodTypesData) extendedMethodTypesData = [FFMemory allocateInProcess: self.process WithSize: Size];
        else extendedMethodTypesData.size = Size;
        
        ExtendedMethodTypesAddr = extendedMethodTypesData.address;
        
        if (!extendedMethodTypesStringData) extendedMethodTypesStringData = [FFMemory allocateInProcess: self.process WithSize: [Data length]];
        else extendedMethodTypesStringData.size = [Data length];
        
        const mach_vm_address_t StringsAddr = extendedMethodTypesStringData.address - 1;
        for (NSUInteger Loop = 0; Loop < Count; Loop++)
        {
            [self.process writeAddress: Strings[Loop]? Strings[Loop] + StringsAddr : 0 ToAddress: ExtendedMethodTypesAddr + (PointerSize * Loop)];
        }
        
        [self.process write: Data ToAddress: StringsAddr + 1];
    }
    
    [self.process writeAddress: ExtendedMethodTypesAddr ToAddress: self.address + PROC_OFFSET_OF(protocol_t, extendedMethodTypes)];
}

-(void) dealloc
{
    [nameData release]; nameData = nil;
    [protocolsData release]; protocolsData = nil;
    [instanceMethodsData release]; instanceMethodsData = nil;
    [classMethodsData release]; classMethodsData = nil;
    [optionalInstanceMethodsData release]; optionalInstanceMethodsData = nil;
    [optionalClassMethodsData release]; optionalClassMethodsData = nil;
    [instancePropertiesData release]; instancePropertiesData = nil;
    [extendedMethodTypesStringData release]; extendedMethodTypesStringData = nil;
    [extendedMethodTypesData release]; extendedMethodTypesData = nil;
    
    [super dealloc];
}

@end
