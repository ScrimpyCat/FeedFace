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

#import "FFInjector.h"
#import "FFProcess.h"
#import "NSValue+MachVMAddress.h"
#import "FFMemory.h"


@interface FFInjector ()

@property (readwrite, assign) FFProcess *process;
@property (readwrite) _Bool enabled;

@end

@implementation FFInjector
@synthesize process, data, additionalInfo, enabler, disabler, disableOnEnablerSet, disableOnDisablerSet, disableOnRelease, enabled;

+(id) inject: (id<NSCopying>)data InProcess: (FFProcess*)process
{
    return [[self class] inject: data AdditionalInfo: nil InProcess: process];
}

+(id) inject: (id<NSCopying>)data AdditionalInfo: (NSDictionary*)info InProcess: (FFProcess*)process
{
    return [[[[self class] alloc] initWithInjectionData: data AdditionalInfo: info InProcess: process] autorelease];
}

-(id) initWithInjectionData: (id<NSCopying>)theData AdditionalInfo: (NSDictionary*)info InProcess: (FFProcess*)proc
{
    if ((self = [super init]))
    {
        self.process = proc;
        self.data = theData;
        self.additionalInfo = info;
    }
    
    return self;
}

//potentially slow, but whatever :) add some more locks if it's an issue
static OSSpinLock EnablerLock = OS_SPINLOCK_INIT;
-(FFINJECTION) enabler
{
    FFINJECTION Enabler = NULL;
    OSSpinLockLock(&EnablerLock);
    Enabler = [enabler retain];
    OSSpinLockUnlock(&EnablerLock);
    
    return [Enabler autorelease];
}

-(void) setEnabler: (FFINJECTION)newEnabler
{
    OSSpinLockLock(&EnablerLock);
    [enabler release];
    enabler = [newEnabler copy];
    OSSpinLockUnlock(&EnablerLock);
    
    if (self.disableOnEnablerSet) [self disable];
}

static OSSpinLock DisablerLock = OS_SPINLOCK_INIT;
-(FFINJECTION) disabler
{
    FFINJECTION Disabler = NULL;
    OSSpinLockLock(&DisablerLock);
    Disabler = [disabler retain];
    OSSpinLockUnlock(&DisablerLock);
    
    return [Disabler autorelease];
}

-(void) setDisabler: (FFINJECTION)newDisabler
{
    OSSpinLockLock(&DisablerLock);
    [disabler release];
    disabler = [newDisabler copy];
    OSSpinLockUnlock(&DisablerLock);
    
    if (self.disableOnDisablerSet) [self disable];
}

-(void) enable
{
    if (!self.enabled)
    {
        FFINJECTION Enabler = self.enabler;
        if (Enabler)
        {
            Enabler(self);
            self.enabled = YES;
        }
    }
}

-(void) disable
{
    if (self.enabled)
    {
        FFINJECTION Disabler = self.disabler;
        if (Disabler)
        {
            Disabler(self);
            self.enabled = NO;
        }
    }
}

-(void) dealloc
{
    if (self.disableOnRelease) [self disable];
    
    self.process = nil;
    self.data = nil;
    self.additionalInfo = nil;
    self.enabler = NULL;
    self.disabler = NULL;
    
    [super dealloc];
}

@end

@interface FFDataInjector ()

@property (readwrite) mach_vm_address_t address;
@property (readwrite, retain) NSData *originalData;

@end

@implementation FFDataInjector
@synthesize address, originalData;

+(FFDataInjector*) inject: (NSData*)data ToAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process
{
    return [FFDataInjector inject: data AdditionalInfo: nil ToAddress: address InProcess: process];
}

+(FFDataInjector*) inject: (NSData*)data AdditionalInfo: (NSDictionary*)info ToAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process
{
    return [FFDataInjector inject: data AdditionalInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSValue valueWithAddress: address], @"address",
                                                         info? info : [NSNull null], @"info",
                                                         nil] InProcess: process];
}

