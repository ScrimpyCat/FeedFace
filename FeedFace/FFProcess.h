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

#import <Foundation/Foundation.h>
#import <FeedFace/FFAddressSet.h>

@class FFClass;
@interface FFProcess : NSObject

@property (readonly) mach_port_name_t task;
@property (readonly) pid_t pid;
@property (readonly, retain) NSString *name;
@property (readonly, retain) NSString *path;
@property (readonly) _Bool is64;
@property (readonly) cpu_type_t cpuType;
@property (readonly) _Bool usesNewRuntime;

//add property to get current version of libobjc.A.dylib ?

+(FFProcess*) current;
+(NSString*) nameOfProcessWithIdentifier: (pid_t)pid;
+(NSString*) pathOfProcessWithIdentifier: (pid_t)pid;
+(FFProcess*) processWithIdentifier: (pid_t)pid;
+(FFProcess*) processWithName: (NSString*)name;
+(NSArray*) processesWithName: (NSString*)name;

-(id) initWithProcessIdentifier: (pid_t)thePid; //override
-(mach_vm_address_t) loadAddressForImage: (NSString*)image; //override
-(mach_vm_address_t) relocateAddress: (mach_vm_address_t)address;
-(mach_vm_address_t) relocateAddress: (mach_vm_address_t)address InImage: (NSString*)image; //override
-(mach_vm_address_t) relocateAddress: (mach_vm_address_t)address InImageAtAddress: (mach_vm_address_t)imageAddress; //suggested override
-(mach_vm_address_t) relocateAddress: (mach_vm_address_t)address InImageContainingAddress: (mach_vm_address_t)vmAddress; //suggested override
-(NSString*) filePathForImageAtAddress: (mach_vm_address_t)imageAddress; //override
-(NSString*) filePathForImageContainingAddress: (mach_vm_address_t)vmAddress; //override
-(NSArray*) regions;
-(NSArray*) images; //override
-(NSArray*) threads;
-(thread_state_flavor_t) threadStateKind;

//convenient code
-(NSData*) jumpCodeToAddress: (mach_vm_address_t)toAddr FromAddress: (mach_vm_address_t)fromAddr; //override


-(void) terminate;
-(void) pause;
-(void) pauseWithNoThreadsExecutingAtAddress: (mach_vm_address_t)address;
-(void) pauseWithNoThreadsExecutingInRange: (FFAddressRange)range;
-(void) pauseWithNoThreadsExecutingInSet: (FFAddressSet*)set;
-(void) resume;

//object inspection
-(NSString*) nameOfObject: (mach_vm_address_t)address; //override
-(id) classAtAddress: (mach_vm_address_t)address;
-(id) classOfObject: (mach_vm_address_t)address; //override

@end


@interface FFProcess (Reading)

-(NSData*) dataAtAddress: (mach_vm_address_t)address OfSize: (mach_vm_size_t)size;
-(NSArray*) dataForSegment: (NSString*)segment Section: (NSString*)section;
-(NSData*) dataForSegment: (NSString*)segment Section: (NSString*)section InImage: (NSString*)image;
-(NSString*) nullTerminatedStringAtAddress: (mach_vm_address_t)address;
-(mach_vm_address_t) addressAtAddress: (mach_vm_address_t)address;

@end


@interface FFProcess (Writing)

-(void) writeData: (const void*)data OfSize: (mach_vm_size_t)size ToAddress: (mach_vm_address_t)address;
-(void) write: (NSData*)data ToAddress: (mach_vm_address_t)address;
-(void) writeAddress: (mach_vm_address_t)addressData ToAddress: (mach_vm_address_t)address;

@end


@interface FFProcess (Injecting)

/*
 Injection conveniences
 */

@end


/*
 None of the scanning methods make any guarantees about the accuracy. While they should locate the matches, they don't guarantee on how
 well those matches fit with what you expected.
 
 Suggested usage is to perform additional tests on the returned addresses (and the data at those locations) if you're expecting them
 to represent something specific.
*/
@interface FFProcess (Scanning)

-(NSArray*) findData: (const void*)data OfSize: (NSUInteger)size;
-(NSArray*) find: (NSData*)data;
-(NSArray*) findCString: (const char*)string;
-(NSArray*) ownClasses;
-(NSArray*) referencedClasses;
-(NSArray*) classes;
-(id) classWithName: (NSString*)name WantMetaClass: (_Bool)wantMeta;
-(NSArray*) classesWithName: (NSString*)name;
-(NSArray*) findClass: (NSString*)classname;
-(NSArray*) findInstanceOfClass: (NSString*)classname;
-(NSArray*) findLoadCommandForSegment: (NSString*)segment;
-(NSArray*) findLoadCommandForSegment: (NSString*)segment Section: (NSString*)section;
-(NSArray*) findSegment: (NSString*)segment;
-(NSArray*) findSegment: (NSString*)segment Section: (NSString*)section;
-(NSArray*) findAddress: (mach_vm_address_t)address; 


-(mach_vm_address_t) findData: (const void*)data OfSize: (NSUInteger)size ClosestTo: (mach_vm_address_t)targetAddress;
-(mach_vm_address_t) findCString: (const char*)string ClosestTo: (mach_vm_address_t)targetAddress;

@end

@interface FFProcess (InfoLogging)

-(void) logOwnClasses;
-(void) logReferencedClasses;
-(void) logAllClasses;

@end
