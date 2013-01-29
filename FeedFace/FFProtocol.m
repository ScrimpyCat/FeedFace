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

#import "FFProtocol.h"
#import "FFProcess.h"
#import "FFProtocolNew.h"
#import "FFProtocolOld.h"

@implementation FFProtocol
@dynamic isa, name, protocols, instanceMethods, classMethods;

+(FFProtocol*) protocolAtAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    return [[[FFProtocol alloc] initWithProtocolAtAddress: addr InProcess: proc] autorelease];
}

-(id) initWithProtocolAtAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    if (!addr)
    {
        [self release];
        return nil;
    }
    
    if ([self isMemberOfClass: [FFProtocol class]])
    {
        [self release];
        
        return [(proc.usesNewRuntime? [FFProtocolNew alloc] : [FFProtocolOld alloc]) initWithProtocolAtAddress: addr InProcess: proc];
    }
    
    if ((self = [super initWithAddress: addr InProcess: proc]))
    {
        
    }
    
    return self;
}

-(id) initWithAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    return [self initWithProtocolAtAddress: addr InProcess: proc];
}

@end
