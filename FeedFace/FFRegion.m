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

#import "FFRegion.h"
#import "FFProcess.h"
#import "NSValue+MachVMAddress.h"

#import <mach/mach.h>
#import <mach/mach_vm.h>

@implementation FFRegion
{
    FFProcess *process;
    void *data;
}

@synthesize size, address, info, objectName;

+(FFRegion*) regionInProcess: (FFProcess*)process AtAddress: (mach_vm_address_t)address
{
    mach_vm_size_t RegionSize;
    vm_region_basic_info_data_64_t Info;
    mach_port_t ObjectName;
    mach_msg_type_number_t Count = VM_REGION_BASIC_INFO_COUNT_64;
    
    mach_error_t err = mach_vm_region(process.task, &address, &RegionSize, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&Info, &Count, &ObjectName);
    if (err != KERN_SUCCESS)
    {
        mach_error("mach_vm_region", err);
        printf("Region error: %u\n", err);
        return nil;
    }
    
    return [FFRegion regionInProcess: process AtAddress: address OfSize: RegionSize WithInfo: &Info ObjectName: ObjectName];
}

+(FFRegion*) regionInProcess: (FFProcess*)process AtAddress: (mach_vm_address_t)address OfSize: (mach_vm_size_t)size WithInfo: (vm_region_basic_info_64_t)info ObjectName: (mach_port_t)objectName;
{
    return [[[FFRegion alloc] initInProcess: process AtAddress: address OfSize: size WithInfo: info ObjectName: objectName] autorelease];
}

-(id) initInProcess: (FFProcess*)theProcess AtAddress: (mach_vm_address_t)theAddress OfSize: (mach_vm_size_t)theSize WithInfo: (vm_region_basic_info_64_t)theInfo ObjectName: (mach_port_t)theObjectName
{
    if ((self = [super init]))
    {
        process = [theProcess retain];
        size = theSize;
        address = theAddress;
        info = *theInfo;
        objectName = theObjectName;
        
        data = malloc(size);
    }
    
    return self;
}

-(const void*) map
{
    memset(data, size, 0);
    
    
    mach_error_t err = mach_vm_protect(process.task, address, size, FALSE, info.protection | VM_PROT_READ);//VM_PROT_ALL);
    if (err != KERN_SUCCESS)
    {
        /*
         mach_error("mach_vm_protect", err);
         printf("Protection error: %u\n", err);
         */
        return NULL;
    }
    
    
    mach_vm_size_t Read;
    err = mach_vm_read_overwrite(process.task, address, size, (mach_vm_address_t)data, &Read);
    if (err != KERN_SUCCESS)
    {
        /*
         mach_error("mach_vm_read_overwrite", err);
         printf("Read error: %u\n", err);
         */
        return NULL;
    }
    
    
    err = mach_vm_protect(process.task, address, size, FALSE, info.protection);
    if (err != KERN_SUCCESS)
    {
        /*
         mach_error("mach_vm_protect", err);
         printf("Protection error: %u\n", err);
         */
        
        printf("Current protection left as VM_PROT_ALL, but was originally:");
        
        if (info.protection & VM_PROT_READ)
        {
            printf(" VM_PROT_READ");
        }
        
        if (info.protection & VM_PROT_WRITE)
        {
            printf(" VM_PROT_WRITE");
        }
        
        if (info.protection & VM_PROT_EXECUTE)
        {
            printf(" VM_PROT_EXECUTE");
        }
        
        printf("\n");
    }
    
    return data;
}

-(void) dealloc
{
    free(data); data = NULL;
    [process release]; process = nil;
    
    [super dealloc];
}

@end
