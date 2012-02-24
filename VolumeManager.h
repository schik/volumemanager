/* VolumeManager.h
 *  
 * Copyright (C) 2007 Andreas Schik
 *
 * Author: Andreas Schik <andreas@schik.de>
 * Date: March 2007
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

#ifndef VOLUMEMANAGER_H
#define VOLUMEMANAGER_H

#include <Foundation/Foundation.h>
#include "HalHandler.h"

@interface VolumeManager: NSObject
{
    HalHandler *halHandler;
    id delegate;
    NSMutableDictionary *mountedVolumes;
    DKNotificationCenter *center;
}

- (id) init;

- (void) mountAll;
- (void) unmountAll;

- (void) unmountVolume: (NSString *)device;
- (void) ejectVolume: (NSString *)device;

- (void) deviceAdded: (id)data;
- (void) deviceRemoved: (id)data;
- (void) propertyModified: (id)data;

/**
 * Handle notification service's signal that an action has
 * been invoked by the user.
 */
- (void) actionInvoked: (id)data;

- (NSDictionary *)mountedVolumes;

- (void) setDelegate: (id)object;

@end

#endif // VOLUMEMANAGER_H
