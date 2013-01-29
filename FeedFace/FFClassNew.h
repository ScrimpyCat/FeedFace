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

#import <FeedFace/FFClass.h>
#import <FeedFace/ObjcNewRuntime.h>
#import <FeedFace/FFInterfaceObject.h>

@interface FFClassNew : FFClass

@property (nonatomic, copy) FFClassNew *isa;
@property (nonatomic, copy) FFClassNew *superclass;
@property (nonatomic, copy) FFCache *cache;
@property (nonatomic, copy) NSArray *vtable;
@property (nonatomic) mach_vm_address_t data_NEVER_USE;
@property (nonatomic) mach_vm_address_t rw;

/*
 The following flags correspond to the RO and RW flags. While they are settable, they simply modify the subsequent flag (directly in memory), they do not
 go and change anything else to make sure that it actually behaves correctly with that set flag, nor does it set call one of the expected functions to set those flags (as they may need to set/handle other things).
 
 In short, it's best to avoid unless you know what you're doing/expecting.
 */
//ro, rw flags
@property (nonatomic) _Bool isMetaClass; //RO_META
@property (nonatomic) _Bool isRootClass; //RO_ROOT
@property (nonatomic) _Bool hasCxxStructors; //RO_HAS_CXX_STRUCTORS | RW_HAS_CXX_STRUCTORS
@property (nonatomic) _Bool isHidden; //RO_HIDDEN
@property (nonatomic) _Bool isExceptionClass; //RO_EXCEPTION
@property (nonatomic) _Bool usesAutomaticRetainRelease; //RO_IS_ARR
@property (nonatomic) _Bool isBundleClass; //RO_FROM_BUNDLE
@property (nonatomic) _Bool isFutureClass; //RO_FUTURE | RW_FUTURE
@property (nonatomic) _Bool isRealized; //RO_REALIZED | RW_REALIZED
@property (nonatomic) _Bool isInitialized; //RW_INITIALIZED
@property (nonatomic) _Bool isInitializing; //RW_INITIALIZING
@property (nonatomic) _Bool hasCopiedRO; //RW_COPIED_RO
@property (nonatomic) _Bool isConstructing; //RW_CONSTRUCTING
@property (nonatomic) _Bool isConstructed; //RW_CONSTRUCTED
@property (nonatomic) _Bool shouldFinalizeOnMainThread; //RW_FINALIZE_ON_MAIN_THREAD
@property (nonatomic) _Bool isLoaded; //RW_LOADED
@property (nonatomic) _Bool hasSpecializedVtable; //RW_SPECIALIZED_VTABLE
@property (nonatomic) _Bool instancesHaveAssociatedObjects; //RW_INSTANCES_HAVE_ASSOCIATED_OBJECTS
@property (nonatomic) _Bool instancesHaveSpecificLayout; //RW_HAS_INSTANCE_SPECIFIC_LAYOUT
@property (nonatomic) _Bool methodListIsArray; //RW_METHOD_ARRAY
@property (nonatomic) _Bool hasCustomRR; //RW_HAS_CUSTOM_RR (retain/release/autorelease/retainCount)
@property (nonatomic) _Bool hasCustomAWZ; //RW_HAS_CUSTOM_AWZ (allocWithZone:)
@property (nonatomic) uint32_t roFlags;
@property (nonatomic) uint32_t rwFlags; 


//rw
@property (nonatomic) uint32_t version;
@property (nonatomic) mach_vm_address_t ro;
@property (nonatomic, copy) NSArray *methods; //array of FFMethod
@property (nonatomic, copy) NSArray *properties; //array of FFProperty
@property (nonatomic, copy) NSArray *protocols; //array of FFProtocol
@property (nonatomic, copy) FFClassNew *firstSubclass;
@property (nonatomic, copy) FFClassNew *nextSiblingClass;


//ro
@property (nonatomic) uint32_t instanceStart;
@property (nonatomic) uint32_t instanceSize;
@property (nonatomic) uint32_t reserved; //on 32 bit just return 0, in earlier runtime versions the reserved wasn't limited to __LP64__; could be an issue, may have to add runtime version detection later
@property (nonatomic, copy) NSArray *ivarLayout; //array of NSNumbers
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSArray *baseMethods; //array of FFMethod
@property (nonatomic, copy) NSArray *baseProtocols; //array of FFProtocol
@property (nonatomic, copy) NSArray *ivars; //array of FFIvar
@property (nonatomic, copy) NSArray *weakIvarLayout; //array of NSNumbers
@property (nonatomic, copy) NSArray *baseProperties; //array of FFProperty

@end
