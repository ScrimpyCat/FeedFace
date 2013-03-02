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

#import "FFImage.h"
#import "FFProcess.h"

#import <mach-o/loader.h>
#import <mach/mach_vm.h>
#import <mach/mach.h>


_Bool FFImagePathMatch(NSString *ImagePath1, NSString *ImagePath2)
{
    if ([ImagePath1 isAbsolutePath] && [ImagePath2 isAbsolutePath]) //Full path
    {
        return [ImagePath1 isEqualToString: ImagePath2];
    }
    
    else
    {
        return [[ImagePath1 lastPathComponent] isEqualToString: [ImagePath2 lastPathComponent]];
    }
}

void FFImageInProcess(FFProcess *Process, mach_vm_address_t ImageLoadAddress, FFIMAGE_ACTION ImageHeaderAction, FFIMAGE_ACTION ImageLoadCommandsAction, FFIMAGE_ACTION ImageDataAction)
{
    if ((ImageHeaderAction) || (ImageLoadCommandsAction) || (ImageDataAction))
    {
        const mach_port_name_t Task = Process.task;
        const _Bool Is64 = Process.is64;
        
        
        union {
            struct mach_header header;
            struct mach_header_64 header64;
        } Header;
        const size_t HeaderSize = (Is64? sizeof(struct mach_header_64) : sizeof(struct mach_header));
        
        mach_vm_size_t ReadSize;
        mach_error_t err = mach_vm_read_overwrite(Task, ImageLoadAddress, HeaderSize, (mach_vm_address_t)&Header, &ReadSize);
        
        if (err != KERN_SUCCESS)
        {
            mach_error("mach_vm_read_overwrite", err);
            printf("Read error: %u\n", err);
            return;
        }
        
        
        if (ImageHeaderAction) ImageHeaderAction(&Header);
        
        
        if ((ImageLoadCommandsAction) || (ImageDataAction))
        {
            void *LoadCommands = malloc(Header.header.sizeofcmds);
            if (!LoadCommands)
            {
                printf("Could not allocate memory to copy load commands\n");
                return;
            }
            
            
            err = mach_vm_read_overwrite(Task, ImageLoadAddress + HeaderSize, Header.header.sizeofcmds, (mach_vm_address_t)LoadCommands, &ReadSize);
            
            if (err != KERN_SUCCESS)
            {
                mach_error("mach_vm_read_overwrite", err);
                printf("Read error: %u\n", err);
                free(LoadCommands);
                return;
            }
            
            
            
            ptrdiff_t CommandSize = 0;
            for (uint32_t Loop2 = 0; Loop2 < Header.header.ncmds; Loop2++)
            {
                struct load_command *LoadCommand = LoadCommands + CommandSize;
                
                if (ImageLoadCommandsAction) ImageLoadCommandsAction(LoadCommand);
                
                if (ImageDataAction)
                {
                    const uint32_t cmd = LoadCommand->cmd;
                    if ((cmd == LC_SEGMENT_64) || (cmd == LC_SEGMENT))
                    {
                        mach_vm_address_t SegmentAddress;
                        mach_vm_size_t SegmentSize;
                        if (Is64)
                        {
                            const struct segment_command_64* const Segment = (struct segment_command_64*)(LoadCommands + CommandSize);
                            SegmentAddress = ImageLoadAddress + Segment->vmaddr;
                            SegmentSize = Segment->vmsize;
                        }
                        
                        else
                        {
                            const struct segment_command* const Segment = (struct segment_command*)(LoadCommands + CommandSize);
                            SegmentAddress = ImageLoadAddress + Segment->vmaddr;
                            SegmentSize = Segment->vmsize;
                        }
                        
                        
                        void *SegmentData = malloc(SegmentSize);
                        if (!SegmentData)
                        {
                            printf("Could not allocate memory to copy segment data\n");
                            return;
                        }
                        
                        err = mach_vm_read_overwrite(Task, SegmentAddress, SegmentSize, (mach_vm_address_t)SegmentData, &ReadSize);
                        
                        if (err != KERN_SUCCESS)
                        {
                            mach_error("mach_vm_read_overwrite", err);
                            printf("Read error: %u\n", err);
                            free(LoadCommands);
                            free(SegmentData);
                            return;
                        }
                        
                        
                        ImageDataAction(SegmentData);
                    }
                }
                
                CommandSize += LoadCommand->cmdsize;
            }
            
            free(LoadCommands);
        }
    }
}