static FFINJECTION DataInjectionEnabler = (FFINJECTION)^(FFDataInjector *Injector){
    [Injector.process write: Injector.data ToAddress: Injector.address];
};

static FFINJECTION DataInjectionDisabler = (FFINJECTION)^(FFDataInjector *Injector){
    [Injector.process write: Injector.originalData ToAddress: Injector.address];
};

-(id) initWithInjectionData: (NSData*)theData AdditionalInfo: (NSDictionary*)info InProcess: (FFProcess*)proc
{
    NSValue *Addr = nil;
    if ((!(Addr = [info objectForKey: @"address"])) || (![theData isKindOfClass: [NSData class]]))
    {
        [self release];
        return nil;
    }
    
    NSDictionary *Info = nil;
    if ([info count] > 1)
    {
        if ((Info = [info objectForKey: @"info"]))
        {
            if ((id)Info == [NSNull null]) Info = nil; 
        }
        
        else Info = info;
    }
    
    self.address = [Addr addressValue];
    self.originalData = [NSData data];
    
    if ((self = [super initWithInjectionData: theData AdditionalInfo: Info InProcess: proc]))
    {
        self.enabler = DataInjectionEnabler;
        self.disabler = DataInjectionDisabler;
    }
    
    return self;
}

-(void) setData: (NSData*)data
{
    NSMutableData *OriginalData = [[self.originalData mutableCopy] autorelease];
    const NSUInteger NewLength = [data length], OldLength = [OriginalData length];
    
    if (OldLength < NewLength)
    {
        [OriginalData appendData: [self.process dataAtAddress: self.address + OldLength OfSize: NewLength - OldLength]];
        self.originalData = OriginalData;
    }
    
    [super setData: data];
}

-(void) dealloc
{
    self.originalData = nil;
    
    [super dealloc];
}

@end


@interface FFCodeInjector ()

@property (readwrite) mach_vm_address_t address;
@property (readwrite, retain) NSData *originalData;
@property (readwrite) mach_vm_address_t dlsymPtr;
@property (readwrite, copy) NSData *jumpCode;

@end

@implementation FFCodeInjector
{
    FFMemory *code;
    NSData *jump, *retJump;
    FFCODEINJECTOR_JUMPCODE createJumpCode;
    enum {
        CODE_PLACEMENT_C,  //code
        CODE_PLACEMENT_OC, //original code, code
        CODE_PLACEMENT_CO //code, original code
    } placement;
    _Bool isCodecave;
}

@synthesize address, originalData, jumpCode, dlsymPtr;

+(FFCodeInjector*) injectCode: (NSData*)code ToAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process
{
    return [FFCodeInjector injectCode: code AdditionalInfo: nil ToAddress: address InProcess: process];
}

+(FFCodeInjector*) injectCode: (NSData*)code AdditionalInfo: (NSDictionary*)info ToAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process
{
    return [FFCodeInjector inject: code AdditionalInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSValue valueWithAddress: address], @"address",
                                                         [NSNumber numberWithBool: NO], @"isCodecave",
                                                         info? info : [NSNull null], @"info",
                                                         nil] InProcess: process];
}

+(FFCodeInjector*) injectCodecaveToCode: (NSData*)code FromAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process
{
    return [FFCodeInjector injectCodecaveToCode: code AdditionalInfo: nil FromAddress: address InProcess: process];
}

+(FFCodeInjector*)injectCodecaveToCode:(NSData *)code AdditionalInfo:(NSDictionary *)info FromAddress:(mach_vm_address_t)address InProcess:(FFProcess *)process
{
    return [FFCodeInjector inject: code AdditionalInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSValue valueWithAddress: address], @"address",
                                                         [NSNumber numberWithBool: YES], @"isCodecave",
                                                         [NSNumber numberWithInt: CODE_PLACEMENT_C], @"placement",
                                                         info? info : [NSNull null], @"info",
                                                         nil] InProcess: process];
}

