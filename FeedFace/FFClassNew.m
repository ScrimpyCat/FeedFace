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

#import "FFClassNew.h"
#import "FFProcess.h"
#import "NSValue+MachVMAddress.h"
#import "ObjcNewRuntime32.h"
#import "ObjcNewRuntime64.h"
#import <objc/runtime.h>

#import "FFMemory.h"

#import "FFCache.h"
#import "FFIvar.h"
#import "FFProperty.h"
#import "FFProtocol.h"
#import "FFMethod.h"

#import <mach/mach.h>
#import <mach/mach_vm.h>

#import "PropertyImpMacros.h"


@interface FFClassNew ()
{
    FFMemory *nameData;
    FFMemory *methodsData, *methodListData;
    FFMemory *propertyListData;
    FFMemory *baseMethodsData;
    FFMemory *ivarsData;
    FFMemory *basePropertiesData;
    FFMemory *baseProtocolsData;
    FFMemory *protocolsData, *protocolsListData;
    FFMemory *ivarLayoutData;
    FFMemory *weakIvarLayoutData;
    FFMemory *vtableData;
}

-(void) expose;

@end

@implementation FFClassNew

-(NSUInteger) dataSize
{
    const _Bool HasRW = self.rw, HasRO = self.ro; //Should have RO, unless error or was modified.
    return self.process.is64? sizeof(class_t64) + (HasRW? sizeof(class_rw_t64) : 0) + (HasRO? sizeof(class_ro_t64) : 0) : sizeof(class_t32) + (HasRW? sizeof(class_rw_t32) : 0) + (HasRO? sizeof(class_ro_t32) : 0) + 0x20;
}

-(id) copyToAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    /*
     All subsequent calls after FirstCopy must remain on same thread.
     */
    
    _Bool FirstCopy = NO;
    static NSMapTable * volatile CopiedTables = nil;
    if (!CopiedTables)
    {
        if (OSAtomicCompareAndSwapPtrBarrier(nil, [NSMapTable mapTableWithStrongToStrongObjects], (void**)&CopiedTables)) [CopiedTables retain];
    }
    
    NSThread *CurrentThread = [NSThread currentThread];
    NSMutableDictionary *CopiedTable = [CopiedTables objectForKey: CurrentThread];
    if ((!CopiedTable) || ((id)CopiedTable == [NSNull null]))
    {
        CopiedTable = [NSMutableDictionary dictionary];
        [CopiedTables setObject: CopiedTable forKey: CurrentThread];
        FirstCopy = YES;
    }
    
    FFClass *CopiedClass = [CopiedTable objectForKey: [NSValue valueWithAddress: self.address]];
    if (CopiedClass) return CopiedClass;
    
    
    const _Bool Is64 = self.process.is64, HasRW = self.rw, HasRO = self.ro;
    NSMutableData *Data = [[[self.process dataAtAddress: self.address OfSize: Is64? sizeof(class_t64) : sizeof(class_t32)] mutableCopy] autorelease];
    
    //move rw and ro so they both sit on 0xnnnnnnn0 memory (so they have bits that won't conflict with them if modified with the data_NEVER_USE flags)
    unsigned int OffsetRW = 0, OffsetRO = 0;
    if (HasRW)
    {
        const NSUInteger Length = [Data length];
        OffsetRW = (0x10 - (Length & 0xf)) & 0xf;
        if (OffsetRW) [Data increaseLengthBy: OffsetRW];
        [Data appendData: [self.process dataAtAddress: self.rw OfSize: Is64? sizeof(class_rw_t64) : sizeof(class_rw_t32)]];
    }
    if (HasRO)
    {
        const NSUInteger Length = [Data length];
        OffsetRO = (0x10 - (Length & 0xf)) & 0xf;
        if (OffsetRO) [Data increaseLengthBy: OffsetRO];
        [Data appendData: [self.process dataAtAddress: self.ro OfSize: Is64? sizeof(class_ro_t64) : sizeof(class_ro_t32)]];
    }
    
    
    //NULL out all members used in -expose
    void *Cls = Data.mutableBytes;
    if (!Cls) return nil;
    if (Is64)
    {
        ((class_t64*)Cls)->isa = 0;
        ((class_t64*)Cls)->superclass = 0;
        ((class_t64*)Cls)->data_NEVER_USE = 0;
        if (HasRW)
        {
            Cls += sizeof(class_t64) + OffsetRW;
            ((class_rw_t64*)Cls)->firstSubclass = 0;
            ((class_rw_t64*)Cls)->nextSiblingClass = 0;
        }
    }
    
    else
    {
        ((class_t32*)Cls)->isa = 0;
        ((class_t32*)Cls)->superclass = 0;
        ((class_t32*)Cls)->data_NEVER_USE = 0;
        if (HasRW)
        {
            Cls += sizeof(class_t32) + OffsetRW;
            ((class_rw_t32*)Cls)->firstSubclass = 0;
            ((class_rw_t32*)Cls)->nextSiblingClass = 0;
        }
    }
    
    [proc write: Data ToAddress: addr];
    
    
    FFClassNew *ClassCopy = [[self class] classAtAddress: addr InProcess: proc];
    [CopiedTable setObject: ClassCopy forKey: [NSValue valueWithAddress: self.address]];
    if (HasRW)
    {
        ClassCopy.rw = addr + (Is64? sizeof(class_t64) : sizeof(class_t32)) + OffsetRW;
        ClassCopy.methods = self.methods;
        ClassCopy.properties = self.properties;
        ClassCopy.protocols = self.protocols;
        //ClassCopy.firstSubclass = self.firstSubclass;
        //ClassCopy.nextSiblingClass = self.nextSiblingClass;
    }
    
    if (HasRO)
    {
        ClassCopy.ro = addr + (Is64? sizeof(class_t64) + (HasRW? sizeof(class_rw_t64) : 0) : sizeof(class_t32) + (HasRW? sizeof(class_ro_t64) : 0)) + OffsetRW + OffsetRO;
        ClassCopy.ivarLayout = self.ivarLayout;
        ClassCopy.name = self.name;
        ClassCopy.baseMethods = self.baseMethods;
        ClassCopy.baseProtocols = self.baseProtocols;
        ClassCopy.ivars = self.ivars;
        ClassCopy.weakIvarLayout = self.weakIvarLayout;
        ClassCopy.baseProperties = self.baseProperties;
    }
    
    ClassCopy.isa = self.isa;
    ClassCopy.superclass = self.superclass;
    ClassCopy.cache = self.cache;
    ClassCopy.vtable = self.vtable;
    ClassCopy.data_NEVER_USE = ClassCopy.data_NEVER_USE | (self.data_NEVER_USE & 3); //If it wrote to rw or ro (if no rw), then data_NEVER_USE would lose bits used for flags incase they were set originally
    
    if (FirstCopy)
    {
        [CopiedTables setObject: [NSNull null] forKey: CurrentThread];
    }
    
    
    return ClassCopy;
}