uint64_t FFImageStructureSizeInProcess(FFProcess *Process, mach_vm_address_t ImageLoadAddress)
{
    __block uint64_t ImageSize = 0;
    
    FFImageInProcess(Process, ImageLoadAddress, Process.is64? (FFIMAGE_ACTION)^(struct mach_header_64 *data){
        ImageSize += sizeof(*data) + data->sizeofcmds;
    } : (FFIMAGE_ACTION)^(struct mach_header *data){
        ImageSize += sizeof(*data) + data->sizeofcmds;
    }, NULL, NULL);
    
    
    return ImageSize;
}

_Bool FFImageInProcessContainsVMAddress(FFProcess *Process, mach_vm_address_t ImageLoadAddress, mach_vm_address_t VMAddress)
{
    __block _Bool ContainsAddress = NO;
    FFImageInProcess(Process, ImageLoadAddress, NULL, Process.is64? (FFIMAGE_ACTION)^(struct segment_command_64 *data){
        if (data->cmd == LC_SEGMENT_64)
        {
            const mach_vm_address_t Addr = data->vmaddr;
            if ((Addr <= VMAddress) && ((Addr + data->vmsize) > VMAddress)) ContainsAddress = YES;  
        }
    } : (FFIMAGE_ACTION)^(struct segment_command *data){
        if (data->cmd == LC_SEGMENT)
        {
            const mach_vm_address_t Addr = data->vmaddr;
            if ((Addr <= VMAddress) && ((Addr + data->vmsize) > VMAddress)) ContainsAddress = YES;  
        }
    }, NULL);
    
    return ContainsAddress;
}

