/*
 *  Original Code: http://www.opensource.apple.com/source/objc4/objc4-532/runtime/objc-runtime-new.h
 *  Modified by Stefan Johnson on 16/12/12.
 *  Modification notes:
 *  - Removed all code except for the class_t, class_rw_t, class_ro_t structures.
 *  - Modified structures so they represent those in a 32 bit process.
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
typedef struct class_ro_t32 {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
    
    uint32_t /*const uint8_t * */ ivarLayout;
    
    uint32_t /*const char * */ name;
    uint32_t /*const method_list_t * */ baseMethods;
    uint32_t /*const protocol_list_t * */ baseProtocols;
    uint32_t /*const ivar_list_t * */ ivars;
    
    uint32_t /*const uint8_t * */ weakIvarLayout;
    uint32_t /*const property_list_t * */ baseProperties;
} class_ro_t32;

typedef struct class_rw_t32 {
    uint32_t flags;
    uint32_t version;
    
    uint32_t /*const class_ro_t * */ ro;
    
    union {
        uint32_t /*method_list_t ** */ method_lists;  // RW_METHOD_ARRAY == 1
        uint32_t /*method_list_t * */ method_list;    // RW_METHOD_ARRAY == 0
    };
    uint32_t /*struct chained_property_list * */ properties;
    uint32_t /*const protocol_list_t ** */ protocols;
    
    uint32_t /*struct class_t * */ firstSubclass;
    uint32_t /*struct class_t * */ nextSiblingClass;
} class_rw_t32;

typedef struct class_t32 {
    uint32_t /*struct class_t * */ isa;
    uint32_t /*struct class_t * */ superclass;
    uint32_t /*Cache */ cache;
    uint32_t /*IMP * */ vtable;
    uint32_t /*uintptr_t */ data_NEVER_USE;  // class_rw_t * plus custom rr/alloc flags (data_NEVER_USE & ~(uintptr_t)3); 
} class_t32;


//Method
typedef struct method_t32 {
    uint32_t /*SEL */ name;
    uint32_t /*const char * */ types;
    uint32_t /*IMP */ imp;
} method_t32;

//Property
typedef struct objc_property32 {
    uint32_t /*const char * */ name;
    uint32_t /*const char * */ attributes;
} property_t32;

typedef struct chained_property_list32 {
    uint32_t /*struct chained_property_list * */next;
    uint32_t count;
    uint32_t /*property_t */ list/*[0]*/;  // variable-size
} chained_property_list32;

//Ivar
typedef struct ivar_t32 {
    // *offset is 64-bit by accident even though other 
    // fields restrict total instance size to 32-bit. 
    uint32_t /*uintptr_t * */ offset;
    uint32_t /*const char * */ name;
    uint32_t /*const char * */ type;
    // alignment is sometimes -1; use ivar_alignment() instead
    uint32_t alignment;//  __attribute__((deprecated));
    uint32_t size;
} ivar_t32;

//Protocol
typedef struct protocol_t32 {
    uint32_t /*id */ isa;
    uint32_t /*const char * */ name;
    uint32_t /*struct protocol_list_t * */ protocols;
    uint32_t /*method_list_t * */ instanceMethods;
    uint32_t /*method_list_t * */ classMethods;
    uint32_t /*method_list_t * */ optionalInstanceMethods;
    uint32_t /*method_list_t * */ optionalClassMethods;
    uint32_t /*property_list_t * */ instanceProperties;
    uint32_t size;   // sizeof(protocol_t)
    uint32_t flags;
    uint32_t /*const char ** */ extendedMethodTypes;
} protocol_t32;

typedef struct protocol_list_t32 {
    // count is 64-bit by accident. 
    uint64_t /*uintptr_t */ count;
    uint32_t /*protocol_ref_t */ list/*[0]*/; // variable-size
} protocol_list_t32;
