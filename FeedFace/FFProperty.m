/*
 *  Copyright (c) 2012,2013, Stefan Johnson                                                  
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

#import "FFProperty.h"
#import "ObjcNewRuntime32.h"
#import "ObjcNewRuntime64.h"

#import "FFProcess.h"
#import "FFMemory.h"

#import "PropertyImpMacros.h"

@implementation FFProperty
{
    FFMemory *nameData, *attributesData;
}

+(FFProperty*) propertyAtAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    return [[[FFProperty alloc] initWithPropertyAtAddress: addr InProcess: proc] autorelease];
}

-(id) initWithPropertyAtAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    if (!addr)
    {
        [self release];
        return nil;
    }
    
    if ((self = [super initWithAddress: addr InProcess: proc]))
    {
        
    }
    
    return self;
}

-(id) initWithAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    return [self initWithPropertyAtAddress: addr InProcess: proc];
}

-(id) copyToAddress: (mach_vm_address_t)address InProcess: (FFProcess *)proc
{
    FFProperty *Property = [super copyToAddress: address InProcess: proc];
    Property.name = self.name;
    Property.attributes = self.attributes;
    
    return Property;
}

-(NSUInteger) dataSize
{
    return self.process.is64? sizeof(property_t64) : sizeof(property_t32);
}

STRING_TYPE_PROPERTY(name, setName, Address = self.address + PROC_OFFSET_OF(property_t, name))
STRING_TYPE_PROPERTY(attributes, setAttributes, Address = self.address + PROC_OFFSET_OF(property_t, attributes))

-(void) dealloc
{
    [nameData release]; nameData = nil;
    [attributesData release]; attributesData = nil;
    
    
    [super dealloc];
}

@end
