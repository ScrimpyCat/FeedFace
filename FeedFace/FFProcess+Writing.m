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
#import <mach/mach.h>
#import <mach/mach_vm.h>

@implementation FFProcess (Writing)

-(void) writeData: (const void*)data OfSize: (mach_vm_size_t)size ToAddress: (mach_vm_address_t)address
{
    if (!data) return;
        
    
    mach_vm_size_t RegionSize;
    vm_region_basic_info_data_64_t Info;
    mach_port_t ObjectName;
    mach_msg_type_number_t Count = VM_REGION_BASIC_INFO_COUNT_64;
    
    mach_error_t err = mach_vm_region(self.task, &(mach_vm_address_t){ address }, &RegionSize, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&Info, &Count, &ObjectName);
    if (err != KERN_SUCCESS)
    {
        mach_error("mach_vm_region", err);
        printf("Region error: %u\n", err);
        return;
    }
    
    
    err = mach_vm_protect(self.task, address, size, FALSE, Info.protection | VM_PROT_WRITE);
    if (err != KERN_SUCCESS)
    {
        mach_error("mach_vm_protect", err);
        printf("Protection error: %u\n", err);
        return;
    }
    
    
    err = mach_vm_write(self.task, address, (mach_vm_address_t)data, (mach_msg_type_number_t)size);
    if (err != KERN_SUCCESS)
    {
        mach_error("mach_vm_write", err);
        printf("Writing error: %u\n", err);
        return;
    }
    
    
    err = mach_vm_protect(self.task, address, size, FALSE, Info.protection);
    if (err != KERN_SUCCESS)
    {
        mach_error("mach_vm_protect", err);
        printf("Protection error: %u\n", err);
        
        /*
         While the injection should have succeeded, was unable to return
         the protection for that region back to it's original rights.
         */
        
        if (!(Info.protection & VM_PROT_WRITE))
        {
            printf("Current protection left with VM_PROT_WRITE rights, but originally had no write rights\n");
        }
    }
}

-(void) write: (NSData*)data ToAddress: (mach_vm_address_t)address
{
    [self writeData: data.bytes OfSize: [data length] ToAddress: address];
}

-(void) writeAddress: (mach_vm_address_t)addressData ToAddress: (mach_vm_address_t)address
{
    const _Bool Is64 = self.is64;
    [self writeData: Is64? (void*)&(uint64_t){ addressData } : (void*)&(uint32_t){ (uint32_t)addressData } OfSize: Is64? sizeof(uint64_t) : sizeof(uint32_t) ToAddress: address];
}

@end
