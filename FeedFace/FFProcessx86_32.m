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

#import "FFProcessx86_32.h"
#import "dyld_image32.h"
#import "FFImage.h"
#import "ObjcNewRuntime32.h"
#import "NSValue+MachVMAddress.h"
#import "FFClass.h"

#import <mach/mach.h>
#import <mach/mach_vm.h>
#import <mach-o/dyld_images.h>
#import <mach-o/loader.h>


@interface FFProcessx86_32 ()

-(const class_rw_t32*) classRWOfClass: (mach_vm_address_t)address;
-(const class_ro_t32*) classROOfClass: (mach_vm_address_t)address;

@end

@implementation FFProcessx86_32
{
    task_dyld_info_data_t dyldInfo;
    struct dyld_all_image_infos32 imageInfos;
}

-(id) initWithProcessIdentifier: (pid_t)thePid
{
    mach_port_name_t Task;
    mach_error_t err = task_for_pid(mach_task_self(), thePid, &Task);
    if (err != KERN_SUCCESS)
    {
        mach_error("task_for_pid", err);
        if (err == 5) printf("Invalid PID or not running as root\n");
        
        [self release];
        return nil;
    }
    
    if ((self = [super init]))
    {        
        self.is64 = NO;
        self.cpuType = CPU_TYPE_I386;
        self.task = Task;
        self.pid = thePid;
        self.name = [FFProcess nameOfProcessWithIdentifier: thePid];
        self.path = [FFProcess pathOfProcessWithIdentifier: thePid];
        
        err = task_info(self.task, TASK_DYLD_INFO, (task_info_t)&dyldInfo, &(mach_msg_type_number_t){ TASK_DYLD_INFO_COUNT });
        
        if (err != KERN_SUCCESS)
        {
            mach_error("task_info", err);
            printf("Task info error: %u\n", err);
            [self release];
            return nil;
        }
        
        if (!dyldInfo.all_image_info_addr)
        {
            printf("Error\n");
            [self release];
            return nil;
        }
        
        mach_vm_size_t ReadSize;
        size_t ImageInfosSize = dyldInfo.all_image_info_size;
        if (sizeof(imageInfos) < ImageInfosSize) ImageInfosSize = sizeof(imageInfos); //Later version being used. If needing new elements add them.
        
        err = mach_vm_read_overwrite(self.task, dyldInfo.all_image_info_addr, ImageInfosSize, (mach_vm_address_t)&imageInfos, &ReadSize);
        
        if (err != KERN_SUCCESS)
        {
            mach_error("mach_vm_read_overwrite", err);
            printf("Read error: %u\n", err);
            [self release];
            return nil;
        }
        
        
        self.usesNewRuntime = ![[self findSegment: @"__OBJC"] count];
    }
    
    return self;
}

-(mach_vm_address_t) loadAddressForImage: (NSString*)image
{
    struct dyld_image_info32 ImageInfo;
    const uint32_t InfoArrayCount = imageInfos.infoArrayCount;
    const uint32_t InfoArray = imageInfos.infoArray, ImageInfoSize = sizeof(ImageInfo);
    
    mach_vm_size_t ReadSize;
    if (image)
    {
        _Bool Match = FALSE;
        for (uint32_t Loop = 0; (Loop < InfoArrayCount) && (!Match); Loop++)
        {
            mach_error_t err = mach_vm_read_overwrite(self.task, (mach_vm_address_t)(InfoArray + (ImageInfoSize * Loop)), ImageInfoSize, (mach_vm_address_t)&ImageInfo, &ReadSize);
            
            if (err != KERN_SUCCESS)
            {
                mach_error("mach_vm_read_overwrite", err);
                printf("Read error: %u\n", err);
                return 0;
            }
            
            
            char FilePath[PATH_MAX];
            err = mach_vm_read_overwrite(self.task, (mach_vm_address_t)ImageInfo.imageFilePath, sizeof(FilePath), (mach_vm_address_t)FilePath, &ReadSize);
            
            if (err != KERN_SUCCESS)
            {
                mach_error("mach_vm_read_overwrite", err);
                printf("Read error: %u\n", err);
                return 0;
            }
            
            
            Match = FFImagePathMatch(image, [NSString stringWithUTF8String: FilePath]);
        }
        
        if (!Match)
        {
            printf("Could not find image: %s\n", [image UTF8String]);
            return 0;
        }
    }
    
    else
    {
        //Assumes first element in info array is the app itself.
        mach_error_t err = mach_vm_read_overwrite(self.task, (mach_vm_address_t)InfoArray, ImageInfoSize, (mach_vm_address_t)&ImageInfo, &ReadSize);
        
        if (err != KERN_SUCCESS)
        {
            mach_error("mach_vm_read_overwrite", err);
            printf("Read error: %u\n", err);
            return 0;
        }
    }
    
    return (mach_vm_address_t)ImageInfo.imageLoadAddress;
}

