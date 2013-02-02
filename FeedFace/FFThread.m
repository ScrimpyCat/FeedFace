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

#import "FFThread.h"
#import "FFProcess.h"
#import <mach/thread_act.h>
#import <mach/mach.h>

@implementation FFThread
@synthesize process, threadAct;

+(FFThread*) threadForThread: (thread_act_t)threadAct InProcess: (FFProcess*)proc
{
    return [[[FFThread alloc] initWithThread: threadAct InProcess: proc] autorelease];
}

-(id) initWithThread: (thread_act_t)thread InProcess: (FFProcess*)proc
{
    if ((self = [super init]))
    {
        process = proc;
        threadAct = thread;
    }
    
    return self;
}

-(mach_vm_address_t) pc
{
    thread_state_data_t ThreadState;
    thread_state_flavor_t Flavour = [process threadStateKind];
    mach_error_t err =  thread_get_state(threadAct, Flavour, (thread_state_t)&ThreadState, &(mach_msg_type_number_t){ THREAD_STATE_MAX });
    if (err != KERN_SUCCESS)
    {
        mach_error("thread_get_state", err);
        printf("Thread state query error: %u\n", err);
        return 0;
    }
    
    switch (Flavour)
    {
        case x86_THREAD_STATE32:
            return ((x86_thread_state32_t*)ThreadState)->__eip;
            break;
            
        case x86_THREAD_STATE64:
            return ((x86_thread_state64_t*)ThreadState)->__rip;
            break;
    }
    
    return 0;
}

-(void) setPc: (mach_vm_address_t)pc
{
    _Bool ShouldResume = self.isRunning;
    if (ShouldResume) [self pause];
    
    thread_state_data_t ThreadState;
    thread_state_flavor_t Flavour = [process threadStateKind];
    mach_msg_type_number_t Count = THREAD_STATE_MAX;
    mach_error_t err = thread_get_state(threadAct, Flavour, (thread_state_t)&ThreadState, &Count);
    if (err != KERN_SUCCESS)
    {
        mach_error("thread_get_state", err);
        printf("Thread state query error: %u\n", err);
        if (ShouldResume) [self resume];
        return;
        //return; //should return or return thread to original run state?
    }
    
    switch (Flavour)
    {
        case x86_THREAD_STATE32:
            ((x86_thread_state32_t*)ThreadState)->__eip = (uint32_t)pc;
            break;
            
        case x86_THREAD_STATE64:
            ((x86_thread_state64_t*)ThreadState)->__rip = pc;
            break;
    }
    
    err = thread_set_state(threadAct, Flavour, (thread_state_t)&ThreadState, Count);
    if (err != KERN_SUCCESS)
    {
        mach_error("thread_set_state", err);
        printf("Thread state set error: %u\n", err);
        //return; //should return or return thread to original run state?
    }
    
    if (ShouldResume) [self resume];
}

-(_Bool) isRunning
{
    thread_basic_info_data_t ThreadInfo;
    mach_error_t err = thread_info(threadAct, THREAD_BASIC_INFO, (thread_info_t)&ThreadInfo, &(mach_msg_type_number_t){ THREAD_BASIC_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("thread_info", err);
        printf("Thread info query error: %u\n", err);
        return YES;
    }
    
    return ThreadInfo.run_state == TH_STATE_RUNNING;
}

-(void) pause
{
    mach_error_t err = thread_suspend(threadAct);
    if (err != KERN_SUCCESS)
    {
        mach_error("thread_suspend", err);
        printf("Failed to suspend thread: %u\n", err);
    }
}

-(void) resume
{
    mach_error_t err = thread_resume(threadAct);
    if (err != KERN_SUCCESS)
    {
        mach_error("thread_resume", err);
        printf("Failed to resume thread: %u\n", err);
    }
}

@end