-(void) expose
{
    [self isa];
    [self superclass];
    [self firstSubclass];
    [self nextSiblingClass];
}

#define ADDRESS_IN_CLASS(member) Address = self.address + PROC_OFFSET_OF(class_t, member);
#define ADDRESS_IN_CLASS_RO(member) Address = self.ro + PROC_OFFSET_OF(class_ro_t, member);
#define ADDRESS_IN_CLASS_RW(member) \
if (!self.rw) goto Failure; \
Address = self.rw + PROC_OFFSET_OF(class_rw_t, member);

//class_t
POINTER_TYPE_PROPERTY(FFClassNew, isa, setIsa, ADDRESS_IN_CLASS(isa))
POINTER_TYPE_PROPERTY(FFClassNew, superclass, setSuperclass, ADDRESS_IN_CLASS(superclass))
POINTER_TYPE_PROPERTY(FFCache, cache, setCache, ADDRESS_IN_CLASS(cache))

-(NSArray*) vtable
{
    const mach_vm_address_t VTableAddr = [self.process addressAtAddress: self.address + PROC_OFFSET_OF(class_t, vtable)];
    
    const size_t PointerSize = self.process.is64? sizeof(uint64_t) : sizeof(uint32_t);
    NSValue *Imps[16];
    for (int Loop = 0; Loop < 16; Loop++)
    {
        Imps[Loop] = [NSValue valueWithAddress: [self.process addressAtAddress: VTableAddr + (Loop * PointerSize)]];
    }
    
    return [NSArray arrayWithObjects: Imps count: 16];
}