-(mach_vm_address_t) relocateAddress: (mach_vm_address_t)address InImage: (NSString*)image
{
    return (address & 0xfffffff) + [self loadAddressForImage: image];
}

-(NSArray*) images
{
    NSMutableArray *Images = [NSMutableArray array];
    struct dyld_image_info32 ImageInfo;
    const uint32_t InfoArrayCount = imageInfos.infoArrayCount;
    const uint32_t InfoArray = imageInfos.infoArray, ImageInfoSize = sizeof(ImageInfo);
    
    mach_vm_size_t ReadSize;
    for (uint32_t Loop = 0; Loop < InfoArrayCount; Loop++)
    {
        mach_error_t err = mach_vm_read_overwrite(self.task, (mach_vm_address_t)(InfoArray + (ImageInfoSize * Loop)), ImageInfoSize, (mach_vm_address_t)&ImageInfo, &ReadSize);
        
        if (err != KERN_SUCCESS)
        {
            mach_error("mach_vm_read_overwrite", err);
            printf("Read error: %u\n", err);
            return nil;
        }
        
        [Images addObject: [NSValue valueWithAddress: ImageInfo.imageLoadAddress]];
    }
    
    return Images;
}

-(NSString*) filePathForImageAtAddress: (mach_vm_address_t)imageAddress
{
    struct dyld_image_info32 ImageInfo;
    const uint32_t InfoArrayCount = imageInfos.infoArrayCount;
    const uint32_t InfoArray = imageInfos.infoArray, ImageInfoSize = sizeof(ImageInfo);
    
    mach_vm_size_t ReadSize;
    for (uint32_t Loop = 0; Loop < InfoArrayCount; Loop++)
    {
        mach_error_t err = mach_vm_read_overwrite(self.task, (mach_vm_address_t)(InfoArray + (ImageInfoSize * Loop)), ImageInfoSize, (mach_vm_address_t)&ImageInfo, &ReadSize);
        
        if (err != KERN_SUCCESS)
        {
            mach_error("mach_vm_read_overwrite", err);
            printf("Read error: %u\n", err);
            return nil;
        }
        
        
        if ((ImageInfo.imageLoadAddress <= imageAddress))
        {
            if ((ImageInfo.imageLoadAddress + FFImageStructureSizeInProcess(self, ImageInfo.imageLoadAddress)) > imageAddress)
            {
                char FilePath[PATH_MAX];
                err = mach_vm_read_overwrite(self.task, (mach_vm_address_t)ImageInfo.imageFilePath, sizeof(FilePath), (mach_vm_address_t)FilePath, &ReadSize);
                
                if (err != KERN_SUCCESS)
                {
                    mach_error("mach_vm_read_overwrite", err);
                    printf("Read error: %u\n", err);
                    return nil;
                }
                
                
                return [NSString stringWithUTF8String: FilePath];
            }
        }
    }
    
    return nil;
}

