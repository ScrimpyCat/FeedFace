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

#import <Foundation/Foundation.h>
#import <FeedFace/ObjcNewRuntime.h>
#import <FeedFace/FFInterfaceObject.h>


@class FFCache;
@interface FFClass : FFInterfaceObject

@property (nonatomic, copy) FFClass *isa;
@property (nonatomic, copy) FFClass *superclass;
@property (nonatomic, copy) NSString *name;
@property (nonatomic) uint32_t version;
@property (nonatomic) uint32_t instanceSize;
@property (nonatomic, copy) FFCache *cache;
@property (nonatomic, copy) NSArray *ivars; //array of FFIvar
@property (nonatomic, copy) NSArray *methods; //array of FFMethod
@property (nonatomic, copy) NSArray *properties; //array of FFProperty
@property (nonatomic, copy) NSArray *protocols; //array of FFProtocol
@property (nonatomic, copy) NSArray *ivarLayout; //array of NSNumbers
@property (nonatomic, copy) NSArray *weakIvarLayout; //array of NSNumbers
@property (nonatomic) _Bool isMetaClass;
@property (nonatomic) _Bool isRootClass;
@property (nonatomic) _Bool hasCxxStructors;
@property (nonatomic) _Bool isHidden;
@property (nonatomic) _Bool isBundleClass;
@property (nonatomic) _Bool isInitialized;
@property (nonatomic) _Bool isInitializing;
@property (nonatomic) _Bool isConstructed;
@property (nonatomic) _Bool isConstructing;
@property (nonatomic) _Bool shouldFinalizeOnMainThread;
@property (nonatomic) _Bool isLoaded;
@property (nonatomic) _Bool instancesHaveAssociatedObjects;
@property (nonatomic) _Bool instancesHaveSpecificLayout;


+(id) classAtAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc;
+(NSArray*) classesExposedForProcess: (FFProcess*)proc; //those which are currently exposed/have an FFClass representation of

-(id) initWithClassAtAddress: (mach_vm_address_t)addr InProcess: (FFProcess*)proc;

@end
