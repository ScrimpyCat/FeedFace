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

#define PROC_OFFSET_OF(type, member) (self.process.is64? offsetof(type##64, member) : offsetof(type##32, member))

#define POINTER_TYPE_PROPERTY(fftype, getter, setter, ...) \
-(fftype*) getter \
{ \
    mach_vm_address_t Address = 0; \
    __VA_ARGS__;  \
    if (!Address) goto Failure; \
    return [[[fftype alloc] initWithAddress: [self.process addressAtAddress: Address] InProcess: self.process] autorelease]; \
Failure: \
    return nil; \
} \
\
-(void) setter: (fftype*)new##getter \
{ \
    mach_vm_address_t Address = 0; \
    __VA_ARGS__; \
    if (!Address) goto Failure; \
    fftype *Injected = [new##getter injectTo: self.process]; \
    [self.process writeAddress: Injected.address ToAddress: Address]; \
Failure:; \
}

#define ARRAY_OF_POINTER_TYPE_PROPERTY(fftype, getter, setter, list, entsizeGet, entsizeSet, ...) \
-(NSArray*) getter \
{ \
    mach_vm_address_t Address = 0; \
    __VA_ARGS__; \
    if (!Address) goto Failure; \
    const mach_vm_address_t ListAddr = [self.process addressAtAddress: Address]; \
    const list *List = ListAddr? [self.process dataAtAddress: ListAddr OfSize: sizeof(list)].bytes : NULL; \
    if (!List) return nil; \
    const uint32_t TypeSize = List->entsizeGet; \
    \
    NSMutableArray *Types = [NSMutableArray array]; \
    for (uint32_t Loop = 0; Loop < List->count; Loop++) \
    { \
        const mach_vm_address_t TypeAddress = (Loop * TypeSize) + (ListAddr + sizeof(list)); \
        fftype *Type = [[[fftype alloc] initWithAddress: TypeAddress InProcess: self.process] autorelease]; \
        if (Type) [Types addObject: Type]; \
    } \
    \
    return Types; \
Failure: \
    return nil; \
} \
\
-(void) setter: (NSArray*)new##getter \
{ \
    mach_vm_address_t Address = 0, DataHeaderAddr = 0; \
    __VA_ARGS__;  \
    if (!Address) goto Failure; \
    if (new##getter) \
    { \
        const NSUInteger Count = [new##getter count]; \
        if (Count) \
        { \
            const size_t Entsize = [[new##getter objectAtIndex: 0] dataSize]; \
            if (!getter##Data) getter##Data = [FFMemory allocateInProcess: self.process WithSize: Count * Entsize]; \
            else getter##Data.size = Count * Entsize; \
            \
            NSUInteger Index = 0; \
            DataHeaderAddr = getter##Data.address; \
            const mach_vm_address_t DataAddr = DataHeaderAddr + sizeof(list); \
            \
            for (fftype *Type in new##getter) \
            { \
                if ([Type copyToAddress: DataAddr + (Entsize * Index) InProcess: self.process]) Index++;\
            } \
            \
            [self.process writeData: &(list){ .entsizeSet, .count = (uint32_t)Index } OfSize: sizeof(list) ToAddress: DataHeaderAddr]; \
        } \
    } \
    \
    [self.process writeAddress: DataHeaderAddr ToAddress: Address]; \
Failure:; \
}

#define ADDRESS_TYPE_PROPERTY(getter, setter, ...) \
-(mach_vm_address_t) getter \
{ \
    mach_vm_address_t Address = 0; \
    __VA_ARGS__; \
    if (!Address) goto Failure; \
    return [self.process addressAtAddress: Address]; \
Failure: \
    return 0; \
} \
\
-(void) setter: (mach_vm_address_t)new##getter \
{ \
    mach_vm_address_t Address = 0; \
    __VA_ARGS__;  \
    if (!Address) goto Failure; \
    [self.process writeAddress: new##getter ToAddress: Address]; \
Failure:; \
}

#define DIRECT_TYPE_PROPERTY(type, getter, setter, ...) \
-(type) getter \
{ \
    mach_vm_address_t Address = 0; \
    __VA_ARGS__; \
    if (!Address) goto Failure; \
    const type *Temp##getter = [self.process dataAtAddress: Address OfSize: sizeof(type)].bytes; \
    if (Temp##getter) return *Temp##getter; \
Failure: \
    return 0; \
} \
\
-(void) setter: (type)new##getter \
{ \
    mach_vm_address_t Address = 0; \
    __VA_ARGS__; \
    if (!Address) goto Failure; \
    [self.process writeData: &new##getter OfSize: sizeof(type) ToAddress: Address]; \
Failure:; \
}

#define STRING_TYPE_PROPERTY(getter, setter, ...) \
-(NSString*) getter \
{ \
    mach_vm_address_t Address = 0; \
    __VA_ARGS__; \
    if (!Address) goto Failure; \
    return [self.process nullTerminatedStringAtAddress: [self.process addressAtAddress: Address]]; \
Failure: \
    return nil; \
} \
\
-(void) setter: (NSString*)getter \
{ \
    mach_vm_address_t Address = 0; \
    __VA_ARGS__; \
    if (!Address) goto Failure; \
    \
    mach_vm_address_t getter##Addr = 0; /*So if name is nil, it will be the same as setting the types member to NULL*/ \
    if (getter) \
    { \
        NSUInteger Size = [getter lengthOfBytesUsingEncoding: NSUTF8StringEncoding] + 1; \
        if (!getter##Data) getter##Data = [FFMemory allocateInProcess: self.process WithSize: Size]; \
        else getter##Data.size = Size; \
        \
        [self.process writeData: [getter UTF8String] OfSize: getter##Data.size ToAddress: getter##Data.address]; \
        getter##Addr = getter##Data.address; \
    } \
    \
    \
    [self.process writeAddress: getter##Addr ToAddress: Address]; \
Failure:; \
}
