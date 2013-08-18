/*
 *  Copyright (c) 2012,2013, Stefan Johnson                                                  
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

#import "FFCache.h"
#import "ObjcNewRuntime32.h"
#import "ObjcNewRuntime64.h"
#import "ObjcCache32.h"
#import "ObjcCache64.h"
#import "PropertyImpMacros.h"

#import "FFProcess.h"
#import "FFMethod.h"


@implementation FFCache

+(FFCache*) cacheAtAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    return [[[FFCache alloc] initWithCacheAtAddress: addr InProcess: proc] autorelease];
}

-(id) initWithCacheAtAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
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
    return [self initWithCacheAtAddress: addr InProcess: proc];
}

-(id) copyToAddress:(mach_vm_address_t)address InProcess:(FFProcess *)proc
{
    FFCache *Cache = [super copyToAddress: address InProcess: proc];
    Cache.buckets = self.buckets;
    
    return nil;
}

-(NSUInteger) dataSize
{
    return self.process.is64? sizeof(struct objc_cache64) : sizeof(struct objc_cache32);
}

-(uint64_t) mask
{
    return [self.process addressAtAddress: self.address + PROC_OFFSET_OF(struct objc_cache, mask)];
}

-(void) setMask: (uint64_t)mask
{
    [self.process writeAddress: mask ToAddress: self.address + PROC_OFFSET_OF(struct objc_cache, mask)];
}

-(uint64_t) occupied
{
    return [self.process addressAtAddress: self.address + PROC_OFFSET_OF(struct objc_cache, occupied)];
}

-(void) setOccupied: (uint64_t)occupied
{
    [self.process writeAddress: occupied ToAddress: self.address + PROC_OFFSET_OF(struct objc_cache, occupied)];
}

-(NSArray*) buckets
{
    NSMutableArray *Methods = [NSMutableArray array];
    FFMethod *Method;
    for (size_t Count = 0, PointerSize = self.process.is64? sizeof(uint64_t) : sizeof(uint32_t); (Method = [FFMethod methodAtAddress: [self.process addressAtAddress: self.address + PROC_OFFSET_OF(struct objc_cache, buckets) + (Count * PointerSize)] InProcess: self.process]); Count++) [Methods addObject: Method];
    
    
    return Methods;
}

-(void) setBuckets: (NSArray*)buckets
{
    if ([buckets count] == [self.buckets count])
    {
        size_t Index = 0, PointerSize = self.process.is64? sizeof(uint64_t) : sizeof(uint32_t);
        for (FFMethod *Method in buckets)
        {
            [self.process writeAddress: ((FFMethod*)[Method injectTo: self.process]).address ToAddress: self.address + PROC_OFFSET_OF(struct objc_cache, buckets) + (Index++ * PointerSize)];
        }
    }
}

@end
