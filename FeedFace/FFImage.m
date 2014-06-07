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

#import <libkern/OSByteOrder.h>
#import <mach-o/fat.h>
#import <mach-o/nlist.h>
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
        const _Bool Is64 = Process.is64;
        
        
        const size_t HeaderSize = (Is64? sizeof(struct mach_header_64) : sizeof(struct mach_header));
        const struct mach_header *Header = [Process dataAtAddress: ImageLoadAddress OfSize: HeaderSize].bytes;
        if (!Header) return;
        
        
        if (ImageHeaderAction) ImageHeaderAction(Header);
        
        
        if ((ImageLoadCommandsAction) || (ImageDataAction))
        {
            const void *LoadCommands = [Process dataAtAddress: ImageLoadAddress + HeaderSize OfSize: Header->sizeofcmds].bytes;
            if (!LoadCommands) return;
            
            
            ptrdiff_t CommandSize = 0;
            for (uint32_t Loop2 = 0; Loop2 < Header->ncmds; Loop2++)
            {
                const struct load_command *LoadCommand = LoadCommands + CommandSize;
                
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
                        
                        
                        const void *SegmentData = [Process dataAtAddress: SegmentAddress OfSize: SegmentSize].bytes;
                        if (!SegmentData) return;
                        
                        ImageDataAction(SegmentData);
                    }
                }
                
                CommandSize += LoadCommand->cmdsize;
            }
        }
    }
}

uint64_t FFImageStructureSizeInProcess(FFProcess *Process, mach_vm_address_t ImageLoadAddress)
{
    __block uint64_t ImageSize = 0;
    
    FFImageInProcess(Process, ImageLoadAddress, Process.is64? (FFIMAGE_ACTION)^(const struct mach_header_64 *data){
        ImageSize += sizeof(*data) + data->sizeofcmds;
    } : (FFIMAGE_ACTION)^(const struct mach_header *data){
        ImageSize += sizeof(*data) + data->sizeofcmds;
    }, NULL, NULL);
    
    
    return ImageSize;
}