-(NSString*) filePathForImageContainingAddress: (mach_vm_address_t)vmAddress
{
    struct dyld_image_info32 ImageInfo;
    const uint32_t InfoArrayCount = imageInfos.infoArrayCount;
    const uint32_t InfoArray = imageInfos.infoArray, ImageInfoSize = sizeof(ImageInfo);
    
    mach_vm_size_t ReadSize;
    for (uint32_t Loop = 0; Loop < InfoArrayCount; Loop++)
    {
        mach_error_t err = mach_vm_read_overwrite(self.task, (mach_vm_address_t)(InfoArray + (ImageInfoSize * Loop)), ImageInfoSize, (mach_vm_address_t)&ImageInfo, &ReadSize);
        
        if (err != KERN_SUCCESS)
        {
            mach_error("mach_vm_read_overwrite", err);
            printf("Read error: %u\n", err);
            return nil;
        }
        
        if (FFImageInProcessContainsVMAddress(self, ImageInfo.imageLoadAddress, vmAddress))
        {
            char FilePath[PATH_MAX];
            err = mach_vm_read_overwrite(self.task, (mach_vm_address_t)ImageInfo.imageFilePath, sizeof(FilePath), (mach_vm_address_t)FilePath, &ReadSize);
            
            if (err != KERN_SUCCESS)
            {
                mach_error("mach_vm_read_overwrite", err);
                printf("Read error: %u\n", err);
                return nil;
            }
            
            
            return [NSString stringWithUTF8String: FilePath];
        }
    }
    
    return nil;
}

-(const class_rw_t32*) classRWOfClass: (mach_vm_address_t)address
{
    const class_t32 *ClassT = [self dataAtAddress: address OfSize: sizeof(class_t32)].bytes;
    if (!ClassT) return NULL;
    
    const class_rw_t32 *ClassRW = [self dataAtAddress: ClassT->data_NEVER_USE & ~(uint32_t)3 OfSize: sizeof(class_rw_t32)].bytes;
    if (!ClassRW) return NULL;
    
    if (ClassRW->flags & RW_REALIZED) return ClassRW;
    return NULL;
}

-(const class_ro_t32*) classROOfClass: (mach_vm_address_t)address
{
    const class_t32 *ClassT = [self dataAtAddress: address OfSize: sizeof(class_t32)].bytes;
    if (!ClassT) return NULL;
    
    const class_rw_t32 *ClassRW = [self dataAtAddress: ClassT->data_NEVER_USE & ~(uint32_t)3 OfSize: sizeof(class_rw_t32)].bytes;
    if (!ClassRW) return NULL;
    
    
    const class_ro_t32 *ClassRO;
    if (ClassRW->flags & RW_REALIZED)
    {
        ClassRO = [self dataAtAddress: ClassRW->ro OfSize: sizeof(class_ro_t32)].bytes;
    }
    
    else ClassRO = (const class_ro_t32*)ClassRW;
    
    return ClassRO;
}

-(NSString*) nameOfObject: (mach_vm_address_t)address
{
    const uint32_t *ObjectISA = [self dataAtAddress: address OfSize: sizeof(uint32_t)].bytes;
    if (!ObjectISA) return nil;
    
    if (self.usesNewRuntime)
    {
        const class_ro_t32 *ClassRO = [self classROOfClass: *ObjectISA];
        if (!ClassRO) return nil;
        
        if (ClassRO->flags & RO_META)
        {
            ClassRO = [self classROOfClass: address];
        }
        
        return [self nullTerminatedStringAtAddress: ClassRO->name];
    }
    
    else
    {
        return ((FFClass*)[FFClass classAtAddress: *ObjectISA InProcess: self]).name; //Lazy optimize later
    }
    
    return nil;
}

-(NSData*) jumpCodeToAddress: (mach_vm_address_t)toAddr FromAddress: (mach_vm_address_t)fromAddr
{
    uint8_t Code[5];
    Code[0] = 0xe9; //jmp rel32
    *(uint32_t*)(Code + 1) = (uint32_t)(toAddr - (fromAddr + 5));
    
    return [NSData dataWithBytes: Code length: 5];
}

@end
