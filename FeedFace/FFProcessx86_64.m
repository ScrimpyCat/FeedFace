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

#import "FFProcessx86_64.h"
#import "dyld_image64.h"
#import "FFImage.h"
#import "ObjcNewRuntime64.h"
#import "NSValue+MachVMAddress.h"
#import "FFClass.h"

#import <mach/mach.h>
#import <mach/mach_vm.h>
#import <mach-o/dyld_images.h>
#import <mach-o/loader.h>


@interface FFProcessx86_64 ()

-(const class_rw_t64*) classRWOfClass: (mach_vm_address_t)address;
-(const class_ro_t64*) classROOfClass: (mach_vm_address_t)address;

@end

@implementation FFProcessx86_64
{
    task_dyld_info_data_t dyldInfo;
    struct dyld_all_image_infos64 imageInfos;
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
        self.is64 = YES;
        self.cpuType = CPU_TYPE_X86_64;
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
        
        
        size_t ImageInfosSize = dyldInfo.all_image_info_size;
        if (sizeof(imageInfos) < ImageInfosSize) ImageInfosSize = sizeof(imageInfos); //Later version being used. If needing new elements add them.
        
        const void *AllImageInfoAddress = [self dataAtAddress: dyldInfo.all_image_info_addr OfSize: ImageInfosSize].bytes;
        if (!AllImageInfoAddress)
        {
            [self release];
            return nil;
        }
        
        memcpy(&imageInfos, AllImageInfoAddress, ImageInfosSize);
        
        self.usesNewRuntime = ![[self findSegment: @"__OBJC"] count];
    }
    
    return self;
}

-(mach_vm_address_t) loadAddressForImage: (NSString*)image
{
    mach_vm_address_t ImageLoadAddress = 0;
    const uint32_t InfoArrayCount = imageInfos.infoArrayCount;
    const uint64_t InfoArray = imageInfos.infoArray, ImageInfoSize = sizeof(struct dyld_image_info64);
    
    if (image)
    {
        _Bool Match = FALSE;
        for (uint32_t Loop = 0; (Loop < InfoArrayCount) && (!Match); Loop++)
        {
            const struct dyld_image_info64 *ImageInfo = [self dataAtAddress: (mach_vm_address_t)(InfoArray + (ImageInfoSize * Loop)) OfSize: ImageInfoSize].bytes;
            if (ImageInfo)
            {
                Match = FFImagePathMatch(image, [self nullTerminatedStringAtAddress: ImageInfo->imageFilePath]);
                if (Match) ImageLoadAddress = ImageInfo->imageLoadAddress;
            }
        }
        
        if (!Match) printf("Could not find image: %s\n", [image UTF8String]);
    }
    
    else
    {
        //Assumes first element in info array is the app itself.
        const struct dyld_image_info64 *ImageInfo = [self dataAtAddress: InfoArray OfSize: ImageInfoSize].bytes;
        if (ImageInfo) ImageLoadAddress = ImageInfo->imageLoadAddress;
    }
    
    return ImageLoadAddress;
}

-(mach_vm_address_t) relocateAddress: (mach_vm_address_t)address InImage: (NSString*)image
{
    const mach_vm_address_t ImageLoadAddress = [self loadAddressForImage: image];
    
    __block mach_vm_address_t Slide;
    FFImageInProcess(self, ImageLoadAddress, (FFIMAGE_ACTION)^(struct mach_header_64 *data){
        if (data->flags & MH_PIE) Slide = 0x100000000;
        else Slide = 0;
    }, NULL, NULL);
    
    return address + (ImageLoadAddress - Slide);
}

-(NSArray*) images
{
    NSMutableArray *Images = [NSMutableArray array];
    const uint32_t InfoArrayCount = imageInfos.infoArrayCount;
    const uint64_t InfoArray = imageInfos.infoArray, ImageInfoSize = sizeof(struct dyld_image_info64);
    
    for (uint32_t Loop = 0; Loop < InfoArrayCount; Loop++)
    {
        const struct dyld_image_info64 *ImageInfo = [self dataAtAddress: (mach_vm_address_t)(InfoArray + (ImageInfoSize * Loop)) OfSize: ImageInfoSize].bytes;
        if (ImageInfo) [Images addObject: [NSValue valueWithAddress: ImageInfo->imageLoadAddress]];
    }
    
    return Images;
}