_Bool FFImageInProcessContainsVMAddress(FFProcess *Process, mach_vm_address_t ImageLoadAddress, mach_vm_address_t VMAddress)
{
    __block _Bool ContainsAddress = NO;
    FFImageInProcess(Process, ImageLoadAddress, NULL, Process.is64? (FFIMAGE_ACTION)^(const struct segment_command_64 *data){
        if (data->cmd == LC_SEGMENT_64)
        {
            const mach_vm_address_t Addr = data->vmaddr;
            if ((Addr <= VMAddress) && ((Addr + data->vmsize) > VMAddress)) ContainsAddress = YES;  
        }
    } : (FFIMAGE_ACTION)^(const struct segment_command *data){
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
    
    FFImageInProcess(Process, ImageLoadAddress, NULL, Process.is64? (FFIMAGE_ACTION)^(const struct segment_command_64 *data){
        if ((data->cmd == LC_SEGMENT_64) && (!strncmp([SegmentName UTF8String], data->segname, 16)))
        {
            if (VMAddress) *VMAddress = data->vmaddr;
            if (LoadCommandAddress) *LoadCommandAddress = SegmentLoadCommand;
            Found = YES;
        }
        
        SegmentLoadCommand += data->cmdsize;
    } : (FFIMAGE_ACTION)^(const struct segment_command *data){
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
    
    FFImageInProcess(Process, ImageLoadAddress, NULL, Process.is64? (FFIMAGE_ACTION)^(const struct segment_command_64 *data){
        if ((data->cmd == LC_SEGMENT_64) && (!strncmp([SegmentName UTF8String], data->segname, 16)))
        {
            SectionLoadCommand += sizeof(struct segment_command_64);
            size_t SectCount = data->nsects;
            const struct section_64 *Section = (const void*)data + sizeof(struct segment_command_64);
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
    } : (FFIMAGE_ACTION)^(const struct segment_command *data){
        if ((data->cmd == LC_SEGMENT) && (!strncmp([SegmentName UTF8String], data->segname, 16)))
        {
            SectionLoadCommand += sizeof(struct segment_command);
            size_t SectCount = data->nsects;
            const struct section *Section = (const void*)data + sizeof(struct segment_command);
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
    FFImageInProcess(Process, ImageLoadAddress, NULL, Process.is64? (FFIMAGE_ACTION)^(const struct segment_command_64 *data){
        if (data->cmd == LC_SEGMENT_64)
        {
            if ((VMAddress >= data->vmaddr) && (VMAddress <= (data->vmaddr + data->vmsize)))
            {
                Segment = [NSString stringWithUTF8String: data->segname];
            }
        }
    } : (FFIMAGE_ACTION)^(const struct segment_command *data){
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
    
    FFImageInProcess(Process, ImageLoadAddress, NULL, Process.is64? (FFIMAGE_ACTION)^(const struct segment_command_64 *data){
        if (data->cmd == LC_SEGMENT_64)
        {
            if ((VMAddress >= data->vmaddr) && (VMAddress <= (data->vmaddr + data->vmsize)))
            {
                SectionLoadCommand += sizeof(struct segment_command_64);
                size_t SectCount = data->nsects;
                const struct section_64 *Section = (const void*)data + sizeof(struct segment_command_64);
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
    } : (FFIMAGE_ACTION)^(const struct segment_command *data){
        if (data->cmd == LC_SEGMENT)
        {
            if ((VMAddress >= data->vmaddr) && (VMAddress <= (data->vmaddr + data->vmsize)))
            {
                SectionLoadCommand += sizeof(struct segment_command);
                size_t SectCount = data->nsects;
                const struct section *Section = (const void*)data + sizeof(struct segment_command);
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
    
    return SectionName;
}

mach_vm_address_t FFImageInProcessAddressOfSymbol(FFProcess *Process, mach_vm_address_t ImageLoadAddress, NSString *Symbol)
{
    mach_vm_address_t Address = 0;
    NSString *Image = [Process filePathForImageAtAddress: ImageLoadAddress];
    if (FFImageInFileContainsSymbol(Image, Process.cpuType, Symbol, NULL, NULL, NULL, &Address))
    {
        Address = [Process relocateAddress: Address InImage: Image];
    }
    
    return Address;
}

_Bool FFImageUsesSharedCacheSlide(FFProcess *Process, mach_vm_address_t ImageLoadAddress)
{
    __block _Bool UsesSharedCacheSlide = FALSE;
    FFImageInProcess(Process, ImageLoadAddress, Process.is64? (FFIMAGE_ACTION)^(const struct mach_header_64 *data){
        UsesSharedCacheSlide = data->flags & 0x80000000;
    } : (FFIMAGE_ACTION)^(const struct mach_header *data){
        UsesSharedCacheSlide = data->flags & 0x80000000;
    }, NULL, NULL);

    return UsesSharedCacheSlide;
}

void FFImageInFile(NSString *ImagePath, cpu_type_t CPUType, FFIMAGE_FILE_ACTION ImageHeaderAction, FFIMAGE_FILE_ACTION ImageLoadCommandsAction, FFIMAGE_FILE_ACTION ImageDataAction)
{
    if ((ImageHeaderAction) || (ImageLoadCommandsAction) || (ImageDataAction))
    {
        const _Bool Is64 = CPUType & CPU_ARCH_ABI64;
        
        const void * const ImageFileBeginning = [[NSData dataWithContentsOfFile: ImagePath] bytes];
        if (!ImageFileBeginning) return;
        
        const void *ImageFile = ImageFileBeginning;
        if (OSReadBigInt32(&((struct fat_header*)ImageFile)->magic, 0) == FAT_MAGIC)
        {
            uint32_t Offset = 0;
            const struct fat_arch * const Arch = ImageFile + sizeof(struct fat_header);
            for (uint32_t Loop = 0, Count = OSReadBigInt32(&((struct fat_header*)ImageFile)->nfat_arch, 0); Loop < Count; Loop++)
            {
                if (OSReadBigInt32(&Arch[Loop].cputype, 0) == CPUType)
                {
                    Offset = OSReadBigInt32(&Arch[Loop].offset, 0);
                    break;
                }
            }
            
            if (Offset == 0)
            {
                NSLog(@"Could not find fat arch matching cpu type: %#x", CPUType);
                return;
            }
            
            
            ImageFile += Offset;
        }
        
        
        const size_t HeaderSize = (Is64? sizeof(struct mach_header_64) : sizeof(struct mach_header));
        const struct mach_header * const Header = ImageFile;
        
        
        if (ImageHeaderAction) ImageHeaderAction(ImageFileBeginning, ImageFile, Header);
        
        
        if ((ImageLoadCommandsAction) || (ImageDataAction))
        {
            const void * const LoadCommands = ImageFile + HeaderSize;
            
            ptrdiff_t CommandSize = 0;
            for (uint32_t Loop2 = 0; Loop2 < Header->ncmds; Loop2++)
            {
                const struct load_command * const LoadCommand = LoadCommands + CommandSize;
                
                if (ImageLoadCommandsAction) ImageLoadCommandsAction(ImageFileBeginning, ImageFile, LoadCommand);
                
                if (ImageDataAction)
                {
                    const uint32_t cmd = LoadCommand->cmd;
                    if ((cmd == LC_SEGMENT_64) || (cmd == LC_SEGMENT))
                    {
                        const void *SegmentData;
                        if (Is64)
                        {
                            const struct segment_command_64* const Segment = (struct segment_command_64*)(LoadCommands + CommandSize);
                            SegmentData = ImageFileBeginning + Segment->fileoff;
                        }
                        
                        else
                        {
                            const struct segment_command* const Segment = (struct segment_command*)(LoadCommands + CommandSize);
                            SegmentData = ImageFileBeginning + Segment->fileoff;
                        }
                        
                        ImageDataAction(ImageFileBeginning, ImageFile, SegmentData);
                    }
                }
                
                CommandSize += LoadCommand->cmdsize;
            }
        }
    }
}

_Bool FFImageInFileContainsSymbol(NSString *ImagePath, cpu_type_t CPUType, NSString *Symbol, uint8_t *Type, uint8_t *SectionIndex, int16_t *Description, mach_vm_address_t *Value)
{
    __block _Bool Found = NO;
    const char *String = [Symbol UTF8String];
    FFImageInFile(ImagePath, CPUType, NULL, (FFIMAGE_FILE_ACTION)^(const void *file, const void *image, const struct symtab_command *data){
        if (data->cmd == LC_SYMTAB)
        {
            const struct nlist_64 *SymbolTable = image + data->symoff;
            const char *StringTable = image + data->stroff;
            const uint32_t StringTableSize = data->strsize;
            
            for (uint32_t Loop = 0; Loop < data->nsyms; Loop++)
            {
                uint32_t StringIndex = SymbolTable[Loop].n_un.n_strx;
                if ((StringIndex != 0) && (StringIndex < StringTableSize))
                {
                    if (!strcmp(String, StringTable + StringIndex))
                    {
                        if (Type) *Type = SymbolTable[Loop].n_type;
                        if (SectionIndex) *SectionIndex = SymbolTable[Loop].n_sect;
                        if (Description) *Description = SymbolTable[Loop].n_desc;
                        if (Value) *Value = SymbolTable[Loop].n_value;
                        Found = YES;
                        return;
                    }
                }
            }
        }
    }, NULL);
    
    return Found;
}