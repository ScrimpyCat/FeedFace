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

#import "FFProcessPrivate.h"
#import "NSValue+MachVMAddress.h"

#import <mach/mach.h>
#import <mach/mach_vm.h>
#import <mach-o/loader.h>

#import "FFImage.h"

@implementation FFProcess (Reading)

-(NSData*) dataAtAddress: (mach_vm_address_t)address OfSize: (mach_vm_size_t)size
{
    void *Data = calloc(size, 1);
    if (!Data) return nil;
    
    
    mach_vm_size_t RegionSize;
    vm_region_basic_info_data_64_t Info;
    mach_port_t ObjectName;
    mach_msg_type_number_t Count = VM_REGION_BASIC_INFO_COUNT_64;
    
    mach_error_t err = mach_vm_region(self.task, &(mach_vm_address_t){ address }, &RegionSize, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&Info, &Count, &ObjectName);
    if (err != KERN_SUCCESS)
    {
        mach_error("mach_vm_region", err);
        printf("Region error: %u\n", err);
        return nil;
    }
    
    
    err = mach_vm_protect(self.task, address, size, FALSE, Info.protection | VM_PROT_READ);
    if (err != KERN_SUCCESS)
    {
        mach_error("mach_vm_protect", err);
        printf("Protection error: %u\n", err);
        return nil;
    }
    
    
    mach_vm_size_t Read;
    err = mach_vm_read_overwrite(self.task, address, size, (mach_vm_address_t)Data, &Read);
    if (err != KERN_SUCCESS)
    {
        mach_error("mach_vm_read_overwrite", err);
        printf("Read error: %u\n", err);
        return nil;
    }
    
    
    err = mach_vm_protect(self.task, address, size, FALSE, Info.protection);
    if (err != KERN_SUCCESS)
    {
        mach_error("mach_vm_protect", err);
        printf("Protection error: %u\n", err);
        
        if (!(Info.protection & VM_PROT_READ))
        {
            printf("Current protection left with VM_PROT_READ rights, but originally had no read rights\n");
        }
    }
    
    
    return [NSData dataWithBytesNoCopy: Data length: Read];
}

-(NSArray*) dataForSegment: (NSString*)segment Section: (NSString*)section
{
    const _Bool Is64 = self.is64;
    NSArray *LoadCommandAddresses = [self findLoadCommandForSegment: segment Section: section];
    NSMutableArray *Occurrences = [NSMutableArray arrayWithCapacity: [LoadCommandAddresses count]];
    for (NSValue *Section in LoadCommandAddresses)
    {
        const mach_vm_address_t SectionAddress = [Section addressValue];
        const struct section_64 *Sect = [self dataAtAddress: SectionAddress OfSize: sizeof(struct section_64)].bytes;
        
        if (!Sect) continue;
        mach_vm_address_t Address = Is64? Sect->addr : ((const struct section*)Sect)->addr;
        const mach_vm_size_t Size = Is64? Sect->size : ((const struct section*)Sect)->size;
        
        
        Address = [self relocateAddress: Address InImageAtAddress: SectionAddress];
        NSData *SectionData = [self dataAtAddress: Address OfSize: Size];
        if (SectionData) [Occurrences addObject: SectionData];
    }
    
    return Occurrences;
}

-(NSData*) dataForSegment: (NSString*)segment Section: (NSString*)section InImage: (NSString*)image
{
    const _Bool Is64 = self.is64;
    NSArray *LoadCommandAddresses = [self findLoadCommandForSegment: segment Section: section];
    NSData *Data = nil;
    for (NSValue *Section in LoadCommandAddresses)
    {
        const mach_vm_address_t SectionAddress = [Section addressValue];
        const struct section_64 *Sect = [self dataAtAddress: SectionAddress OfSize: sizeof(struct section_64)].bytes;
        
        if (!Sect) continue;
        mach_vm_address_t Address = Is64? Sect->addr : ((const struct section*)Sect)->addr;
        const mach_vm_size_t Size = Is64? Sect->size : ((const struct section*)Sect)->size;
        
        
        NSString *SectionInImage = [self filePathForImageAtAddress: SectionAddress];
        
        if (FFImagePathMatch(SectionInImage, image))
        {
            Address = [self relocateAddress: Address InImage: SectionInImage];
            Data = [self dataAtAddress: Address OfSize: Size];
        }
    }
    
    return Data;
}

-(NSString*) nullTerminatedStringAtAddress: (mach_vm_address_t)address
{
    NSData *String = nil;
    for ( ; ; )
    {
        String = [self dataAtAddress: address OfSize: [String length] + 32];
        if ((!String) || (memchr(String.bytes, 0, [String length]))) break;
    }
    
    return String? [NSString stringWithUTF8String: String.bytes] : nil;
}

-(mach_vm_address_t) addressAtAddress: (mach_vm_address_t)address
{
    const _Bool Is64 = self.is64;
    const void *Addr = [self dataAtAddress: address OfSize: Is64? sizeof(uint64_t) : sizeof(uint32_t)].bytes;
    
    if (Addr) return Is64? *(uint64_t*)Addr : *(uint32_t*)Addr;
    return 0;
}

@end