-(NSString*) filePathForImageAtAddress: (mach_vm_address_t)imageAddress
{
    const uint32_t InfoArrayCount = imageInfos.infoArrayCount;
    const uint64_t InfoArray = imageInfos.infoArray, ImageInfoSize = sizeof(struct dyld_image_info64);
    
    for (uint32_t Loop = 0; Loop < InfoArrayCount; Loop++)
    {
        const struct dyld_image_info64 *ImageInfo = [self dataAtAddress: (mach_vm_address_t)(InfoArray + (ImageInfoSize * Loop)) OfSize: ImageInfoSize].bytes;
        if (!ImageInfo) continue;
        
        const mach_vm_address_t ImageLoadAddress = ImageInfo->imageLoadAddress;
        if ((ImageLoadAddress <= imageAddress))
        {
            if ((ImageLoadAddress + FFImageStructureSizeInProcess(self, ImageLoadAddress)) > imageAddress)
            {
                return [self nullTerminatedStringAtAddress: (mach_vm_address_t)ImageInfo->imageFilePath];
            }
        }
    }
    
    return nil;
}

-(NSString*) filePathForImageContainingAddress: (mach_vm_address_t)vmAddress
{
    const uint32_t InfoArrayCount = imageInfos.infoArrayCount;
    const uint64_t InfoArray = imageInfos.infoArray, ImageInfoSize = sizeof(struct dyld_image_info64);
    
    for (uint32_t Loop = 0; Loop < InfoArrayCount; Loop++)
    {
        const struct dyld_image_info64 *ImageInfo = [self dataAtAddress: (mach_vm_address_t)(InfoArray + (ImageInfoSize * Loop)) OfSize: ImageInfoSize].bytes;
        if (!ImageInfo) continue;
        
        
        if (FFImageInProcessContainsVMAddress(self, ImageInfo->imageLoadAddress, vmAddress))
        {
            return [self nullTerminatedStringAtAddress: (mach_vm_address_t)ImageInfo->imageFilePath];
        }
    }
    
    return nil;
}

-(thread_state_flavor_t) threadStateKind
{
    return x86_THREAD_STATE64;
}

-(const class_rw_t64*) classRWOfClass: (mach_vm_address_t)address
{
    const class_t64 *ClassT = [self dataAtAddress: address OfSize: sizeof(class_t64)].bytes;
    if (!ClassT) return NULL;
    
    const class_rw_t64 *ClassRW = [self dataAtAddress: ClassT->data_NEVER_USE & ~(uint64_t)3 OfSize: sizeof(class_rw_t64)].bytes;
    if (!ClassRW) return NULL;
    
    if (ClassRW->flags & RW_REALIZED) return ClassRW;
    return NULL;
}

-(const class_ro_t64*) classROOfClass: (mach_vm_address_t)address
{
    const class_t64 *ClassT = [self dataAtAddress: address OfSize: sizeof(class_t64)].bytes;
    if (!ClassT) return NULL;
    
    const class_rw_t64 *ClassRW = [self dataAtAddress: ClassT->data_NEVER_USE & ~(uint64_t)3 OfSize: sizeof(class_rw_t64)].bytes;
    if (!ClassRW) return NULL;
    
    
    const class_ro_t64 *ClassRO;
    if (ClassRW->flags & RW_REALIZED)
    {
        ClassRO = [self dataAtAddress: ClassRW->ro OfSize: sizeof(class_ro_t64)].bytes;
    }
    
    else ClassRO = (const class_ro_t64*)ClassRW;
    
    return ClassRO;
}

-(NSString*) nameOfObject: (mach_vm_address_t)address
{
    if (self.usesNewRuntime)
    {
        //Check to see if it's a tagged pointer (refer to objc-config.h in the future to see if this needs to be applied to other environments)
        if (address & 1)
        {
            //don't handle yet
            return nil;
        }
        
        const uint64_t *ObjectISA = [self dataAtAddress: address OfSize: sizeof(uint64_t)].bytes;
        if (!ObjectISA) return nil;
        
        const class_ro_t64 *ClassRO = [self classROOfClass: *ObjectISA];
        if (!ClassRO) return nil;
        
        if (ClassRO->flags & RO_META)
        {
            ClassRO = [self classROOfClass: address];
        }
        
        return [self nullTerminatedStringAtAddress: ClassRO->name];
    }
    
    else
    {
        const uint64_t *ObjectISA = [self dataAtAddress: address OfSize: sizeof(uint64_t)].bytes;
        if (!ObjectISA) return nil;
        
        return ((FFClass*)[FFClass classAtAddress: *ObjectISA InProcess: self]).name; //Lazy optimize later
    }
    
    return nil;
}

extern const void x86_64JumpCodeEnd, x86_64JumpCode, x86_64JumpCodeAddress;
-(NSData*) jumpCodeToAddress: (mach_vm_address_t)toAddr FromAddress: (mach_vm_address_t)fromAddr
{
    const ptrdiff_t Length = &x86_64JumpCodeEnd - &x86_64JumpCode;
    uint8_t Code[Length];
    memcpy(Code, &x86_64JumpCode, Length);
    *(uint64_t*)(Code + (&x86_64JumpCodeAddress - &x86_64JumpCode)) = toAddr;
    
    return [NSData dataWithBytes: Code length: Length];
}

@end