+(FFCodeInjector*) injectCodecaveToOriginalCodeFollowedByCode: (NSData*)code FromAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process
{
    return [FFCodeInjector injectCodecaveToOriginalCodeFollowedByCode: code AdditionalInfo: nil FromAddress: address InProcess: process];
}

+(FFCodeInjector*) injectCodecaveToOriginalCodeFollowedByCode: (NSData*)code AdditionalInfo:(NSDictionary *)info FromAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process
{
    return [FFCodeInjector inject: code AdditionalInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSValue valueWithAddress: address], @"address",
                                                         [NSNumber numberWithBool: YES], @"isCodecave",
                                                         [NSNumber numberWithInt: CODE_PLACEMENT_OC], @"placement",
                                                         info? info : [NSNull null], @"info",
                                                         nil] InProcess: process];
}

+(FFCodeInjector*) injectCodecaveToCode: (NSData*)code FollowedByOriginalCodeFromAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process
{
    return [FFCodeInjector injectCodecaveToCode: code AdditionalInfo: nil FollowedByOriginalCodeFromAddress: address InProcess: process];
}

+(FFCodeInjector*) injectCodecaveToCode: (NSData*)code AdditionalInfo:(NSDictionary *)info FollowedByOriginalCodeFromAddress: (mach_vm_address_t)address InProcess: (FFProcess*)process
{
    return [FFCodeInjector inject: code AdditionalInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSValue valueWithAddress: address], @"address",
                                                         [NSNumber numberWithBool: YES], @"isCodecave",
                                                         [NSNumber numberWithInt: CODE_PLACEMENT_CO], @"placement",
                                                         info? info : [NSNull null], @"info",
                                                         nil] InProcess: process];
}

static FFINJECTION CodecaveInjectionEnabler = (FFINJECTION)^(FFCodeInjector *Injector){
    FFAddressRange Range = { Injector.address, Injector.address + [Injector.jumpCode length] };
    [Injector.process pauseWithNoThreadsExecutingInSet: [FFAddressSet addressSetWithAddressesInRange: Range]];
    [Injector.process write: Injector.jumpCode ToAddress: Injector.address];
    [Injector.process resume];
};

static FFINJECTION CodeInjectionDisabler = (FFINJECTION)^(FFCodeInjector *Injector){
    FFAddressRange Range = { Injector.address, Injector.address + [Injector.originalData length] };
    [Injector.process pauseWithNoThreadsExecutingInSet: [FFAddressSet addressSetWithAddressesInRange: Range]];
    [Injector.process write: Injector.originalData ToAddress: Injector.address];
    [Injector.process resume];
};

static FFINJECTION CodeInjectionEnabler = (FFINJECTION)^(FFCodeInjector *Injector){
    FFAddressRange Range = { Injector.address, Injector.address + [Injector.data length] };
    [Injector.process pauseWithNoThreadsExecutingInSet: [FFAddressSet addressSetWithAddressesInRange: Range]];
    [Injector.process write: Injector.data ToAddress: Injector.address];
    [Injector.process resume];
};

-(id) initWithInjectionData: (NSData*)theData AdditionalInfo: (NSDictionary*)info InProcess: (FFProcess*)proc
{
    NSValue *Addr = nil;
    NSNumber *CodeCave = nil;
    if ((!(Addr = [info objectForKey: @"address"])) || (!(CodeCave = [info objectForKey: @"isCodecave"])) || (![theData isKindOfClass: [NSData class]]))
    {
        [self release];
        return nil;
    }
    
    NSDictionary *Info = nil;
    if ([info count] > 1)
    {
        if ((Info = [info objectForKey: @"info"]))
        {
            if ((id)Info == [NSNull null]) Info = nil; 
        }
        
        else Info = info;
    }
    
    
    NSNumber *Placement = [info objectForKey: @"placement"];
    if (Placement) placement = [Placement intValue];
    
    
    [self customJumpCode: NULL];
    
    self.address = [Addr addressValue];
    self.originalData = [NSData data];
    isCodecave = [CodeCave boolValue];
    if (isCodecave) code = [[FFMemory allocateInProcess: self.process WithSize: 1] retain];
    
    if ((self = [super initWithInjectionData: theData AdditionalInfo: Info InProcess: proc]))
    {
        if (isCodecave) self.enabler = CodecaveInjectionEnabler;
        else self.enabler = CodeInjectionEnabler; //inject code
        
        self.disabler = CodeInjectionDisabler;
    }
    
    return self;
}