-(void) setVtable: (NSArray*)vtable
{
    if ([vtable count] != 16) return;
    
    const size_t PointerSize = self.process.is64? sizeof(uint64_t) : sizeof(uint32_t);    
    if (!vtableData) vtableData = [FFMemory allocateInProcess: self.process WithSize: PointerSize * 16];
    
    const mach_vm_address_t VTableAddr = vtableData.address;
    
    
    int Loop = 0;
    for (NSValue *Imp in vtable)
    {
        [self.process writeAddress: [Imp addressValue] ToAddress: VTableAddr + (Loop++ * PointerSize)];
    }
    
    [self.process writeAddress: VTableAddr ToAddress: self.address + PROC_OFFSET_OF(class_t, vtable)];
}

ADDRESS_TYPE_PROPERTY(data_NEVER_USE, setData_NEVER_USE, ADDRESS_IN_CLASS(data_NEVER_USE))

-(mach_vm_address_t) rw
{
    mach_vm_address_t Address = self.data_NEVER_USE & ~(mach_vm_address_t)3;
    if (!Address) return 0;
    const uint32_t *Flags = [self.process dataAtAddress: Address + PROC_OFFSET_OF(class_rw_t, flags) OfSize: sizeof(uint32_t)].bytes;
    if ((Flags) && (*Flags & RW_REALIZED)) return Address;
    else return 0;
}

-(void) setRw: (mach_vm_address_t)rw
{
    self.data_NEVER_USE = rw;
}

//class_rw_t
DIRECT_TYPE_PROPERTY(uint32_t, rwFlags, setRwFlags, ADDRESS_IN_CLASS_RW(flags))
DIRECT_TYPE_PROPERTY(uint32_t, version, setVersion, ADDRESS_IN_CLASS_RW(version))

-(mach_vm_address_t) ro
{
    mach_vm_address_t RW = self.rw;
    if (RW) return [self.process addressAtAddress: RW + PROC_OFFSET_OF(class_rw_t, ro)];
    else return self.data_NEVER_USE & ~(mach_vm_address_t)3;
}

-(void)setRo: (mach_vm_address_t)ro
{
    mach_vm_address_t RW = self.rw;
    if (RW)
    {
        [self.process writeAddress: ro ToAddress: RW + PROC_OFFSET_OF(class_rw_t, ro)];
    }
    
    else
    {
        self.data_NEVER_USE = ro;
    }
}

-(NSArray*) methods
{
    NSMutableArray *Methods = [NSMutableArray array];
    
    if (!self.rw) return nil;
    mach_vm_address_t Address = self.rw + PROC_OFFSET_OF(class_rw_t, method_list);
    
    mach_vm_address_t MethodList = [self.process addressAtAddress: Address];
    if (!MethodList) return nil;
    
    if (self.methodListIsArray)
    {
        const size_t PointerSize = self.process.is64? sizeof(uint64_t) : sizeof(uint32_t);
        for (mach_vm_address_t ListAddr; (ListAddr = [self.process addressAtAddress: MethodList]); MethodList += PointerSize)
        {
            const method_list_t *List = [self.process dataAtAddress: ListAddr OfSize: sizeof(method_list_t)].bytes;
            if (!List) continue;
            const uint32_t MethodSize = List->entsize_NEVER_USE & ~(uint32_t)3;
            
            for (uint32_t Loop = 0; Loop < List->count; Loop++)
            {
                const mach_vm_address_t MethodAddress = (Loop * MethodSize) + (ListAddr + sizeof(method_list_t));
                FFMethod *Method = [FFMethod methodAtAddress: MethodAddress InProcess: self.process];
                if (Method) [Methods addObject: Method];
            }
        }
    }
    
    else
    {
        const mach_vm_address_t ListAddr = MethodList;
        const method_list_t *List = [self.process dataAtAddress: ListAddr OfSize: sizeof(method_list_t)].bytes;
        if (!List) return nil;
        const uint32_t MethodSize = List->entsize_NEVER_USE & ~(uint32_t)3;
        
        for (uint32_t Loop = 0; Loop < List->count; Loop++)
        {
            const mach_vm_address_t MethodAddress = (Loop * MethodSize) + (ListAddr + sizeof(method_list_t));
            FFMethod *Method = [FFMethod methodAtAddress: MethodAddress InProcess: self.process];
            if (Method) [Methods addObject: Method];
        }
        
        //above would work, however would never be called as methodListIsArray is always true at the moment.
    }
    
    return Methods;
}

