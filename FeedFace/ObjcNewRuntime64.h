/*
 *  Original Code: http://www.opensource.apple.com/source/objc4/objc4-532/runtime/objc-runtime-new.h
 *  Modified by Stefan Johnson on 16/12/12.
 *  Modification notes:
 *  - Removed all code except for the class_t, class_rw_t, class_ro_t structures.
 *  - Modified structures so they represent those in a 64 bit process.
 *  - Renamed structures to reflect with those changes.
 */

#import "ObjcNewRuntime.h"
#import <stdint.h>

/*
 * Copyright (c) 2005-2007 Apple Inc.  All Rights Reserved.
 * 
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

//Class
typedef struct class_ro_t64 {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
    
    uint32_t reserved;
    
    
    uint64_t /*const uint8_t * */ ivarLayout;
    
    uint64_t /*const char * */ name;
    uint64_t /*const method_list_t * */ baseMethods;
    uint64_t /*const protocol_list_t * */ baseProtocols;
    uint64_t /*const ivar_list_t * */ ivars;
    
    uint64_t /*const uint8_t * */ weakIvarLayout;
    uint64_t /*const property_list_t * */ baseProperties;
} class_ro_t64;

typedef struct class_rw_t64 {
    uint32_t flags;
    uint32_t version;
    
    uint64_t /*const class_ro_t * */ ro;
    
    union {
        uint64_t /*method_list_t ** */ method_lists;  // RW_METHOD_ARRAY == 1
        uint64_t /*method_list_t * */ method_list;    // RW_METHOD_ARRAY == 0
    };
    uint64_t /*struct chained_property_list * */ properties;
    uint64_t /*const protocol_list_t ** */ protocols;
    
    uint64_t /*struct class_t * */ firstSubclass;
    uint64_t /*struct class_t * */ nextSiblingClass;
} class_rw_t64;

typedef struct class_t64 {
    uint64_t /*struct class_t * */ isa;
    uint64_t /*struct class_t * */ superclass;
    uint64_t /*Cache */ cache;
    uint64_t /*IMP * */ vtable;
    uint64_t /*uintptr_t */ data_NEVER_USE;  // class_rw_t * plus custom rr/alloc flags (data_NEVER_USE & ~(uintptr_t)3); 
} class_t64;


//Method
typedef struct method_t64 {
    uint64_t /*SEL */ name;
    uint64_t /*const char * */ types;
    uint64_t /*IMP */ imp;
} method_t64;

//Property
typedef struct objc_property64 {
    uint64_t /*const char * */ name;
    uint64_t /*const char * */ attributes;
} property_t64;

typedef struct chained_property_list64 {
    uint64_t /*struct chained_property_list * */next;
    uint32_t count;
    uint64_t /*property_t */ list/*[0]*/;  // variable-size
} chained_property_list64;

//Ivar
typedef struct ivar_t64 {
    // *offset is 64-bit by accident even though other 
    // fields restrict total instance size to 32-bit. 
    uint64_t /*uintptr_t * */ offset;
    uint64_t /*const char * */ name;
    uint64_t /*const char * */ type;
    // alignment is sometimes -1; use ivar_alignment() instead
    uint32_t alignment;//  __attribute__((deprecated));
    uint32_t size;
} ivar_t64;

//Protocol
typedef struct protocol_t64 {
    uint64_t /*id */ isa;
    uint64_t /*const char * */ name;
    uint64_t /*struct protocol_list_t * */ protocols;
    uint64_t /*method_list_t * */ instanceMethods;
    uint64_t /*method_list_t * */ classMethods;
    uint64_t /*method_list_t * */ optionalInstanceMethods;
    uint64_t /*method_list_t * */ optionalClassMethods;
    uint64_t /*property_list_t * */ instanceProperties;
    uint32_t size;   // sizeof(protocol_t)
    uint32_t flags;
    uint64_t /*const char ** */ extendedMethodTypes;
} protocol_t64;

typedef struct protocol_list_t64 {
    // count is 64-bit by accident. 
    uint64_t /*uintptr_t */ count;
    uint64_t /*protocol_ref_t */ list/*[0]*/; // variable-size
} protocol_list_t64;
