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

#import "FFClassOld.h"
#import "ObjcOldRuntime32.h"
#import "ObjcOldRuntime64.h"
#import "NSValue+MachVMAddress.h"
#import "FFProcess.h"
#import "FFMemory.h"
#import "FFCache.h"
#import "FFMethod.h"
#import "FFIvar.h"
#import "FFProtocol.h"

#import "PropertyImpMacros.h"

@implementation FFClassOld
{
    FFMemory *nameData;
    FFMemory *ivarLayoutData, *weakIvarLayoutData;
    FFMemory *methodData;
    FFMemory *ivarData;
    FFMemory *protocolData;
}

-(NSUInteger) dataSize
{
    const _Bool HasExt = self.hasExtension;
    return self.process.is64? sizeof(old_class64) + (HasExt? sizeof(old_class_ext64) : 0) : sizeof(old_class32) + (HasExt? sizeof(old_class_ext32) : 0);
}

-(id) copyToAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    if (addr) return nil;
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
    
    
    const _Bool  Is64 = self.process.is64;
    NSMutableData *Data = [[[self.process dataAtAddress: self.address OfSize: Is64? sizeof(old_class64) : sizeof(old_class32)] mutableCopy] autorelease];
    
    //NULL out all members used in -expose
    void *Cls = Data.mutableBytes;
    if (!Cls) return nil;
    if (Is64)
    {
        ((old_class64*)Cls)->isa = 0;
        ((old_class64*)Cls)->super_class = 0;
    }
    
    else
    {
        ((old_class32*)Cls)->isa = 0;
        ((old_class32*)Cls)->super_class = 0;
    }
    
    [proc write: Data ToAddress: addr];
    
    
    FFClassOld *ClassCopy = [[self class] classAtAddress: addr InProcess: proc];
    [CopiedTable setObject: ClassCopy forKey: [NSValue valueWithAddress: self.address]];
    
    ClassCopy.isa = self.isa;
    ClassCopy.superclass = self.superclass;
    ClassCopy.name = self.name;
    ClassCopy.version = self.version;
    ClassCopy.info = self.info;
    ClassCopy.instanceSize = self.instanceSize;
    ClassCopy.ivars = self.ivars;
    ClassCopy.methods = self.methods;
    ClassCopy.cache = self.cache;
    ClassCopy.protocols = self.protocols;
    
    if (self.ext)
    {
        ClassCopy.ivarLayout = self.ivarLayout;
        
        ClassCopy.ext = addr + (Is64? sizeof(old_class64) : sizeof(old_class32));
        
        ClassCopy.size = self.size;
        ClassCopy.weakIvarLayout = self.weakIvarLayout;
        ClassCopy.properties = self.properties;
    }
    
    if (FirstCopy)
    {
        [CopiedTables setObject: [NSNull null] forKey: CurrentThread];
    }
    
    
    return ClassCopy;
}

#define ADDRESS_IN_CLASS(member) Address = self.address + PROC_OFFSET_OF(old_class, member);
#define ADDRESS_IN_CLASS_EXT(member) \
if (!self.hasExtension) goto Failure; \
Address = self.ext;


POINTER_TYPE_PROPERTY(FFClassOld, isa, setIsa, ADDRESS_IN_CLASS(isa))
POINTER_TYPE_PROPERTY(FFClassOld, superclass, setSuperclass, ADDRESS_IN_CLASS(super_class))
STRING_TYPE_PROPERTY(name, setName, ADDRESS_IN_CLASS(name))
/*
 The following 3 have type long, but should only be applied in 32 bit processes. So unless old runtime is introduced into 64 bit than no need to worry.
 If that does happen than will need to re-implement the following but still cast back to uint32_t from uint64_t (on 64 bit).
 */

DIRECT_TYPE_PROPERTY(uint32_t, version, setVersion, ADDRESS_IN_CLASS(version))
DIRECT_TYPE_PROPERTY(uint32_t, info, setInfo, ADDRESS_IN_CLASS(info))
DIRECT_TYPE_PROPERTY(uint32_t, instanceSize, setInstanceSize, ADDRESS_IN_CLASS(instance_size))

-(NSArray*) ivars
{
    NSMutableArray *Ivars = [NSMutableArray array];
    
    mach_vm_address_t Address = self.address + PROC_OFFSET_OF(old_class, ivars);
    mach_vm_address_t IvarList = [self.process addressAtAddress: Address];
    if (!IvarList) return nil;

    const size_t IvarSize = self.process.is64? sizeof(old_ivar64) : sizeof(old_ivar32);
    const uint32_t *IvarCount = [self.process dataAtAddress: IvarList + PROC_OFFSET_OF(old_ivar_list, ivar_count) OfSize: sizeof(uint32_t)].bytes;
    if (!IvarCount) return nil;
    
    const mach_vm_address_t CurrentIvar = IvarList + PROC_OFFSET_OF(old_ivar_list, ivar_list);
    for (size_t Loop = 0, Count = *IvarCount; Loop < Count; Loop++)
    {
        [Ivars addObject: [FFIvar ivarAtAddress: CurrentIvar + (Loop * IvarSize) InProcess: self.process]];
    }
    
    
    return Ivars;
}

