/*
 *  Copyright (c) 2013, Stefan Johnson                                                  
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

@class FFInjector, FFProcess;
typedef void (^FFINJECTION)(FFInjector *injector);

@interface FFInjector : NSObject

@property (readonly, assign) FFProcess *process;
@property (copy) id data;
@property (retain) NSDictionary *additionalInfo;
@property (copy) FFINJECTION enabler;
@property (copy) FFINJECTION disabler;
@property _Bool disableOnEnablerSet;
@property _Bool disableOnDisablerSet;
@property _Bool disableOnRelease;
@property (readonly) _Bool enabled;

+(id) inject: (id<NSCopying>)data InProcess: (FFProcess*)process;
+(id) inject: (id<NSCopying>)data AdditionalInfo: (NSDictionary*)info InProcess: (FFProcess*)process;

-(id) initWithInjectionData: (id<NSCopying>)theData AdditionalInfo: (NSDictionary*)info InProcess: (FFProcess*)proc;
-(void) enable;
-(void) disable;

@end

/*
 Subclassed rather than used categories (as could store the data in additionalInfo) for FFInjector, is so it offers simple and obvious way to query
 the new data if decided to override either the default enabler or disabler.
 */
@interface FFDataInjector : FFInjector

@property (readonly) mach_vm_address_t address;
@property (readonly, retain) NSData *originalData;

+(FFDataInjector*) inject: (NSData*)data ToAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process;
+(FFDataInjector*) inject: (NSData*)data AdditionalInfo: (NSDictionary*)info ToAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process;

@end


typedef NSData *(^FFCODEINJECTOR_JUMPCODE)(mach_vm_address_t from, mach_vm_address_t to, mach_vm_size_t *maxSize); //Set *maxSize to the largest possible size of data that this function could return/produce

@interface FFCodeInjector : FFInjector

@property (readonly) mach_vm_address_t address;
@property (readonly, retain) NSData *originalData;
@property (readonly, copy) NSData *jumpCode;
@property (readonly) mach_vm_address_t dlsymPtr;
@property _Bool fillWithNops;

+(FFCodeInjector*) injectCode: (NSData*)code ToAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process;
+(FFCodeInjector*) injectCode: (NSData*)code AdditionalInfo: (NSDictionary*)info ToAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process;
+(FFCodeInjector*) injectCodecaveToCode: (NSData*)code FromAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process;
+(FFCodeInjector*) injectCodecaveToCode: (NSData*)code AdditionalInfo: (NSDictionary*)info FromAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process;
+(FFCodeInjector*) injectCodecaveToOriginalCodeFollowedByCode: (NSData*)code FromAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process;
+(FFCodeInjector*) injectCodecaveToOriginalCodeFollowedByCode: (NSData*)code AdditionalInfo: (NSDictionary*)info FromAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process;
+(FFCodeInjector*) injectCodecaveToCode: (NSData*)code FollowedByOriginalCodeFromAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process;
+(FFCodeInjector*) injectCodecaveToCode: (NSData*)code AdditionalInfo: (NSDictionary*)info FollowedByOriginalCodeFromAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process;

-(void) customJumpCode: (FFCODEINJECTOR_JUMPCODE)jumpCodeCreator; //pass NULL to use default

@end
