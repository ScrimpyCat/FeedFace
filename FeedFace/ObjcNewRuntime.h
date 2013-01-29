/*
 *  Original Code: http://www.opensource.apple.com/source/objc4/objc4-532/runtime/objc-runtime-new.h
 *  Modified by Stefan Johnson on 16/12/12.
 *  Modification notes:
 *  - Removed all code except for the RW and RO flags, and any structures that can be applied for both 32 bit and 64 bit processes.
 *  - The method_list_t structure has been modified to remove the "first" member.
 */


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


// We cannot store flags in the low bits of the 'data' field until we work with
// the 'leaks' team to not think that objc is leaking memory. See radar 8955342
// for more info.
#define CLASS_FAST_FLAGS_VIA_RW_DATA 0


// Values for class_ro_t->flags
// These are emitted by the compiler and are part of the ABI. 
// class is a metaclass
#define RO_META               (1<<0)
// class is a root class
#define RO_ROOT               (1<<1)
// class has .cxx_construct/destruct implementations
#define RO_HAS_CXX_STRUCTORS  (1<<2)
// class has +load implementation
// #define RO_HAS_LOAD_METHOD    (1<<3)
// class has visibility=hidden set
#define RO_HIDDEN             (1<<4)
// class has attribute(objc_exception): OBJC_EHTYPE_$_ThisClass is non-weak
#define RO_EXCEPTION          (1<<5)
// this bit is available for reassignment
// #define RO_REUSE_ME           (1<<6) 
// class compiled with -fobjc-arc (automatic retain/release)
#define RO_IS_ARR             (1<<7)

// class is in an unloadable bundle - must never be set by compiler
#define RO_FROM_BUNDLE        (1<<29)
// class is unrealized future class - must never be set by compiler
#define RO_FUTURE             (1<<30)
// class is realized - must never be set by compiler
#define RO_REALIZED           (1<<31)

// Values for class_rw_t->flags
// These are not emitted by the compiler and are never used in class_ro_t. 
// Their presence should be considered in future ABI versions.
// class_t->data is class_rw_t, not class_ro_t
#define RW_REALIZED           (1<<31)
// class is unresolved future class
#define RW_FUTURE             (1<<30)
// class is initialized
#define RW_INITIALIZED        (1<<29)
// class is initializing
#define RW_INITIALIZING       (1<<28)
// class_rw_t->ro is heap copy of class_ro_t
#define RW_COPIED_RO          (1<<27)
// class allocated but not yet registered
#define RW_CONSTRUCTING       (1<<26)
// class allocated and registered
#define RW_CONSTRUCTED        (1<<25)
// GC:  class has unsafe finalize method
#define RW_FINALIZE_ON_MAIN_THREAD (1<<24)
// class +load has been called
#define RW_LOADED             (1<<23)
// class does not share super's vtable
#define RW_SPECIALIZED_VTABLE (1<<22)
// class instances may have associative references
#define RW_INSTANCES_HAVE_ASSOCIATED_OBJECTS (1<<21)
// class or superclass has .cxx_construct/destruct implementations
#define RW_HAS_CXX_STRUCTORS  (1<<20)
// class has instance-specific GC layout
#define RW_HAS_INSTANCE_SPECIFIC_LAYOUT (1 << 19)
// class's method list is an array of method lists
#define RW_METHOD_ARRAY       (1<<18)

#if !CLASS_FAST_FLAGS_VIA_RW_DATA
// class or superclass has custom retain/release/autorelease/retainCount
#   define RW_HAS_CUSTOM_RR      (1<<17)
// class or superclass has custom allocWithZone: implementation
#   define RW_HAS_CUSTOM_AWZ     (1<<16)
#endif


typedef struct method_list_t {
    uint32_t entsize_NEVER_USE;  // high bits used for fixup markers
    uint32_t count;
    //method_t first;
} method_list_t;

typedef struct property_list_t {
    uint32_t entsize;
    uint32_t count;
    //property_t first;
} property_list_t;

typedef struct ivar_list_t {
    uint32_t entsize;
    uint32_t count;
    //ivar_t first;
} ivar_list_t;

typedef struct protocol_list_t {
    // count is 64-bit by accident. 
    uint64_t /*uintptr_t */ count;
    //uint64_t /*protocol_ref_t */ list/*[0]*/; // variable-size
} protocol_list_t;