-(void) setIvars: (NSArray*)ivars
{
    mach_vm_address_t Address = self.address + PROC_OFFSET_OF(old_class, ivars);
    
    if (!ivars)
    {
        [self.process writeAddress: 0 ToAddress: Address];
        return;
    }
    
    
    const NSUInteger Count = [ivars count];
    const _Bool Is64 = self.process.is64;
    if (!ivarData) ivarData = [FFMemory allocateInProcess: self.process WithSize: Is64? sizeof(old_ivar_list64) + (sizeof(old_ivar64) * Count) : sizeof(old_ivar_list32) + (sizeof(old_ivar32) * Count)];
    else ivarData.size = Is64? sizeof(old_ivar_list64) + (sizeof(old_ivar64) * Count) : sizeof(old_ivar_list32) + (sizeof(old_ivar32) * Count);
    
    
    const mach_vm_address_t IvarDataHeaderAddr = ivarData.address;
    const mach_vm_address_t IvarDataAddr = IvarDataHeaderAddr + PROC_OFFSET_OF(old_ivar_list, ivar_list);
    const size_t Entsize = Is64? sizeof(old_ivar64) : sizeof(old_ivar32);
    
    NSUInteger Index = 0;
    for (FFIvar *Ivar in ivars)
    {
        if ([Ivar copyToAddress: IvarDataAddr + (Entsize * Index) InProcess: self.process]) Index++;
    }
    
    
    [self.process writeData: &(uint32_t){ (uint32_t)Index } OfSize: sizeof(uint32_t) ToAddress: IvarDataHeaderAddr + PROC_OFFSET_OF(old_ivar_list, ivar_count)];
    
    [self.process writeAddress: IvarDataHeaderAddr ToAddress: Address];

}

-(NSArray*) methods
{
    NSMutableArray *Methods = [NSMutableArray array];
    
    mach_vm_address_t Address = self.address + PROC_OFFSET_OF(old_class, methodLists);
    mach_vm_address_t MethodList = [self.process addressAtAddress: Address];
    if (!MethodList) return nil;
    
    const size_t MethodSize = self.process.is64? sizeof(old_method64) : sizeof(old_method32);
    
    if (self.methodListIsNotArray)
    {
        const mach_vm_address_t List = MethodList;
        const uint32_t *MethodCount = [self.process dataAtAddress: List + PROC_OFFSET_OF(old_method_list, method_count) OfSize: sizeof(uint32_t)].bytes;
        if (!MethodCount) return nil;
        
        const mach_vm_address_t CurrentMethod = List + PROC_OFFSET_OF(old_method_list, method_list);
        for (size_t Loop = 0, Count = *MethodCount; Loop < Count; Loop++)
        {
            [Methods addObject: [FFMethod methodAtAddress: CurrentMethod + (Loop * MethodSize) InProcess: self.process]];
        }
    }
    
    else
    {
        const mach_vm_address_t ListTerminator = self.process.is64? (uint64_t)INT64_C(-1) : (uint32_t)INT32_C(-1);
        const size_t PointerSize = self.process.is64? sizeof(uint64_t) : sizeof(uint32_t);
        for (mach_vm_address_t ListAddr; (ListAddr = [self.process addressAtAddress: MethodList]) && (ListAddr != ListTerminator); MethodList += PointerSize)
        {
            const mach_vm_address_t List = [self.process addressAtAddress: MethodList];
            const uint32_t *MethodCount = [self.process dataAtAddress: List + PROC_OFFSET_OF(old_method_list, method_count) OfSize: sizeof(uint32_t)].bytes;
            if (!MethodCount) continue;
            
            const mach_vm_address_t CurrentMethod = List + PROC_OFFSET_OF(old_method_list, method_list);
            for (size_t Loop = 0, Count = *MethodCount; Loop < Count; Loop++)
            {
                [Methods addObject: [FFMethod methodAtAddress: CurrentMethod + (Loop * MethodSize) InProcess: self.process]];
            }
        }
    }
    
    
    return Methods;
}

