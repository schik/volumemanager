/* VolumeManagerProtocols.h
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

#ifndef VOLUMEMANAGERPROTOCOLS_H
#define VOLUMEMANAGERPROTOCOLS_H

#include <Foundation/Foundation.h>

enum VolumeChangeEvents {
    VME_VOLUME_MOUNTED = 1 << 0,
    VME_VOLUME_UNMOUNTED = 1 << 1,
    VME_VOLUME_ATTACHED = 1 << 2,
    VME_VOLUME_REMOVED = 1 << 3,
    VME_CDA_INSERTED = 1 << 4,
    VME_FIRST_EVENT = VME_VOLUME_MOUNTED,
    VME_LAST_EVENT = VME_CDA_INSERTED,
    VME_ALL_EVENTS = 0xffffffff
};

enum VolumeChangeCommands {
    VMC_VOLUME_NOOP = 0,
    VMC_VOLUME_MOUNT = 1,
    VMC_VOLUME_UNMOUNT = 2,
    VMC_VOLUME_EJECT = 3,
    VMC_VOLUME_PLAY = 4,
    VMC_FIRST_COMMAND = VMC_VOLUME_NOOP,
    VMC_LAST_COMMAND = VMC_VOLUME_PLAY
};

/**
 * Implement this protocol to be notified by the volume manager if
 * a volume changes, e.g. if it is added or removed or if any
 * of its properties changes.
 */
@protocol VolumeManagerClientProtocol

- (oneway void) volumeDidChange: (NSData *)volumeChangeInfo;

@end

/**
 * The server protocol implemented by the volume manager. Clients
 * can register themselves via this interface.
 */
@protocol VolumeManagerServerProtocol

- (oneway void) registerClient: (id <VolumeManagerClientProtocol>)client;
- (oneway void) unregisterClient: (id <VolumeManagerClientProtocol>)client;

- (oneway void) client: (id <VolumeManagerClientProtocol>)client
    addWatcherForEvent: (unsigned int)event;

- (oneway void) client: (id <VolumeManagerClientProtocol>)client
   addWatcherForEvents: (unsigned int)events;

- (oneway void)  client: (id <VolumeManagerClientProtocol>)client
  removeWatcherForEvent: (unsigned int)event;

- (oneway void) client: (id <VolumeManagerClientProtocol>)client
        executeCommand: (unsigned int)command
              withData: (NSData *)data;

- (NSData *) getMountedVolumes;

@end

#endif
