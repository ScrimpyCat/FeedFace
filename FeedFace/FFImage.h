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

#import <Foundation/Foundation.h>

@class FFProcess;


typedef void (^FFIMAGE_ACTION)(const void *data);
typedef void (^FFIMAGE_FILE_ACTION)(const void *file, const void *image, const void *data);

_Bool FFImagePathMatch(NSString *ImagePath1, NSString *ImagePath2);

void FFImageInProcess(FFProcess *Process, mach_vm_address_t ImageLoadAddress, FFIMAGE_ACTION ImageHeaderAction, FFIMAGE_ACTION ImageLoadCommandsAction, FFIMAGE_ACTION ImageDataAction);
uint64_t FFImageStructureSizeInProcess(FFProcess *Process, mach_vm_address_t ImageLoadAddress);
_Bool FFImageInProcessContainsVMAddress(FFProcess *Process, mach_vm_address_t ImageLoadAddress, mach_vm_address_t VMAddress);
_Bool FFImageInProcessContainsSegment(FFProcess *Process, mach_vm_address_t ImageLoadAddress, NSString *SegmentName, mach_vm_address_t *LoadCommandAddress, mach_vm_address_t *VMAddress); //VMAddress directly from Mach-O data structure for that image; in other words it needs to be relocated if you want to reference that address in the process correctly.
_Bool FFImageInProcessContainsSection(FFProcess *Process, mach_vm_address_t ImageLoadAddress, NSString *SegmentName, NSString *SectionName, mach_vm_address_t *LoadCommandAddress, mach_vm_address_t *VMAddress); //VMAddress directly from Mach-O data structure for that image; in other words it needs to be relocated if you want to reference that address in the process correctly.
NSString *FFImageInProcessSegmentContainingVMAddress(FFProcess *Process, mach_vm_address_t ImageLoadAddress, mach_vm_address_t VMAddress);
NSString *FFImageInProcessSectionContainingVMAddress(FFProcess *Process, mach_vm_address_t ImageLoadAddress, mach_vm_address_t VMAddress, NSString **Segment);
mach_vm_address_t FFImageInProcessAddressOfSymbol(FFProcess *Process, mach_vm_address_t ImageLoadAddress, NSString *Symbol);
_Bool FFImageInProcessUsesSharedCacheSlide(FFProcess *Process, mach_vm_address_t ImageLoadAddress);

void FFImageInFile(NSString *ImagePath, cpu_type_t CPUType, FFIMAGE_FILE_ACTION ImageHeaderAction, FFIMAGE_FILE_ACTION ImageLoadCommandsAction, FFIMAGE_FILE_ACTION ImageDataAction);
_Bool FFImageInFileContainsSymbol(NSString *ImagePath, cpu_type_t CPUType, NSString *Symbol, uint8_t *Type, uint8_t *SectionIndex, int16_t *Description, mach_vm_address_t *Value);
NSString *FFImageInFileSegmentContainingAddress(NSString *ImagePath, cpu_type_t CPUType, mach_vm_address_t Address);