-(void) setData: (NSData*)data
{
    NSMutableData *OriginalData = [[self.originalData mutableCopy] autorelease];
    const NSUInteger NewLength = [data length], OldLength = [OriginalData length];
    
    if (isCodecave)
    {
        mach_vm_size_t MaxSizeJump;
        createJumpCode(0, 0, &MaxSizeJump);
        const mach_vm_size_t CodeSize = NewLength + MaxSizeJump;
        code.size = CodeSize;
        
        mach_vm_address_t CodeAddr = code.address;
        const mach_vm_address_t InjectionAddr = self.address;
        
        [self.process pauseWithNoThreadsExecutingInSet: [FFAddressSet addressSetWithAddressesInRange: (FFAddressRange){ CodeAddr, CodeAddr + CodeSize }]];
        
        self.jumpCode = createJumpCode(InjectionAddr, CodeAddr, &MaxSizeJump);
        
        if (placement == CODE_PLACEMENT_OC)
        {
            [self.process write: self.originalData ToAddress: CodeAddr];
            CodeAddr += [self.originalData length];
        }
        
        [self.process write: data ToAddress: CodeAddr];
        CodeAddr += NewLength;
        
        if (placement == CODE_PLACEMENT_CO)
        {
            [self.process write: self.originalData ToAddress: CodeAddr];
            CodeAddr += [self.originalData length];
        }
        
        
        retJump = [[self.process jumpCodeToAddress: InjectionAddr + [self.jumpCode length] FromAddress: CodeAddr] retain];
        [self.process write: retJump ToAddress: CodeAddr];
        
        [self.process resume];
    }
    
    else if (OldLength < NewLength)
    {
        [OriginalData appendData: [self.process dataAtAddress: self.address + OldLength OfSize: NewLength - OldLength]];
        self.originalData = OriginalData;
    }
    
    
    [super setData: data];
}

static OSSpinLock JumpCodeLock = OS_SPINLOCK_INIT;
-(NSData*) jumpCode
{
    NSData *JumpData = nil;
    OSSpinLockLock(&JumpCodeLock);
    JumpData = [jumpCode retain];
    OSSpinLockUnlock(&JumpCodeLock);
    
    return [JumpData autorelease];
}

-(void) setJumpCode: (NSData*)jumpData
{
    NSMutableData *OriginalData = [[self.originalData mutableCopy] autorelease];
    const NSUInteger NewLength = [jumpData length], OldLength = [OriginalData length];
    if (OldLength < NewLength) [OriginalData appendData: [self.process dataAtAddress: self.address + OldLength OfSize: NewLength - OldLength]];
    
    
    OSSpinLockLock(&JumpCodeLock);
    [jumpCode release];
    jumpCode = [jumpData copy];
    if (OldLength < NewLength) self.originalData = OriginalData;
    OSSpinLockUnlock(&JumpCodeLock);
}

-(void) customJumpCode: (FFCODEINJECTOR_JUMPCODE)jumpCodeCreator
{
    if (jumpCodeCreator) createJumpCode = jumpCodeCreator;
    else
    {
        FFProcess *Proc = self.process;
        createJumpCode = ^NSData *(mach_vm_address_t from, mach_vm_address_t to, mach_vm_size_t *maxSize){
            *maxSize = [[Proc jumpCodeToAddress: 0 FromAddress: 0] length]; //change to [Proc maxJumpCodeSize];
            return [Proc jumpCodeToAddress: to FromAddress: from];
        };
    }
}

-(void) dealloc
{
    self.originalData = nil;
    
    [code release]; code = nil;
    [jump release]; jump = nil;
    
    [super dealloc];
}

@end