-(void) setMethods: (NSArray*)methods
{
    if (!self.rw) return;
    mach_vm_address_t Address = self.rw + PROC_OFFSET_OF(class_rw_t, method_lists);
    
    if (!methods)
    {
        [self.process writeAddress: 0 ToAddress: Address];
        return;
    }
    
    const size_t PointerSize = self.process.is64? sizeof(uint64_t) : sizeof(uint32_t);
    
    if (!methodListData) methodListData = [FFMemory allocateInProcess: self.process WithSize: PointerSize * 2];
    mach_vm_address_t MethodList = methodListData.address;
    [self.process writeAddress: MethodList ToAddress: Address];
    
    self.methodListIsArray = YES; //As we will use only method_list_t** (since it's supported in earlier and later versions)
    
    const NSUInteger Count = [methods count];
    if (Count)
    {
        const size_t Entsize = self.process.is64? sizeof(method_t64) : sizeof(method_t32);
        if (!methodsData) methodsData = [FFMemory allocateInProcess: self.process WithSize: Count * Entsize];
        else methodsData.size = Count * Entsize;
        
        
        NSUInteger Index = 0;
        const mach_vm_address_t MethodDataHeaderAddr = methodsData.address;
        const mach_vm_address_t MethodDataAddr = MethodDataHeaderAddr + sizeof(method_list_t);
        
        for (FFMethod *Method in methods)
        {
            if ([Method copyToAddress: MethodDataAddr + (Entsize * Index) InProcess: self.process]) Index++;
        }
        
        //OR 3 for preoptimized, OR 1 for un-preoptimized
        [self.process writeData: &(method_list_t){ .entsize_NEVER_USE = (uint32_t)Entsize | 3, .count = (uint32_t)Index } OfSize: sizeof(method_list_t) ToAddress: MethodDataHeaderAddr];
        
        
        [self.process writeAddress: MethodDataHeaderAddr ToAddress: MethodList];
        MethodList += PointerSize;
    }
    
    [self.process writeAddress: 0 ToAddress: MethodList];
}

-(NSArray*) properties
{
    if (!self.rw) return nil;
    
    NSMutableArray *Properties = [NSMutableArray array];
    
    mach_vm_address_t Address = self.rw + PROC_OFFSET_OF(class_rw_t, properties);
    mach_vm_address_t ChainedPropertyList = [self.process addressAtAddress: Address];
    
    if (!ChainedPropertyList) return nil;
    
    const _Bool Is64 = self.process.is64;
    const size_t PropertySize = Is64? sizeof(property_t64) : sizeof(property_t32);
    
    do
    {
        const void *ChainedList = [self.process dataAtAddress: ChainedPropertyList OfSize: Is64? sizeof(chained_property_list64) : sizeof(chained_property_list32)].bytes;
        if (!ChainedList) break;
        
        
        for (uint32_t Loop = 0, Count = Is64? ((const chained_property_list64*)ChainedList)->count : ((const chained_property_list32*)ChainedList)->count; Loop < Count; Loop++)
        {
            const mach_vm_address_t PropertyAddress = (Loop * PropertySize) + ((Is64? offsetof(chained_property_list64, list) : offsetof(chained_property_list32, list)) + ChainedPropertyList);
            FFProperty *Property = [FFProperty propertyAtAddress: PropertyAddress InProcess: self.process];
            if (Property) [Properties addObject: Property];
        }
        
        ChainedPropertyList = Is64? ((const chained_property_list64*)ChainedList)->next : ((const chained_property_list32*)ChainedList)->next;
    } while (ChainedPropertyList);
    
    
    return Properties;
}

-(void) setProperties: (NSArray*)properties
{
    if (!self.rw) return;
    
    mach_vm_address_t Address = self.rw + PROC_OFFSET_OF(class_rw_t, properties);
    if (!properties)
    {
        [self.process writeAddress: 0 ToAddress: Address];
        return;
    }
    
    const _Bool Is64 = self.process.is64;
    const size_t PropertySize = Is64? sizeof(property_t64) : sizeof(property_t32);
    const size_t ChainSize = Is64? sizeof(chained_property_list64) : sizeof(chained_property_list32);
    
    if (!propertyListData) propertyListData = [FFMemory allocateInProcess: self.process WithSize: ChainSize + (PropertySize * [properties count])];
    else propertyListData.size = ChainSize + (PropertySize * [properties count]);
    
    mach_vm_address_t ChainAddr = propertyListData.address;
    [self.process writeAddress: 0 ToAddress: ChainAddr + PROC_OFFSET_OF(chained_property_list, next)];
    
    mach_vm_address_t ListAddr = ChainAddr + PROC_OFFSET_OF(chained_property_list, list);
    uint32_t Count = 0;
    for (FFProperty *Property in properties)
    {
        if ([Property copyToAddress: ListAddr + (PropertySize * Count) InProcess: self.process]) Count++;
    }
    
    
    [self.process writeData: &Count OfSize: sizeof(uint32_t) ToAddress: ChainAddr + PROC_OFFSET_OF(chained_property_list, count)];
    [self.process writeAddress: ChainAddr ToAddress: Address];
}

