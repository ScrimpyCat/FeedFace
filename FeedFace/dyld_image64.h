/*
 *  Original Code: http://opensource.apple.com/source/dyld/dyld-210.2.3/include/mach-o/dyld_images.h
 *  Modified by Stefan Johnson on 13/12/12.
 *  Modification notes:
 *  - Removed all code except for the dyld_all_image_infos, dyld_image_info structures.
 *  - Modified structures so they would represent those in a 64 bit process.
 *  - Renamed strctures to coincide with those changes.
 */

#include <stdint.h>

/*
 * Copyright (c) 2006-2010 Apple Inc. All rights reserved.
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


#include <stdbool.h>


struct dyld_image_info64 {
	uint64_t /*const struct mach_header* */ imageLoadAddress;	/* base address image is mapped into */
	uint64_t /*const char* */ imageFilePath;		/* path dyld used to load the image */
	uint64_t /*uintptr_t */ imageFileModDate;	/* time_t of image file */
    /* if stat().st_mtime of imageFilePath does not match imageFileModDate, */
    /* then file has been modified since dyld loaded it */
};

struct dyld_all_image_infos64 {
	uint32_t version;		/* 1 in Mac OS X 10.4 and 10.5 */
	uint32_t infoArrayCount;
	uint64_t /*const struct dyld_image_info* */ infoArray;
	uint64_t /*dyld_image_notifier */ notification;		
	bool processDetachedFromSharedRegion;
	/* the following fields are only in version 2 (Mac OS X 10.6, iPhoneOS 2.0) and later */
	bool libSystemInitialized;
	uint64_t /*const struct mach_header* */ dyldImageLoadAddress;
	/* the following field is only in version 3 (Mac OS X 10.6, iPhoneOS 3.0) and later */
	uint64_t /*void* */ jitInfo;
	/* the following fields are only in version 5 (Mac OS X 10.6, iPhoneOS 3.0) and later */
	uint64_t /*const char* */ dyldVersion;
	uint64_t /*const char* */ errorMessage;
	uint64_t /*uintptr_t */ terminationFlags;
	/* the following field is only in version 6 (Mac OS X 10.6, iPhoneOS 3.1) and later */
	uint64_t /*void* */ coreSymbolicationShmPage;
	/* the following field is only in version 7 (Mac OS X 10.6, iPhoneOS 3.1) and later */
	uint64_t /*uintptr_t */ systemOrderFlag;
	/* the following field is only in version 8 (Mac OS X 10.7, iPhoneOS 3.1) and later */
	uint64_t /*uintptr_t */ uuidArrayCount;
	uint64_t /*const struct dyld_uuid_info* */ uuidArray;		/* only images not in dyld shared cache */
	/* the following field is only in version 9 (Mac OS X 10.7, iOS 4.0) and later */
	uint64_t /*struct dyld_all_image_infos* */ dyldAllImageInfosAddress;
	/* the following field is only in version 10 (Mac OS X 10.7, iOS 4.2) and later */
	uint64_t /*uintptr_t */ initialImageCount;
	/* the following field is only in version 11 (Mac OS X 10.7, iOS 4.2) and later */
	uint64_t /*uintptr_t */ errorKind;
	uint64_t /*const char* */ errorClientOfDylibPath;
	uint64_t /*const char* */ errorTargetDylibPath;
	uint64_t /*const char* */ errorSymbol;
	/* the following field is only in version 12 (Mac OS X 10.7, iOS 4.3) and later */
	uint64_t /*uintptr_t */ sharedCacheSlide;
};
