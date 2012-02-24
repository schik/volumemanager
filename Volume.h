/* Volume.h
 *  
 * Copyright (C) 2007, 2011 Andreas Schik
 *
 * Author: Andreas Schik <andreas@schik.de>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef VOLUME_H
#define VOLUME_H

#include <Foundation/Foundation.h>
#include "HalHandler.h"

@interface Volume: NSObject
{
	NSString *udi;
	HalHandler *halHandler;

	NSString *label;
	NSString *mountPoint;
	NSString *device;
	BOOL shouldUnmount;
}

- (id) initWithUdi: (NSString *)anUdi andHalHandler: (HalHandler *)handler;

- (BOOL) shouldUnmount;
- (void) setShouldUnmount: (BOOL)unmount;

- (NSString *)label;
- (NSString *)mountPoint;
- (NSString *)device;

@end


@interface Volume (Mount)

- (BOOL) mount;
- (BOOL) unmount;
- (BOOL) eject;

@end

#endif // VOLUME_H
