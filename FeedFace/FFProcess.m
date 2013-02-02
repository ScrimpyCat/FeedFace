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

#import "FFProcessPrivate.h"
#import "FFProcessx86_32.h"
#import "FFProcessx86_64.h"
#import "dyld_image32.h"
#import "dyld_image64.h"

#import <mach/mach.h>
#import <mach/mach_vm.h>
#import <mach-o/dyld_images.h>
#import <mach-o/loader.h>
#import <libproc.h>

#import "NSValue+MachVMAddress.h"
#import "FFRegion.h"
#import "FFImage.h"
#import "FFClass.h"
#import "FFThread.h"


@implementation FFProcess
@synthesize pid, name, path, is64, task, cpuType, usesNewRuntime;

+(FFProcess*) current
{
    static FFProcess * volatile CurrentProcess = nil;
    if (!CurrentProcess)
    {
        pid_t Pid;
        kern_return_t err = pid_for_task(mach_task_self(), &Pid);
    
        if (err == KERN_SUCCESS)
        {
            if (OSAtomicCompareAndSwapPtrBarrier(nil, [FFProcess processWithIdentifier: Pid], (void**)&CurrentProcess)) [CurrentProcess retain];
        }
    }
    
    return CurrentProcess;
}

+(NSString*) nameOfProcessWithIdentifier: (pid_t)pid
{
    char ProcName[PROC_PIDPATHINFO_MAXSIZE];
    if (!proc_name(pid, ProcName, sizeof(ProcName))) return nil;
    
    return [NSString stringWithUTF8String: ProcName];
}

+(NSString*) pathOfProcessWithIdentifier: (pid_t)pid
{
    char ProcName[PROC_PIDPATHINFO_MAXSIZE];
    if (!proc_pidpath(pid, ProcName, sizeof(ProcName))) return nil;
    
    return [NSString stringWithUTF8String: ProcName];
}

+(FFProcess*) processWithIdentifier: (pid_t)pid
{
    return [[[FFProcess alloc] initWithProcessIdentifier: pid] autorelease];
}

+(FFProcess*) processWithName: (NSString*)name
{
    //Lazy and unnecessary, later change it to manually getting the processes and returning first occurrence
    NSArray *Procs = [FFProcess processesWithName: name];
    if ([Procs count] == 0) return nil;
    else return [Procs objectAtIndex: 0];
}

+(NSArray*) processesWithName: (NSString*)name
{
    struct rlimit MaxProc;
    getrlimit(RLIMIT_NPROC, &MaxProc);
    
    pid_t *PidList = malloc(sizeof(pid_t) * MaxProc.rlim_max);
    if (!PidList) return nil; //Should error?
    FFProcess **Processes = (FFProcess **)malloc(sizeof(FFProcess*) * MaxProc.rlim_max);
    if (!Processes)
    {
        free(PidList);
        return nil; //Should error?
    }
    
    NSUInteger Count = 0;
    int PidCount = proc_listpids(PROC_ALL_PIDS, 0, PidList, (int)(sizeof(pid_t) * MaxProc.rlim_max)); //There won't be support for that many max processes to cause precision issues (at least not currently), so don't worry. Later if it dos become an issue, fix it up to workout if larger than INT_MAX and how many INT_MAX + remaining there are.
    if (PidCount > 0)
    {
        for (int Loop = 0; Loop < PidCount; Loop++)
        {
            if ([[FFProcess nameOfProcessWithIdentifier: PidList[Loop]] isEqualToString: name])
            {
                FFProcess *Proc = [FFProcess processWithIdentifier: PidList[Loop]];
                if (Proc) Processes[Count++] = Proc;
            }
        }
    }
    
    NSArray *Procs = [NSArray arrayWithObjects: Processes count: Count];
    
    free(PidList);
    free(Processes);
    
    return Procs;
}

-(id) initWithProcessIdentifier: (pid_t)thePid
{
    [self release];
    
    vm_map_t Task;
    mach_error_t err = task_for_pid(mach_task_self(), thePid, &Task);
    if (err != KERN_SUCCESS)
    {
        mach_error("task_for_pid", err);
        if (err == 5) printf("Invalid PID or not running as root\n");
        
        return nil;
    }
    
    
    mach_msg_type_number_t Count = TASK_DYLD_INFO_COUNT;
    task_dyld_info_data_t DyldInfo;
    err = task_info(Task, TASK_DYLD_INFO, (task_info_t)&DyldInfo, &Count);
    
    if (err != KERN_SUCCESS)
    {
        mach_error("task_info", err);
        printf("Task info error: %u\n", err);
        return nil;
    }
    
    if (!DyldInfo.all_image_info_addr)
    {
        printf("Error\n");
        return nil;
    }
    
    
    mach_vm_size_t ReadSize;
    union {
        struct dyld_all_image_infos32 infos32;
        struct dyld_all_image_infos64 infos64;
    } ImageInfos;
    
    size_t ImageInfosSize = DyldInfo.all_image_info_size;
    if (sizeof(ImageInfos) < ImageInfosSize) ImageInfosSize = sizeof(ImageInfos); //Later version being used. If needing new elements add them.
    
    err = mach_vm_read_overwrite(Task, DyldInfo.all_image_info_addr, ImageInfosSize, (mach_vm_address_t)&ImageInfos, &ReadSize);
    
    if (err != KERN_SUCCESS)
    {
        mach_error("mach_vm_read_overwrite", err);
        printf("Read error: %u\n", err);
        return nil;
    }
    
    
    const _Bool Is64 = DyldInfo.all_image_info_format == TASK_DYLD_ALL_IMAGE_INFO_64; //else is TASK_DYLD_ALL_IMAGE_INFO_32
    
    mach_vm_address_t DyldImageLoadAddress = (mach_vm_address_t)(Is64? ImageInfos.infos64.dyldImageLoadAddress : ImageInfos.infos32.dyldImageLoadAddress);
    
    
    struct mach_header DyldHeader;
    err = mach_vm_read_overwrite(Task, DyldImageLoadAddress, sizeof(DyldHeader), (mach_vm_address_t)&DyldHeader, &ReadSize);
    
    if (err != KERN_SUCCESS)
    {
        mach_error("mach_vm_read_overwrite", err);
        printf("Read error: %u\n", err);
        return nil;
    }
    
    static NSMutableSet * volatile Processes = nil;
    if (!Processes)
    {
        if (OSAtomicCompareAndSwapPtrBarrier(nil, [NSMutableSet set], (void**)&Processes)) [Processes retain];
    }
    
    FFProcess *Proc = nil;
    /* If ever a problem, use the sub type too, so can know what instructions exactly should be injected */
    if (DyldHeader.cputype == CPU_TYPE_I386)
    {
        Proc = [[FFProcessx86_32 alloc] initWithProcessIdentifier: thePid];
    }
    
    else if (DyldHeader.cputype == CPU_TYPE_X86_64)
    {
        Proc = [[FFProcessx86_64 alloc] initWithProcessIdentifier: thePid];
    }
    
    FFProcess *Other = [Processes member: Proc];
    if ((!Other) && (Proc)) [Processes addObject: Proc];
    else Proc = Other;
    
    return Proc;
}

