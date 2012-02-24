/* ConnectionManager.h
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

#ifndef CONNECTIONMANAGER_H
#define CONNECTIONMANAGER_H

#include <Foundation/Foundation.h>

#include "VolumeManager.h"
#include "VolumeManagerProtocols.h"
#include "VmIconController.h"


@class VMClientInfo;


@interface ConnectionManager: NSObject
{
    NSConnection *conn;
    NSNotificationCenter *nc; 
    NSMutableSet *clients;

    VolumeManager *volumeManager;

    VmIconController *tiController;
}

- (id) init;

- (void) notifyClientsForEvent: (unsigned int)event withInfo: (NSDictionary *)info;
- (enum VolumeChangeCommands) requestPlayOrMountFromUser: (NSDictionary *)info;
- (VMClientInfo *) clientInfoForClient: (id)client;
- (void) connectionBecameInvalid:(NSNotification *)notification;

@end


@interface VMClientInfo: NSObject
{
    id <VolumeManagerClientProtocol> _client;
    unsigned int _events;
}

- (void) setClient: (id <VolumeManagerClientProtocol>) client;
- (id <VolumeManagerClientProtocol>) client;

- (void) setEvents: (unsigned int) events;
- (void) setEvent: (unsigned int) event;
- (void) unsetEvent: (unsigned int) event;
- (BOOL) watchesEvent: (unsigned int) event;

@end


#endif
