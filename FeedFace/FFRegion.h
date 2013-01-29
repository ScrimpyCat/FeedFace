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
@interface FFRegion : NSObject

@property (nonatomic, readonly) mach_vm_size_t size;
@property (nonatomic, readonly) mach_vm_address_t address;
@property (nonatomic, readonly) vm_region_basic_info_data_64_t info; //later add setters, which will update the region
@property (nonatomic, readonly) mach_port_t objectName;

+(FFRegion*) regionInProcess: (FFProcess*)process AtAddress: (mach_vm_address_t)address;
+(FFRegion*) regionInProcess: (FFProcess*)process AtAddress: (mach_vm_address_t)address OfSize: (mach_vm_size_t)size WithInfo: (vm_region_basic_info_64_t)info ObjectName: (mach_port_t)objectName;

-(id) initInProcess: (FFProcess*)theProcess AtAddress: (mach_vm_address_t)theAddress OfSize: (mach_vm_size_t)theSize WithInfo: (vm_region_basic_info_64_t)theInfo ObjectName: (mach_port_t)theObjectName;
-(const void*) map;

@end
