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

typedef enum {
    FFAllocate = 1,
    FFFreeOnResize = 2,
    FFFreeWhenDone = 4,
    FFCopyOnResize = 8,
    FFCanGrow = 16,
    FFCanShrink = 32
} FFAllocationOptions;

@class FFProcess;
@interface FFMemory : NSObject

@property (nonatomic, readonly, assign) FFProcess *process;
@property (nonatomic, readonly) mach_vm_address_t address;
@property (nonatomic) mach_vm_size_t size;
@property (nonatomic, readonly) NSData *data;
@property (nonatomic) vm_prot_t protection;
@property (nonatomic) vm_prot_t maxProtection;
@property (nonatomic) vm_inherit_t inheritance;
@property (nonatomic, readonly) _Bool shared;
@property (nonatomic, readonly) _Bool reserved;
@property (nonatomic, readonly) memory_object_offset_t offset;
@property (nonatomic) vm_behavior_t behaviour;
@property (nonatomic, readonly) unsigned short userWiredCount;

+(FFMemory*) allocateInProcess: (FFProcess*)process WithSize: (mach_vm_size_t)size;
+(FFMemory*) allocateInProcess: (FFProcess*)process WithSize: (mach_vm_size_t)size IsPurgeable: (_Bool)purgeable;
+(FFMemory*) allocateInProcess: (FFProcess*)process WithSize: (mach_vm_size_t)size AtAddress: (mach_vm_address_t)address;
+(FFMemory*) allocateInProcess: (FFProcess*)process WithSize: (mach_vm_size_t)size AtAddress: (mach_vm_address_t)address IsPurgeable: (_Bool)purgeable;
+(FFMemory*) memoryInProcess: (FFProcess*)process AtAddress: (mach_vm_address_t)address OfSize: (mach_vm_size_t)size;
+(FFMemory*) memoryInProcess: (FFProcess*)theProcess WithSize: (mach_vm_address_t)theSize Flags: (int)theFlags AllocationOptions: (FFAllocationOptions)allocOptions AtAddress: (mach_vm_address_t)theAddress;

-(id) initInProcess: (FFProcess*)theProcess WithSize: (mach_vm_address_t)theSize Flags: (int)theFlags AllocationOptions: (FFAllocationOptions)allocOptions AtAddress: (mach_vm_address_t)theAddress;

@end
