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

#import "FFInterfaceObject.h"
#import "FFProcess.h"
#import "FFMemory.h"

@interface FFInterfaceObject ()

@property (readwrite, assign) FFProcess *process;
@property (readwrite) mach_vm_address_t address;

@end

@implementation FFInterfaceObject
@synthesize process, address;

-(id) initWithAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    if ((self = [super init]))
    {
        self.address = addr;
        self.process = proc;
    }
    
    return self;
}

-(_Bool) canReference: (FFInterfaceObject*)interface
{
    return [self.process isEqual: interface.process];
}

-(id) copyToAddress: (mach_vm_address_t)addr
{
    return [self copyToAddress: addr InProcess: self.process];
}

-(id) copyInProcess: (FFProcess*)proc
{
    return [self copyToAddress: [FFMemory allocateInProcess: proc WithSize: [self dataSize]].address InProcess: proc];
}

-(id) copyToAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    NSData *Data = [self.process dataAtAddress: self.address OfSize: [self dataSize]];
    [proc write: Data ToAddress: addr];
    return [[[[self class] alloc] initWithAddress: addr InProcess: proc] autorelease];
}

-(NSUInteger) dataSize
{
    NSLog(@"Must override in subclass!");
    return 0;
}

-(BOOL) isEqual: (id)object
{
    return ([self isKindOfClass: [object class]]) && (self.address == ((FFInterfaceObject*)object).address) && ([self.process isEqual: ((FFInterfaceObject*)object).process]);
}

-(NSUInteger) hash
{
    return self.address;
}

-(id) injectTo: (FFProcess*)target
{
    return [self.process isEqual: target]? self : [self copyInProcess: target];
}

-(void) dealloc
{
    self.process = nil;
    
    [super dealloc];
}

@end
