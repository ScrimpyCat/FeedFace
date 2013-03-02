/*
 *  Original Code: http://www.opensource.apple.com/source/objc4/objc4-532/runtime/objc-runtime-old.h
 *  Modified by Stefan Johnson on 29/1/13.
 *  Modification notes:
 *  - Removed all code except for necessary structures.
 *  - Modified structures so they represent those in a 32 bit process.
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
typedef struct old_class32 {
    uint32_t /*struct old_class * */ isa;
    uint32_t /*struct old_class * */ super_class;
    uint32_t /*const char * */ name;
    uint32_t /*long */ version;
    uint32_t /*long */ info;
    uint32_t /*long */ instance_size;
    uint32_t /*struct old_ivar_list * */ ivars;
    uint32_t /*struct old_method_list ** */ methodLists;
    uint32_t /*Cache */ cache;
    uint32_t /*struct old_protocol_list * */ protocols;
    // CLS_EXT only
    uint32_t /*const uint8_t * */ ivar_layout;
    uint32_t /*struct old_class_ext * */ ext;
} old_class32;

typedef struct old_class_ext32 {
    uint32_t size;
    uint32_t /*const uint8_t * */ weak_ivar_layout;
    uint32_t /*struct old_property_list ** */ propertyLists;
} old_class_ext32;

//Ivar
typedef struct old_ivar32 {
    uint32_t /*char * */ ivar_name;
    uint32_t /*char * */ ivar_type;
    uint32_t /*int */ ivar_offset;
} old_ivar32;

typedef struct old_ivar_list32 {
    uint32_t /*int */ ivar_count;
    
    /* variable length structure */
    uint32_t /*struct old_ivar */ ivar_list[1];
} old_ivar_list32;

//Protocol
typedef struct old_protocol32 {
    uint32_t /*Class */ isa;
    uint32_t /*const char * */ protocol_name;
    uint32_t /*struct old_protocol_list * */ protocol_list;
    uint32_t /*struct objc_method_description_list * */ instance_methods;
    uint32_t /*struct objc_method_description_list * */ class_methods;
} old_protocol32;
