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

#import "FFMemory.h"
#import "FFProcess.h"
#import <mach/mach.h>
#import <mach/mach_vm.h>

@implementation FFMemory
{
    int flags;
    FFAllocationOptions options;
}

@synthesize process, address, size;

+(FFMemory*) allocateInProcess: (FFProcess*)process WithSize: (mach_vm_size_t)size
{
    return [FFMemory allocateInProcess: process WithSize: size IsPurgeable: NO];
}

+(FFMemory*) allocateInProcess: (FFProcess*)process WithSize: (mach_vm_size_t)size IsPurgeable: (_Bool)purgeable
{
    return [FFMemory memoryInProcess: process WithSize: size Flags: VM_FLAGS_ANYWHERE | (purgeable? VM_FLAGS_PURGABLE : 0) AllocationOptions: FFAllocate | FFFreeOnResize | FFCanGrow | FFCanShrink AtAddress: 0];
}

+(FFMemory*) allocateInProcess: (FFProcess*)process WithSize: (mach_vm_size_t)size AtAddress: (mach_vm_address_t)address
{
    return [FFMemory allocateInProcess: process WithSize: size AtAddress: address IsPurgeable: NO];
}

+(FFMemory*) allocateInProcess: (FFProcess*)process WithSize: (mach_vm_size_t)size AtAddress: (mach_vm_address_t)address IsPurgeable: (_Bool)purgeable
{
    return [FFMemory memoryInProcess: process WithSize: size Flags: VM_FLAGS_FIXED | VM_FLAGS_OVERWRITE | (purgeable? VM_FLAGS_PURGABLE : 0) AllocationOptions: FFAllocate | FFFreeOnResize | FFCanGrow | FFCanShrink AtAddress: address];
}

+(FFMemory*) memoryInProcess: (FFProcess*)process AtAddress: (mach_vm_address_t)address OfSize: (mach_vm_size_t)size
{
    return [FFMemory memoryInProcess: process WithSize: size Flags: VM_FLAGS_FIXED AllocationOptions: 0 AtAddress: address];
}

+(FFMemory*) memoryInProcess: (FFProcess*)theProcess WithSize: (mach_vm_address_t)theSize Flags: (int)theFlags AllocationOptions: (FFAllocationOptions)allocOptions AtAddress: (mach_vm_address_t)theAddress
{
    return [[[FFMemory alloc] initInProcess: theProcess WithSize: theSize Flags: theFlags AllocationOptions: allocOptions AtAddress: theAddress] autorelease];
}

-(id) initInProcess: (FFProcess*)theProcess WithSize: (mach_vm_address_t)theSize Flags: (int)theFlags AllocationOptions: (FFAllocationOptions)allocOptions AtAddress: (mach_vm_address_t)theAddress
{
    if ((self = [super init]))
    {
        flags = theFlags;
        options = allocOptions;
        process = theProcess;
        address = theAddress;
        size = theSize;
        
        if (allocOptions & FFAllocate)
        {
            mach_error_t err = mach_vm_allocate(theProcess.task, &theAddress, theSize, theFlags);
            if (err)
            {
                mach_error("mach_vm_allocate", err);
                printf("Allocation error: %u\n", err);
                [self release];
                return nil;
            }
            
            address = theAddress;
        }
    }
    
    return self;
}

-(NSData*) data
{
    return [process dataAtAddress: address OfSize: size];
}

-(mach_vm_size_t) size
{
    return size;
}

-(void) setSize: (mach_vm_size_t)newSize
{
    const vm_prot_t MaxProt = self.maxProtection, Prot = self.protection;
    if (((options & FFCanGrow) && (size < newSize)) || ((options & FFCanShrink) && (size > newSize)))
    {
        NSMutableData *OldData = [[[process dataAtAddress: address OfSize: size] mutableCopy] autorelease];
        if ((options & FFFreeOnResize) && (size))
        {
            mach_error_t err = mach_vm_deallocate(process.task, address, size);
            size = 0;
            if (err)
            {
                mach_error("mach_vm_deallocate", err);
                printf("Deallocation error: %u\n", err);
                return;
            }
            
        }
        
        if (options & FFAllocate)
        {
            mach_vm_address_t Addr = address;
            mach_error_t err = mach_vm_allocate(process.task, &Addr, newSize, flags);
            if (err)
            {
                mach_error("mach_vm_allocate", err);
                printf("Allocation error: %u\n", err);
                return;
            }
            
            if (options & FFCopyOnResize)
            {
                [OldData setLength: newSize];
                [process write: OldData ToAddress: Addr];
            }
            
            address = Addr;
        }
        
        size = newSize;
        self.maxProtection = MaxProt;
        self.protection = Prot;
    }
}

-(vm_prot_t) protection
{
    mach_vm_size_t RegionSize;
    vm_region_basic_info_data_64_t Info;
    mach_port_t ObjectName;
    mach_msg_type_number_t Count = VM_REGION_BASIC_INFO_COUNT_64;
    
    mach_error_t err = mach_vm_region(process.task, &(mach_vm_address_t){ address }, &RegionSize, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&Info, &Count, &ObjectName);
    if (err != KERN_SUCCESS)
    {
        mach_error("mach_vm_region", err);
        printf("Region error: %u\n", err);
        return VM_PROT_NONE;
    }
    
    return Info.protection;
}

-(void) setProtection: (vm_prot_t)protection
{
    mach_error_t err = mach_vm_protect(process.task, address, size, FALSE, protection);
    if (err != KERN_SUCCESS)
    {
        mach_error("mach_vm_protect", err);
        printf("Protection error: %u\n", err);
    }
}

-(vm_prot_t) maxProtection
{
    mach_vm_size_t RegionSize;
    vm_region_basic_info_data_64_t Info;
    mach_port_t ObjectName;
    mach_msg_type_number_t Count = VM_REGION_BASIC_INFO_COUNT_64;
    
    mach_error_t err = mach_vm_region(process.task, &(mach_vm_address_t){ address }, &RegionSize, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&Info, &Count, &ObjectName);
    if (err != KERN_SUCCESS)
    {
        mach_error("mach_vm_region", err);
        printf("Region error: %u\n", err);
        return VM_PROT_NONE;
    }
    
    return Info.max_protection;
}

-(void) setMaxProtection: (vm_prot_t)maxProtection
{
    mach_error_t err = mach_vm_protect(process.task, address, size, TRUE, maxProtection);
    if (err != KERN_SUCCESS)
    {
        mach_error("mach_vm_protect", err);
        printf("Protection error: %u\n", err);
    }
}

-(void) dealloc
{
    if ((options & FFFreeWhenDone) && (size))
    {
        mach_error_t err = mach_vm_deallocate(process.task, address, size);
        size = 0;
        if (err)
        {
            mach_error("mach_vm_deallocate", err);
            printf("Deallocation error: %u\n", err);
        }
        
    }
    
    process = nil;
    
    [super dealloc];
}

@end