-(NSArray*) protocols
{
    if (!self.rw) return nil;
    mach_vm_address_t Address = self.rw + PROC_OFFSET_OF(class_rw_t, protocols);
    
    mach_vm_address_t ProtocolList = [self.process addressAtAddress: Address];
    if (!ProtocolList) return nil;
    
    NSMutableArray *Protocols = [NSMutableArray array];
    const size_t PointerSize = self.process.is64? sizeof(uint64_t) : sizeof(uint32_t);
    for (mach_vm_address_t ListAddr; (ListAddr = [self.process addressAtAddress: ProtocolList]); ProtocolList += PointerSize)
    {
        const protocol_list_t *List = [self.process dataAtAddress: ListAddr OfSize: sizeof(protocol_list_t)].bytes;
        if (!List) continue;
        const uint32_t ProtocolSize = self.process.is64? sizeof(uint64_t) : sizeof(uint32_t);
        
        for (uint32_t Loop = 0; Loop < List->count; Loop++)
        {
            const mach_vm_address_t ProtocolAddress = (Loop * ProtocolSize) + (ListAddr + sizeof(protocol_list_t));
            FFProtocol *Protocol = [FFProtocol protocolAtAddress: [self.process addressAtAddress: ProtocolAddress] InProcess: self.process];
            if (Protocol) [Protocols addObject: Protocol];
        }
    }
    
    return Protocols;
}


-(void) setProtocols: (NSArray *)protocols
{
    if (!self.rw) return;
    mach_vm_address_t Address = self.rw + PROC_OFFSET_OF(class_rw_t, protocols);
    
    if (!protocols)
    {
        [self.process writeAddress: 0 ToAddress: Address];
        return;
    }
    
    const size_t PointerSize = self.process.is64? sizeof(uint64_t) : sizeof(uint32_t);
    
    if (!protocolsListData) protocolsListData = [FFMemory allocateInProcess: self.process WithSize: PointerSize * 2];
    mach_vm_address_t ProtocolList = protocolsListData.address;
    [self.process writeAddress: ProtocolList ToAddress: Address];
    
    const NSUInteger Count = [protocols count];
    if (Count)
    {
        const size_t Entsize = PointerSize;
        if (!protocolsData) protocolsData = [FFMemory allocateInProcess: self.process WithSize: Count * Entsize];
        else protocolsData.size = Count * Entsize;
        
        
        NSUInteger Index = 0;
        const mach_vm_address_t ProtocolDataHeaderAddr = protocolsData.address;
        const mach_vm_address_t ProtocolDataAddr = ProtocolDataHeaderAddr + sizeof(protocol_list_t);
        
        for (FFProtocol *Protocol in protocols)
        {
            if ((Protocol = [Protocol injectTo: self.process]))
            {
                [self.process writeAddress: Protocol.address ToAddress: ProtocolDataAddr + (Entsize * Index++)];
            }
        }
        
        [self.process writeData: &(protocol_list_t){ .count = (uint32_t)Index } OfSize: sizeof(protocol_list_t) ToAddress: ProtocolDataHeaderAddr];
        
        
        [self.process writeAddress: ProtocolDataHeaderAddr ToAddress: ProtocolList];
        ProtocolList += PointerSize;
    }
    
    [self.process writeAddress: 0 ToAddress: ProtocolList + PointerSize];
}

POINTER_TYPE_PROPERTY(FFClassNew, firstSubclass, setFirstSubclass, ADDRESS_IN_CLASS_RW(firstSubclass))
POINTER_TYPE_PROPERTY(FFClassNew, nextSiblingClass, setNextSiblingClass, ADDRESS_IN_CLASS_RW(nextSiblingClass))