-(void) setMethods: (NSArray*)methods
{
    mach_vm_address_t Address = self.address + PROC_OFFSET_OF(old_class, methodLists);
    
    if (!methods)
    {
        [self.process writeAddress: 0 ToAddress: Address];
        return;
    }
    
    
    const NSUInteger Count = [methods count];
    const _Bool Is64 = self.process.is64;
    if (!methodData) methodData = [FFMemory allocateInProcess: self.process WithSize: Is64? sizeof(old_method_list64) + (sizeof(old_method64) * Count) : sizeof(old_method_list32) + (sizeof(old_method32) * Count)];
    else methodData.size = Is64? sizeof(old_method_list64) + (sizeof(old_method64) * Count) : sizeof(old_method_list32) + (sizeof(old_method32) * Count);
    
    self.methodListIsNotArray = YES;
    
    
    const mach_vm_address_t MethodDataHeaderAddr = methodData.address;
    const mach_vm_address_t MethodDataAddr = MethodDataHeaderAddr + PROC_OFFSET_OF(old_method_list, method_list);
    const size_t Entsize = Is64? sizeof(old_method64) : sizeof(old_method32);
    
    NSUInteger Index = 0;
    for (FFMethod *Method in methods)
    {
        if ([Method copyToAddress: MethodDataAddr + (Entsize * Index) InProcess: self.process]) Index++;
    }
    
    
    [self.process writeAddress: 0 ToAddress: MethodDataHeaderAddr + PROC_OFFSET_OF(old_method_list, obsolete)];
    [self.process writeData: &(uint32_t){ (uint32_t)Index } OfSize: sizeof(uint32_t) ToAddress: MethodDataHeaderAddr + PROC_OFFSET_OF(old_method_list, method_count)];
    
    [self.process writeAddress: MethodDataHeaderAddr ToAddress: Address];
}

POINTER_TYPE_PROPERTY(FFCache, cache, setCache, ADDRESS_IN_CLASS(cache))

