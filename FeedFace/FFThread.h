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
#import <FeedFace/FFAddressSet.h>

@class FFProcess;
@interface FFThread : NSObject

@property (nonatomic, readonly, assign) FFProcess *process;
@property (nonatomic, readonly) thread_act_t threadAct;
@property (nonatomic) mach_vm_address_t pc;
@property (nonatomic, readonly) _Bool isRunning;
@property (nonatomic, readonly) uint64_t cpuUsage;
@property (nonatomic, readonly) double cpuUsagePercent;

+(FFThread*) emptyThreadInProcess: (FFProcess*)proc;
+(FFThread*) threadInProcess: (FFProcess*)proc;
+(FFThread*) threadForThread: (thread_act_t)threadAct InProcess: (FFProcess*)proc;
+(FFThread*) threadForThread: (thread_act_t)threadAct InProcess: (FFProcess *)proc ShouldDestroy: (_Bool)destroy;

-(id) initWithThread: (thread_act_t)thread InProcess: (FFProcess*)proc ShouldDestroy: (_Bool)destroy;
-(void) pause;
-(void) pauseWhenNotExecutingAtAddress: (mach_vm_address_t)address;
-(void) pauseWhenNotExecutingInRange: (FFAddressRange)range;
-(void) pauseWhenNotExecutingInSet: (FFAddressSet*)set;
-(void) resume;

@end