//class_ro_t
DIRECT_TYPE_PROPERTY(uint32_t, roFlags, setRoFlags, ADDRESS_IN_CLASS_RO(flags))
DIRECT_TYPE_PROPERTY(uint32_t, instanceStart, setInstanceStart, ADDRESS_IN_CLASS_RO(instanceStart))
DIRECT_TYPE_PROPERTY(uint32_t, instanceSize, setInstanceSize, ADDRESS_IN_CLASS_RO(instanceSize))
DIRECT_TYPE_PROPERTY(uint32_t, reserved, setReserved, 
                     if (!self.process.is64) goto Failure;
                     Address = self.ro + offsetof(class_ro_t64, reserved);) //As stated in header may need to check process runtime version instead

-(NSArray*) ivarLayout
{
    mach_vm_address_t IvarLayoutAddr = [self.process addressAtAddress: self.ro + PROC_OFFSET_OF(class_ro_t, ivarLayout)];
    NSMutableArray *IvarLayout = nil;
    if (IvarLayoutAddr)
    {
        IvarLayout = [NSMutableArray array];
        for (const uint8_t *Layout; (Layout = [self.process dataAtAddress: IvarLayoutAddr OfSize: sizeof(uint8_t)].bytes) && (*Layout); IvarLayoutAddr += sizeof(uint8_t)) [IvarLayout addObject: [NSNumber numberWithUnsignedChar: *Layout]]; //later optimize it to do it in batches
    }
    
    return IvarLayout;
}

-(void) setIvarLayout: (NSArray*)ivarLayout
{
    mach_vm_address_t IvarLayoutAddr = 0;
    if (ivarLayout)
    {
        NSUInteger Size = [ivarLayout count] + 1;
        if (!ivarLayoutData) ivarLayoutData = [FFMemory allocateInProcess: self.process WithSize: Size];
        else ivarLayoutData.size = Size;
        
        NSUInteger Index = 0;
        const mach_vm_address_t Addr = ivarLayoutData.address;
        for (NSNumber *Val in ivarLayout)
        {
            [self.process writeData: &(uint8_t){ [Val unsignedCharValue] } OfSize: sizeof(uint8_t) ToAddress: Addr + Index++];
        }
        
        [self.process writeData: &(uint8_t){ 0 } OfSize: sizeof(uint8_t) ToAddress: Addr + Index];
        IvarLayoutAddr = Addr;
    }
    
    [self.process writeAddress: IvarLayoutAddr ToAddress: self.ro + PROC_OFFSET_OF(class_ro_t, ivarLayout)];
}

STRING_TYPE_PROPERTY(name, setName, ADDRESS_IN_CLASS_RO(name))
ARRAY_OF_POINTER_TYPE_PROPERTY(FFMethod, baseMethods, setBaseMethods, method_list_t, entsize_NEVER_USE & ~(uint32_t)3, entsize_NEVER_USE = (uint32_t)Entsize | 3, ADDRESS_IN_CLASS_RO(baseMethods))