-(NSArray*) protocols
{
    NSMutableArray *Protocols = [NSMutableArray array];
    
    mach_vm_address_t Address = self.address + PROC_OFFSET_OF(old_class, protocols);
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

// CLS_EXT only
-(NSArray*) ivarLayout
{
    if (!self.hasExtension) return nil;
    mach_vm_address_t IvarLayoutAddr = [self.process addressAtAddress: self.address + PROC_OFFSET_OF(old_class, ivar_layout)];
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
    if (!self.hasExtension) return;
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
    
    [self.process writeAddress: IvarLayoutAddr ToAddress: self.address + PROC_OFFSET_OF(old_class, ivar_layout)];
}

ADDRESS_TYPE_PROPERTY(ext, setExt, 
                      if (!self.hasExtension) goto Failure;
                      ADDRESS_IN_CLASS(ext);)
DIRECT_TYPE_PROPERTY(uint32_t, size, setSize, ADDRESS_IN_CLASS_EXT(size))

-(NSArray*) weakIvarLayout
{
    if (!self.hasExtension) return nil;
    mach_vm_address_t IvarLayoutAddr = [self.process addressAtAddress: self.ext];
    NSMutableArray *IvarLayout = nil;
    if (IvarLayoutAddr)
    {
        IvarLayout = [NSMutableArray array];
        for (const uint8_t *Layout; (Layout = [self.process dataAtAddress: IvarLayoutAddr OfSize: sizeof(uint8_t)].bytes) && (*Layout); IvarLayoutAddr += sizeof(uint8_t)) [IvarLayout addObject: [NSNumber numberWithUnsignedChar: *Layout]]; //later optimize it to do it in batches
    }
    
    return IvarLayout;
}

-(void) setWeakIvarLayout: (NSArray*)ivarLayout
{
    if (!self.hasExtension) return;
    mach_vm_address_t IvarLayoutAddr = 0;
    if (ivarLayout)
    {
        NSUInteger Size = [ivarLayout count] + 1;
        if (!weakIvarLayoutData) weakIvarLayoutData = [FFMemory allocateInProcess: self.process WithSize: Size];
        else weakIvarLayoutData.size = Size;
        
        NSUInteger Index = 0;
        const mach_vm_address_t Addr = weakIvarLayoutData.address;
        for (NSNumber *Val in ivarLayout)
        {
            [self.process writeData: &(uint8_t){ [Val unsignedCharValue] } OfSize: sizeof(uint8_t) ToAddress: Addr + Index++];
        }
        
        [self.process writeData: &(uint8_t){ 0 } OfSize: sizeof(uint8_t) ToAddress: Addr + Index];
        IvarLayoutAddr = Addr;
    }
    
    [self.process writeAddress: IvarLayoutAddr ToAddress: self.ext];
}

-(NSArray*) properties
{
    if (!self.hasExtension) return nil;
    
    return nil;
}

-(void) setProperties: (NSArray*)properties
{
    if (!self.hasExtension) return;
}

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

SINGLE_FLAG_TYPE_PROPERTY(isMetaClass, setIsMetaClass, info, CLS_META)
SINGLE_FLAG_TYPE_PROPERTY(hasCxxStructors, setHasCxxStructors, info, CLS_HAS_CXX_STRUCTORS)
SINGLE_FLAG_TYPE_PROPERTY(isHidden, setIsHidden, info, CLS_HIDDEN) //conflicts with certain versions where CLS_EXT had same value
SINGLE_FLAG_TYPE_PROPERTY(isBundleClass, setIsBundleClass, info, CLS_FROM_BUNDLE)
SINGLE_FLAG_TYPE_PROPERTY(isInitialized, setIsInitialized, info, CLS_INITIALIZED)
SINGLE_FLAG_TYPE_PROPERTY(isInitializing, setIsInitializing, info, CLS_INITIALIZING)
SINGLE_FLAG_TYPE_PROPERTY(isConstructed, setIsConstructed, info, CLS_CONSTRUCTED)
SINGLE_FLAG_TYPE_PROPERTY(isConstructing, setIsConstructing, info, CLS_CONSTRUCTING)
SINGLE_FLAG_TYPE_PROPERTY(shouldFinalizeOnMainThread, setShouldFinalizeOnMainThread, info, CLS_FINALIZE_ON_MAIN_THREAD)
SINGLE_FLAG_TYPE_PROPERTY(isLoaded, setIsLoaded, info, CLS_LOADED)
SINGLE_FLAG_TYPE_PROPERTY(instancesHaveAssociatedObjects, setInstancesHaveAssociatedObjects, info, CLS_INSTANCES_HAVE_ASSOCIATED_OBJECTS)
SINGLE_FLAG_TYPE_PROPERTY(instancesHaveSpecificLayout, setInstancesHaveSpecificLayout, info, CLS_HAS_INSTANCE_SPECIFIC_LAYOUT)
SINGLE_FLAG_TYPE_PROPERTY(isClass, setIsClass, info, CLS_CLASS)
SINGLE_FLAG_TYPE_PROPERTY(isPosing, setIsPosing, info, CLS_POSING)
SINGLE_FLAG_TYPE_PROPERTY(isMapped, setIsMapped, info, CLS_MAPPED)
SINGLE_FLAG_TYPE_PROPERTY(flushCache, setFlushCache, info, CLS_FLUSH_CACHE)
SINGLE_FLAG_TYPE_PROPERTY(growCache, setGrowCache, info, CLS_GROW_CACHE)
SINGLE_FLAG_TYPE_PROPERTY(needsBind, setNeedsBind, info, CLS_NEED_BIND)
SINGLE_FLAG_TYPE_PROPERTY(methodListIsArray, setMethodListIsArray, info, CLS_METHOD_ARRAY)
SINGLE_FLAG_TYPE_PROPERTY(isJavaHybrid, setIsJavaHybrid, info, CLS_JAVA_HYBRID)
SINGLE_FLAG_TYPE_PROPERTY(isJavaClass, setIsJavaClass, info, CLS_JAVA_CLASS)
SINGLE_FLAG_TYPE_PROPERTY(methodListIsNotArray, setMethodListIsNotArray, info, CLS_NO_METHOD_ARRAY) //methodLists is NULL or single list
SINGLE_FLAG_TYPE_PROPERTY(hasLoadMethod, setHasLoadMethod, info, CLS_HAS_LOAD_METHOD)
SINGLE_FLAG_TYPE_PROPERTY(propertyListIsNotArray, setPropertyListIsNotArray, info, CLS_NO_PROPERTY_ARRAY) //propertyLists is NULL or single list
SINGLE_FLAG_TYPE_PROPERTY(isConnected, setIsConnected, info, CLS_CONNECTED)
SINGLE_FLAG_TYPE_PROPERTY(isLeaf, setIsLeaf, info, CLS_LEAF)

-(_Bool) isRootClass
{
    return self.superclass == nil || [self isEqual: self.superclass];
}

-(void) setIsRootClass: (_Bool)isRootClass {}

-(_Bool) hasExtension
{
    if (self.version >= 6)
    {
        return self.isHidden;
    }
    
    return NO;
}

-(void) setHasExtension: (_Bool)hasExtension
{
    if (self.version >= 6)
    {
        self.isHidden = hasExtension;
    }
}

-(void) dealloc
{
    [nameData release]; nameData = nil;
    [ivarLayoutData release]; ivarLayoutData = nil;
    [weakIvarLayoutData release]; weakIvarLayoutData = nil;
    [methodData release]; methodData = nil;
    [ivarData release]; ivarData = nil;
    [protocolData release]; protocolData = nil;
    
    [super dealloc];
}

@end
