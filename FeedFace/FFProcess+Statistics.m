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

#import "FFProcessPrivate.h"
#import "FFThread.h"
#import <mach/mach.h>
#import <mach/task.h>

@implementation FFProcess (Statistics)

-(uint64_t) cpuUsage
{
    uint64_t TotalUsage = 0;
    for (FFThread *Thread in [self threads]) TotalUsage += Thread.cpuUsage;
    
    return TotalUsage;
}

-(double) cpuUsagePercent
{
    return ((double)self.cpuUsage / (double)TH_USAGE_SCALE) * 100.0;
}

//TODO: needs to be refactor

-(mach_vm_size_t) virtualSize
{
    struct mach_task_basic_info BasicInfo;
    mach_error_t err = task_info(self.task, MACH_TASK_BASIC_INFO, (task_info_t)&BasicInfo, &(mach_msg_type_number_t){ MACH_TASK_BASIC_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task basic info query error: %u\n", err);
        return 0;
    }
    
    return BasicInfo.virtual_size;
}

-(mach_vm_size_t) residentSize
{
    struct mach_task_basic_info BasicInfo;
    mach_error_t err = task_info(self.task, MACH_TASK_BASIC_INFO, (task_info_t)&BasicInfo, &(mach_msg_type_number_t){ MACH_TASK_BASIC_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task basic info query error: %u\n", err);
        return 0;
    }
    
    return BasicInfo.resident_size;
}

-(mach_vm_size_t) residentSizeMax
{
    struct mach_task_basic_info BasicInfo;
    mach_error_t err = task_info(self.task, MACH_TASK_BASIC_INFO, (task_info_t)&BasicInfo, &(mach_msg_type_number_t){ MACH_TASK_BASIC_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task basic info query error: %u\n", err);
        return 0;
    }
    
    return BasicInfo.resident_size_max;
}

-(time_value_t) userTime
{
    struct mach_task_basic_info BasicInfo;
    mach_error_t err = task_info(self.task, MACH_TASK_BASIC_INFO, (task_info_t)&BasicInfo, &(mach_msg_type_number_t){ MACH_TASK_BASIC_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task basic info query error: %u\n", err);
        return (time_value_t){ 0, 0 };
    }
    
    return BasicInfo.user_time;
}

-(time_value_t) systemTime
{
    struct mach_task_basic_info BasicInfo;
    mach_error_t err = task_info(self.task, MACH_TASK_BASIC_INFO, (task_info_t)&BasicInfo, &(mach_msg_type_number_t){ MACH_TASK_BASIC_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task basic info query error: %u\n", err);
        return (time_value_t){ 0, 0 };
    }
    
    return BasicInfo.system_time;
}

-(policy_t) policy
{
    struct mach_task_basic_info BasicInfo;
    mach_error_t err = task_info(self.task, MACH_TASK_BASIC_INFO, (task_info_t)&BasicInfo, &(mach_msg_type_number_t){ MACH_TASK_BASIC_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task basic info query error: %u\n", err);
        return 0;
    }
    
    return BasicInfo.policy;
}

-(uint64_t) suspendCount
{
    struct mach_task_basic_info BasicInfo;
    mach_error_t err = task_info(self.task, MACH_TASK_BASIC_INFO, (task_info_t)&BasicInfo, &(mach_msg_type_number_t){ MACH_TASK_BASIC_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task basic info query error: %u\n", err);
        return 0;
    }
    
    return BasicInfo.suspend_count;
}

-(uint64_t) faults
{
    struct task_events_info EventsInfo;
    mach_error_t err = task_info(self.task, TASK_EVENTS_INFO, (task_info_t)&EventsInfo, &(mach_msg_type_number_t){ TASK_EVENTS_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task events info query error: %u\n", err);
        return 0;
    }
    
    return EventsInfo.faults;
}

-(uint64_t) pageins
{
    struct task_events_info EventsInfo;
    mach_error_t err = task_info(self.task, TASK_EVENTS_INFO, (task_info_t)&EventsInfo, &(mach_msg_type_number_t){ TASK_EVENTS_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task events info query error: %u\n", err);
        return 0;
    }
    
    return EventsInfo.pageins;
}

-(uint64_t) copyOnWriteFaults
{
    struct task_events_info EventsInfo;
    mach_error_t err = task_info(self.task, TASK_EVENTS_INFO, (task_info_t)&EventsInfo, &(mach_msg_type_number_t){ TASK_EVENTS_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task events info query error: %u\n", err);
        return 0;
    }
    
    return EventsInfo.cow_faults;
}

-(uint64_t) messagesSent
{
    struct task_events_info EventsInfo;
    mach_error_t err = task_info(self.task, TASK_EVENTS_INFO, (task_info_t)&EventsInfo, &(mach_msg_type_number_t){ TASK_EVENTS_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task events info query error: %u\n", err);
        return 0;
    }
    
    return EventsInfo.messages_sent;
}

-(uint64_t) messagesReceived
{
    struct task_events_info EventsInfo;
    mach_error_t err = task_info(self.task, TASK_EVENTS_INFO, (task_info_t)&EventsInfo, &(mach_msg_type_number_t){ TASK_EVENTS_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task events info query error: %u\n", err);
        return 0;
    }
    
    return EventsInfo.messages_received;
}

-(uint64_t) machSystemCalls
{
    struct task_events_info EventsInfo;
    mach_error_t err = task_info(self.task, TASK_EVENTS_INFO, (task_info_t)&EventsInfo, &(mach_msg_type_number_t){ TASK_EVENTS_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task events info query error: %u\n", err);
        return 0;
    }
    
    return EventsInfo.syscalls_mach;
}

-(uint64_t) unixSystemCalls
{
    struct task_events_info EventsInfo;
    mach_error_t err = task_info(self.task, TASK_EVENTS_INFO, (task_info_t)&EventsInfo, &(mach_msg_type_number_t){ TASK_EVENTS_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task events info query error: %u\n", err);
        return 0;
    }
    
    return EventsInfo.syscalls_unix;
}

-(uint64_t) contextSwitches
{
    struct task_events_info EventsInfo;
    mach_error_t err = task_info(self.task, TASK_EVENTS_INFO, (task_info_t)&EventsInfo, &(mach_msg_type_number_t){ TASK_EVENTS_INFO_COUNT });
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task events info query error: %u\n", err);
        return 0;
    }
    
    return EventsInfo.csw;
}

@end