-(NSArray*) baseProtocols
{
    mach_vm_address_t Address = self.ro + PROC_OFFSET_OF(class_ro_t, baseProtocols);
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

-(void) setBaseProtocols: (NSArray *)baseProtocols
{
    mach_vm_address_t Address = 0, DataHeaderAddr = 0;
    Address = self.ro + PROC_OFFSET_OF(class_ro_t, baseProtocols);
    if (baseProtocols)
    {
        const NSUInteger Count = [baseProtocols count];
        if (Count)
        {
            const size_t Entsize = self.process.is64? sizeof(uint64_t) : sizeof(uint32_t);
            if (!baseProtocolsData) baseProtocolsData = [FFMemory allocateInProcess: self.process WithSize: Count * Entsize];
            else baseProtocolsData.size = Count * Entsize;
            
            NSUInteger Index = 0;
            DataHeaderAddr = baseProtocolsData.address;
            const mach_vm_address_t DataAddr = DataHeaderAddr + sizeof(protocol_list_t);
            for (FFProtocol *Type in baseProtocols)
            {
                if ((Type = [Type injectTo: self.process]))
                {
                    [self.process writeAddress: Type.address ToAddress: DataAddr + (Entsize * Index++)];
                }
            }
            
            [self.process writeData: &(protocol_list_t){ .count = (uint32_t)Index } OfSize: sizeof(protocol_list_t) ToAddress: DataHeaderAddr];
        }
    }
    
    [self.process writeAddress: DataHeaderAddr ToAddress: Address];
}

ARRAY_OF_POINTER_TYPE_PROPERTY(FFIvar, ivars, setIvars, ivar_list_t, entsize, entsize = (uint32_t)Entsize, ADDRESS_IN_CLASS_RO(ivars))

-(NSArray*) weakIvarLayout
{
    mach_vm_address_t WeakIvarLayoutAddr = [self.process addressAtAddress: self.ro + PROC_OFFSET_OF(class_ro_t, ivarLayout)];
    NSMutableArray *WeakIvarLayout = nil;
    if (WeakIvarLayoutAddr)
    {
        WeakIvarLayout = [NSMutableArray array];
        for (const uint8_t *Layout; (Layout = [self.process dataAtAddress: WeakIvarLayoutAddr OfSize: sizeof(uint8_t)].bytes) && (*Layout); WeakIvarLayoutAddr += sizeof(uint8_t)) [WeakIvarLayout addObject: [NSNumber numberWithUnsignedChar: *Layout]]; //later optimize it to do it in batches
    }
    
    return WeakIvarLayout;
}

-(void) setWeakIvarLayout: (NSArray*)weakIvarLayout
{
    mach_vm_address_t WeakIvarLayoutAddr = 0;
    if (weakIvarLayout)
    {
        NSUInteger Size = [weakIvarLayout count] + 1;
        if (!weakIvarLayoutData) weakIvarLayoutData = [FFMemory allocateInProcess: self.process WithSize: Size];
        else weakIvarLayoutData.size = Size;
        
        NSUInteger Index = 0;
        const mach_vm_address_t Addr = weakIvarLayoutData.address;
        for (NSNumber *Val in weakIvarLayout)
        {
            [self.process writeData: &(uint8_t){ [Val unsignedCharValue] } OfSize: sizeof(uint8_t) ToAddress: Addr + Index++];
        }
        
        [self.process writeData: &(uint8_t){ 0 } OfSize: sizeof(uint8_t) ToAddress: Addr + Index];
        WeakIvarLayoutAddr = Addr;
    }
    
    [self.process writeAddress: WeakIvarLayoutAddr ToAddress: self.ro + PROC_OFFSET_OF(class_ro_t, weakIvarLayout)];
}

ARRAY_OF_POINTER_TYPE_PROPERTY(FFProperty, baseProperties, setBaseProperties, property_list_t, entsize, entsize = (uint32_t)Entsize, ADDRESS_IN_CLASS_RO(baseProperties))

#define SINGLE_FLAG_TYPE_PROPERTY(getter, setter, flagProperty, flag) \
-(_Bool) getter \
{ \
return self.flagProperty & flag; \
} \
\
-(void) setter: (_Bool)getter \
{ \
const uint32_t Flags = self.flagProperty & ~flag; \
self.flagProperty = Flags | (getter? flag : 0); \
}

#define RO_RW_FLAG_TYPE_PROPERTY(getter, setter, flagRO, flagRW) \
-(_Bool) getter \
{ \
return (self.roFlags & flagRO) | (self.rwFlags & flagRW); \
} \
\
-(void) setter: (_Bool)getter \
{ \
uint32_t Flags = self.roFlags & ~flagRO; \
self.roFlags = Flags | (getter? flagRO : 0); \
\
Flags = self.rwFlags & ~flagRW; \
self.rwFlags = Flags | (getter? flagRW : 0); \
}

#define RW_DATA_NEVER_USE_FLAG_TYPE_PROPERTY(getter, setter, flagRW, data_NEVER_USE_Flag) \
-(_Bool) getter \
{ \
return (self.data_NEVER_USE & data_NEVER_USE_Flag) | (self.rwFlags & flagRW); \
} \
\
-(void) setter: (_Bool)getter \
{ \
/* To handle either case whether CLASS_FAST_FLAGS_VIA_RW_DATA is used or not */ \
mach_vm_address_t DATA_NEVER_USE = self.data_NEVER_USE & ~data_NEVER_USE_Flag; \
self.data_NEVER_USE = DATA_NEVER_USE | (getter? data_NEVER_USE_Flag : 0); \
\
uint32_t Flags = self.rwFlags & ~flagRW; \
self.rwFlags = Flags | (getter? flagRW : 0); \
}

//RO flags
SINGLE_FLAG_TYPE_PROPERTY(isMetaClass, setIsMetaClass, roFlags, RO_META)
SINGLE_FLAG_TYPE_PROPERTY(isRootClass, setIsRootClass, roFlags, RO_ROOT)
SINGLE_FLAG_TYPE_PROPERTY(isHidden, setIsHidden, roFlags, RO_HIDDEN)
SINGLE_FLAG_TYPE_PROPERTY(isExceptionClass, setIsExceptionClass, roFlags, RO_EXCEPTION)
SINGLE_FLAG_TYPE_PROPERTY(usesAutomaticRetainRelease, setUsesAutomaticRetainRelease, roFlags, RO_IS_ARR)
SINGLE_FLAG_TYPE_PROPERTY(isBundleClass, setIsBundleClass, roFlags, RO_FROM_BUNDLE)

//RW flags
SINGLE_FLAG_TYPE_PROPERTY(isInitialized, setIsInitialized, rwFlags, RW_INITIALIZED)
SINGLE_FLAG_TYPE_PROPERTY(isInitializing, setIsInitializing, rwFlags, RW_INITIALIZING)
SINGLE_FLAG_TYPE_PROPERTY(hasCopiedRO, setHasCopiedRO, rwFlags, RW_COPIED_RO)
SINGLE_FLAG_TYPE_PROPERTY(isConstructing, setIsConstructing, rwFlags, RW_CONSTRUCTING)
SINGLE_FLAG_TYPE_PROPERTY(isConstructed, setIsConstructed, rwFlags, RW_CONSTRUCTED)
SINGLE_FLAG_TYPE_PROPERTY(shouldFinalizeOnMainThread, setShouldFinalizeOnMainThread, rwFlags, RW_FINALIZE_ON_MAIN_THREAD)
SINGLE_FLAG_TYPE_PROPERTY(isLoaded, setIsLoaded, rwFlags, RW_LOADED)
SINGLE_FLAG_TYPE_PROPERTY(hasSpecializedVtable, setHasSpecializedVtable, rwFlags, RW_SPECIALIZED_VTABLE)
SINGLE_FLAG_TYPE_PROPERTY(instancesHaveAssociatedObjects, setInstancesHaveAssociatedObjects, rwFlags, RW_INSTANCES_HAVE_ASSOCIATED_OBJECTS)
SINGLE_FLAG_TYPE_PROPERTY(instancesHaveSpecificLayout, setInstancesHaveSpecificLayout, rwFlags, RW_HAS_INSTANCE_SPECIFIC_LAYOUT)
//SINGLE_FLAG_TYPE_PROPERTY(methodListIsArray, setMethodListIsArray, rwFlags, RW_METHOD_ARRAY)
/*
 Temp hack, as the more recent runtime versions are not used yet. So method list is always an array.
 otool -L /usr/lib/libobjc.A.dylib
 /usr/lib/libobjc.A.dylib:
 /usr/lib/libobjc.A.dylib (compatibility version 1.0.0, current version 228.0.0)
 
 Hopefully 228.0.0 will change when it's introduced, and so can just query that in the process.
 */
-(_Bool)methodListIsArray {return YES;}
-(void)setMethodListIsArray: (_Bool)methodListIsArray{}

//RO & RW flags
RO_RW_FLAG_TYPE_PROPERTY(hasCxxStructors, setHasCxxStructors, RO_HAS_CXX_STRUCTORS, RW_HAS_CXX_STRUCTORS)
RO_RW_FLAG_TYPE_PROPERTY(isFutureClass, setIsFutureClass, RO_FUTURE, RW_FUTURE)
RO_RW_FLAG_TYPE_PROPERTY(isRealized, setIsRealized, RO_REALIZED, RW_REALIZED)

//RW & data_NEVER_USE flags
RW_DATA_NEVER_USE_FLAG_TYPE_PROPERTY(hasCustomRR, setHasCustomRR, RW_HAS_CUSTOM_RR, 1)
RW_DATA_NEVER_USE_FLAG_TYPE_PROPERTY(hasCustomAWZ, setHasCustomAWZ, RW_HAS_CUSTOM_AWZ, 2)

-(void) dealloc
{
    [nameData release]; nameData = nil;
    [methodsData release]; methodsData = nil;
    [methodListData release]; methodListData = nil;
    [propertyListData release]; propertyListData = nil;
    [baseMethodsData release]; baseMethodsData = nil;
    [ivarsData release]; ivarsData = nil;
    [basePropertiesData release]; basePropertiesData = nil;
    [baseProtocolsData release]; baseProtocolsData = nil;
    [protocolsData release]; protocolsData = nil;
    [protocolsListData release]; protocolsListData = nil;
    [ivarLayoutData release]; ivarLayoutData = nil;
    [weakIvarLayoutData release]; weakIvarLayoutData = nil;
    [vtableData release]; vtableData = nil;
    
    [super dealloc];
}

@end
