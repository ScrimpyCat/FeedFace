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


#import "FFClass.h"
#import "FFProcess.h"
#import "NSValue+MachVMAddress.h"
#import <objc/runtime.h>

#import "FFClassOld.h"
#import "FFClassNew.h"


@interface FFClass ()

-(void) expose;

@end

static char ClassListID;

@implementation FFClass
@dynamic isa, superclass, name, version, instanceSize, cache, ivars, methods, properties, protocols, ivarLayout, weakIvarLayout, isMetaClass, isRootClass, hasCxxStructors, isHidden, isBundleClass, isInitialized, isInitializing, isConstructed, isConstructing, shouldFinalizeOnMainThread, isLoaded, instancesHaveAssociatedObjects, instancesHaveSpecificLayout;

+(id) classAtAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    return [[[FFClass alloc] initWithClassAtAddress: addr InProcess: proc] autorelease];
}

+(NSArray*) classesExposedForProcess: (FFProcess*)proc
{
    NSMutableDictionary *ClassList = objc_getAssociatedObject(proc, &ClassListID);
    return [ClassList allValues];
}

-(id) initWithClassAtAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    /*
     Check if there's already a class created for this address in the process. if it is retain and return
     So can safely expose all linked classes.
     */
    if (addr == 0)
    {
        [self release];
        return nil;
    }
    NSMutableDictionary *ClassList = objc_getAssociatedObject(proc, &ClassListID);
    if (!ClassList)
    {
        ClassList = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(proc, &ClassListID, ClassList, OBJC_ASSOCIATION_RETAIN);
        //if multiple threads make it in here, could cause problems but nothing drastic (worst case is the initial class won't be added to the correct list)
    }
    
    id Cls;
    if ((Cls = [ClassList objectForKey: [NSValue valueWithAddress: addr]]))
    {
        [self release];
        return [Cls retain];
    }
    
    
    if ([self isMemberOfClass: [FFClass class]])
    {
        [self release];
        
        return [(proc.usesNewRuntime? [FFClassNew alloc] : [FFClassOld alloc]) initWithClassAtAddress: addr InProcess: proc];
    }
    
    [ClassList setObject: self forKey: [NSValue valueWithAddress: addr]];
    
    
    if ((self = [super initWithAddress: addr InProcess: proc]))
    {
        [self expose];
    }
    
    return self;
}

-(id) initWithAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc
{
    return [self initWithClassAtAddress: addr InProcess: proc];
}

-(void) expose
{
    [self isa];
    [self superclass];
}

@end
