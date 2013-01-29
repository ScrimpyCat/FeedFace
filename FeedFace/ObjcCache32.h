/*
 *  Original Code: http://www.opensource.apple.com/source/objc4/objc4-532/runtime/objc-cache.mm
 *  Modified by Stefan Johnson on 7/1/13.
 *  Modification notes:
 *  - Removed all code except for the objc_cache structure.
 *  - Modified objc_cache so it represents one in a 32 bit process.
 *  - Renamed objc_cache to reflect the changes.
 */

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

struct objc_cache32 {
    uint32_t /*uintptr_t */ mask;            /* total = mask + 1 */
    uint32_t /*uintptr_t */ occupied;        
    uint32_t /*cache_entry * */buckets/*[1]*/;
};