-(BOOL) isEqual: (id)object
{
    return ([object isKindOfClass: [FFProcess class]]) && (self.pid == ((FFProcess*)object).pid);
}

-(NSUInteger) hash
{
    return self.pid;
}

-(mach_vm_address_t) loadAddressForImage: (NSString*)image
{
    NSLog(@"Error: trying to use placeholder class or need to override in subclass");
    return 0;
}

-(mach_vm_address_t) relocateAddress: (mach_vm_address_t)address
{
    return [self relocateAddress: address InImage: self.name];
}

-(mach_vm_address_t) relocateAddress: (mach_vm_address_t)address InImage: (NSString*)image
{
    NSLog(@"Error: trying to use placeholder class or need to override in subclass");
    return 0;
}

-(mach_vm_address_t) relocateAddress: (mach_vm_address_t)address InImageAtAddress: (mach_vm_address_t)imageAddress
{
    return [self relocateAddress: address InImage: [self filePathForImageAtAddress: imageAddress]];
}

-(mach_vm_address_t) relocateAddress: (mach_vm_address_t)address InImageContainingAddress: (mach_vm_address_t)vmAddress
{
    return [self relocateAddress: address InImage: [self filePathForImageContainingAddress: vmAddress]];
}

-(NSString*) filePathForImageAtAddress: (mach_vm_address_t)imageAddress
{
    NSLog(@"Error: trying to use placeholder class or need to override in subclass");
    return nil;
}

-(NSString*) filePathForImageContainingAddress: (mach_vm_address_t)vmAddress
{
    NSLog(@"Error: trying to use placeholder class or need to override in subclass");
    return nil;
}

-(NSArray*) regions
{
    NSMutableArray *Regions = [NSMutableArray array];
    
    mach_vm_size_t RegionSize = 0;
    mach_vm_address_t RegionAddress = 0, PrevRegionAddress = 0;
    vm_region_basic_info_data_64_t Info;
    mach_port_t ObjectName;
    mach_msg_type_number_t Count = VM_REGION_BASIC_INFO_COUNT_64;
    
    for ( ; RegionAddress >= PrevRegionAddress; PrevRegionAddress = RegionAddress, RegionAddress += RegionSize)
    {
        mach_error_t err = mach_vm_region(self.task, &RegionAddress, &RegionSize, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&Info, &Count, &ObjectName);
        if (err != KERN_SUCCESS) break;
        
        [Regions addObject: [FFRegion regionInProcess: self AtAddress: RegionAddress OfSize: RegionSize WithInfo: &Info ObjectName: ObjectName]];
    }
    
    return Regions;
}

-(NSArray*) images
{
    NSLog(@"Error: trying to use placeholder class or need to override in subclass");
    return nil;
}

-(NSArray*) threads
{
    thread_act_port_array_t Threads;
    mach_msg_type_number_t Count;
    mach_error_t err = task_threads(self.task, &Threads, &Count);
    
    if (err != KERN_SUCCESS)
    {
        mach_error("task_threads", err);
        printf("Task thread query error: %u\n", err);
        
        return nil;
    }
    
    
    NSMutableArray *Thr = [NSMutableArray arrayWithCapacity: Count];
    for (size_t Loop = 0; Loop < Count; Loop++) [Thr addObject: [FFThread threadForThread: Threads[Loop] InProcess: self]];
    
    return Thr;
}

-(thread_state_flavor_t) threadStateKind
{
    NSLog(@"Error: trying to use placeholder class or need to override in subclass");
    return 0;
}

-(NSData*) jumpCodeToAddress: (mach_vm_address_t)toAddr FromAddress: (mach_vm_address_t)fromAddr
{
    NSLog(@"Error: trying to use placeholder class or need to override in subclass");
    return nil;
}

-(NSString*) nameOfObject: (mach_vm_address_t)address
{
    NSLog(@"Error: trying to use placeholder class or need to override in subclass");
    return nil;
}

-(id) classAtAddress: (mach_vm_address_t)address
{
    return [FFClass classAtAddress: address InProcess: self];
}

-(void) dealloc
{
    self.name = nil;
    self.path = nil;
    
    [super dealloc];
}

@end