_Bool FFImageInProcessContainsSegment(FFProcess *Process, mach_vm_address_t ImageLoadAddress, NSString *SegmentName, mach_vm_address_t *LoadCommandAddress, mach_vm_address_t *VMAddress)
{
    __block _Bool Found = NO;
    __block mach_vm_address_t SegmentLoadCommand = ImageLoadAddress + (Process.is64? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    
    FFImageInProcess(Process, ImageLoadAddress, NULL, Process.is64? (FFIMAGE_ACTION)^(struct segment_command_64 *data){
        if ((data->cmd == LC_SEGMENT_64) && (!strncmp([SegmentName UTF8String], data->segname, 16)))
        {
            if (VMAddress) *VMAddress = data->vmaddr;
            if (LoadCommandAddress) *LoadCommandAddress = SegmentLoadCommand;
            Found = YES;
        }
        
        SegmentLoadCommand += data->cmdsize;
    } : (FFIMAGE_ACTION)^(struct segment_command *data){
        if ((data->cmd == LC_SEGMENT) && (!strncmp([SegmentName UTF8String], data->segname, 16)))
        {
            if (VMAddress) *VMAddress = data->vmaddr;
            if (LoadCommandAddress) *LoadCommandAddress = SegmentLoadCommand;
            Found = YES;
        }
        
        SegmentLoadCommand += data->cmdsize;
    }, NULL);
    
    return Found;
}

_Bool FFImageInProcessContainsSection(FFProcess *Process, mach_vm_address_t ImageLoadAddress, NSString *SegmentName, NSString *SectionName, mach_vm_address_t *LoadCommandAddress, mach_vm_address_t *VMAddress)
{
    __block _Bool Found = NO;
    __block mach_vm_address_t SectionLoadCommand = ImageLoadAddress + (Process.is64? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    
    FFImageInProcess(Process, ImageLoadAddress, NULL, Process.is64? (FFIMAGE_ACTION)^(struct segment_command_64 *data){
        if ((data->cmd == LC_SEGMENT_64) && (!strncmp([SegmentName UTF8String], data->segname, 16)))
        {
            SectionLoadCommand += sizeof(struct segment_command_64);
            size_t SectCount = data->nsects;
            struct section_64 *Section = (void*)data + sizeof(struct segment_command_64);
            for (size_t Loop = 0; Loop < SectCount; Loop++)
            {
                if (!strncmp([SectionName UTF8String], Section[Loop].sectname, 16))
                {
                    if (VMAddress) *VMAddress = Section[Loop].addr;
                    if (LoadCommandAddress) *LoadCommandAddress = SectionLoadCommand;
                    Found = YES;
                }
                
                SectionLoadCommand += sizeof(struct section_64);
            }
        }
        
        else SectionLoadCommand += data->cmdsize;
    } : (FFIMAGE_ACTION)^(struct segment_command *data){
        if ((data->cmd == LC_SEGMENT) && (!strncmp([SegmentName UTF8String], data->segname, 16)))
        {
            SectionLoadCommand += sizeof(struct segment_command);
            size_t SectCount = data->nsects;
            struct section *Section = (void*)data + sizeof(struct segment_command);
            for (size_t Loop = 0; Loop < SectCount; Loop++)
            {
                if (!strncmp([SectionName UTF8String], Section[Loop].sectname, 16))
                {
                    if (VMAddress) *VMAddress = Section[Loop].addr;
                    if (LoadCommandAddress) *LoadCommandAddress = SectionLoadCommand;
                    Found = YES;
                }
                
                SectionLoadCommand += sizeof(struct section);
            }
        }
        
        else SectionLoadCommand += data->cmdsize;
    }, NULL);
    
    return Found;
}

NSString *FFImageInProcessSegmentContainingVMAddress(FFProcess *Process, mach_vm_address_t ImageLoadAddress, mach_vm_address_t VMAddress)
{
    __block NSString *Segment = nil;
    FFImageInProcess(Process, ImageLoadAddress, NULL, Process.is64? (FFIMAGE_ACTION)^(struct segment_command_64 *data){
        if (data->cmd == LC_SEGMENT_64)
        {
            if ((VMAddress >= data->vmaddr) && (VMAddress <= (data->vmaddr + data->vmsize)))
            {
                Segment = [NSString stringWithUTF8String: data->segname];
            }
        }
    } : (FFIMAGE_ACTION)^(struct segment_command *data){
        if (data->cmd == LC_SEGMENT)
        {
            if ((VMAddress >= data->vmaddr) && (VMAddress <= (data->vmaddr + data->vmsize)))
            {
                Segment = [NSString stringWithUTF8String: data->segname];
            }
        }
    }, NULL);
    
    return Segment;
}

NSString *FFImageInProcessSectionContainingVMAddress(FFProcess *Process, mach_vm_address_t ImageLoadAddress, mach_vm_address_t VMAddress, NSString **Segment)
{
    __block NSString *SectionName = nil;
    __block mach_vm_address_t SectionLoadCommand = ImageLoadAddress + (Process.is64? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    
    FFImageInProcess(Process, ImageLoadAddress, NULL, Process.is64? (FFIMAGE_ACTION)^(struct segment_command_64 *data){
        if (data->cmd == LC_SEGMENT_64)
        {
            if ((VMAddress >= data->vmaddr) && (VMAddress <= (data->vmaddr + data->vmsize)))
            {
                SectionLoadCommand += sizeof(struct segment_command_64);
                size_t SectCount = data->nsects;
                struct section_64 *Section = (void*)data + sizeof(struct segment_command_64);
                for (size_t Loop = 0; Loop < SectCount; Loop++)
                {
                    if ((VMAddress >= Section->addr) && (VMAddress <= (Section->addr + Section->size)))
                    {
                        if (Segment) *Segment = [NSString stringWithUTF8String: Section->segname];
                        SectionName = [NSString stringWithUTF8String: Section->sectname];
                    }
                    
                    SectionLoadCommand += sizeof(struct section_64);
                }
            }
        }
        
        else SectionLoadCommand += data->cmdsize;
    } : (FFIMAGE_ACTION)^(struct segment_command *data){
        if (data->cmd == LC_SEGMENT)
        {
            if ((VMAddress >= data->vmaddr) && (VMAddress <= (data->vmaddr + data->vmsize)))
            {
                SectionLoadCommand += sizeof(struct segment_command);
                size_t SectCount = data->nsects;
                struct section *Section = (void*)data + sizeof(struct segment_command);
                for (size_t Loop = 0; Loop < SectCount; Loop++)
                {
                    if ((VMAddress >= Section->addr) && (VMAddress <= (Section->addr + Section->size)))
                    {
                        if (Segment) *Segment = [NSString stringWithUTF8String: Section->segname];
                        SectionName = [NSString stringWithUTF8String: Section->sectname];
                    }
                    
                    SectionLoadCommand += sizeof(struct section);
                }
            }
        }
        
        else SectionLoadCommand += data->cmdsize;
    }, NULL);
}
