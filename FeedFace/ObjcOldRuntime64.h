/*
 *  Original Code: http://www.opensource.apple.com/source/objc4/objc4-532/runtime/objc-runtime-old.h
 *  Modified by Stefan Johnson on 29/1/13.
 *  Modification notes:
 *  - Removed all code except for necessary structures.
 *  - Modified structures so they represent those in a 64 bit process.
 *  - Renamed structures to reflect with those changes.
 */

#import "ObjcNewRuntime.h"
#import <stdint.h>

/*
 * Copyright (c) 1999-2007 Apple Inc.  All Rights Reserved.
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
typedef struct old_class64 {
    uint64_t /*struct old_class * */ isa;
    uint64_t /*struct old_class * */ super_class;
    uint64_t /*const char * */ name;
    uint64_t /*long */ version;
    uint64_t /*long */ info;
    uint64_t /*long */ instance_size;
    uint64_t /*struct old_ivar_list * */ ivars;
    uint64_t /*struct old_method_list ** */ methodLists;
    uint64_t /*Cache */ cache;
    uint64_t /*struct old_protocol_list * */ protocols;
    // CLS_EXT only
    uint64_t /*const uint8_t * */ ivar_layout;
    uint64_t /*struct old_class_ext * */ ext;
} old_class64;

typedef struct old_class_ext64 {
    uint32_t size;
    uint32_t /*const uint8_t * */ weak_ivar_layout;
    uint32_t /*struct old_property_list ** */ propertyLists;
} old_class_ext64;

//Ivar
typedef struct old_ivar64 {
    uint64_t /*char * */ ivar_name;
    uint64_t /*char * */ ivar_type;
    uint32_t /*int */ ivar_offset;

    uint32_t /*int */ space;
} old_ivar64;

typedef struct old_ivar_list64 {
    uint32_t /*int */ ivar_count;
    uint32_t space;
    /* variable length structure */
    uint64_t /*struct old_ivar */ ivar_list/*[1]*/;
} old_ivar_list64;

//Protocol
typedef struct old_protocol64 {
    uint64_t /*Class */ isa;
    uint64_t /*const char * */ protocol_name;
    uint64_t /*struct old_protocol_list * */ protocol_list;
    uint64_t /*struct objc_method_description_list * */ instance_methods;
    uint64_t /*struct objc_method_description_list * */ class_methods;
} old_protocol64;

typedef struct old_protocol_list64 {
    uint64_t /*struct old_protocol_list * */ next;
    uint64_t /*long */ count;
    uint64_t /*struct old_protocol * */list/*[1]*/;
} old_protocol_list64;

typedef struct old_protocol_ext64 {
    uint32_t size;
    uint64_t /*struct objc_method_description_list * */ optional_instance_methods;
    uint64_t /*struct objc_method_description_list * */ optional_class_methods;
    uint64_t /*struct old_property_list * */ instance_properties;
    uint64_t /*const char ** */ extendedMethodTypes;
} old_protocol_ext64;

//Method
typedef struct old_method64 {
    uint64_t /*SEL */ method_name;
    uint64_t /*char * */ method_types;
    uint64_t /*IMP */ method_imp;
} old_method64;

typedef struct old_method_list64 {
    uint64_t /*struct old_method_list * */ obsolete;
    
    uint32_t /*int */ method_count;
    
    uint32_t /*int */ space;
    
    /* variable length structure */
    uint64_t /*struct old_method */ method_list/*[1]*/;
} old_method_list64;
