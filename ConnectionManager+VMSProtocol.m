/* ConnectionManager+VMSProtocol.m
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

#include "ConnectionManager.h"
#include "Volume.h"


@implementation VMClientInfo

- (id) init
{
    self = [super init];
    if (self) {
        _client = nil;
        _events = 0;
    }
    return self;
}

- (void) dealloc
{
    RELEASE((id)_client);
    [super dealloc];
}

- (void) setClient: (id <VolumeManagerClientProtocol>) client
{
    ASSIGN(_client, (id)client);
}

- (id <VolumeManagerClientProtocol>) client
{
    return _client;
}

- (void) setEvents: (unsigned int) events
{
    _events = events;
}

- (void) setEvent: (unsigned int) event
{
    if ((event < VME_FIRST_EVENT) || (event > VME_LAST_EVENT)) {
        return;
    }
    _events |= event;
}

- (void) unsetEvent: (unsigned int) event
{
    if ((event < VME_FIRST_EVENT) || (event > VME_LAST_EVENT)) {
        return;
    }
    _events &= ~event;
}

- (BOOL) watchesEvent: (unsigned int) event
{
    if ((event < VME_FIRST_EVENT) || (event > VME_LAST_EVENT)) {
        return NO;
    }
    return _events & event;
}

@end



@implementation ConnectionManager(VMSProtocol)

- (oneway void) registerClient: (id <VolumeManagerClientProtocol>)client
{
    NSConnection *connection = [(NSDistantObject *)client connectionForProxy];
    VMClientInfo *info = [self clientInfoForClient: client];

    if (info != nil) {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Registration with registered client"];
    }

    info = [VMClientInfo new];

    [info setClient: client];
    [clients addObject: info];
    RELEASE (info);

    [(id)client setProtocolForProxy: @protocol(VolumeManagerClientProtocol)];

    [nc addObserver: self
           selector: @selector(connectionBecameInvalid:)
               name: NSConnectionDidDieNotification
             object: connection];
           
    [connection setDelegate: self];
}

- (oneway void) unregisterClient: (id <VolumeManagerClientProtocol>)client
{
    NSConnection *connection = [(NSDistantObject *)client connectionForProxy];
    VMClientInfo *info = [self clientInfoForClient: client];

    if (info == nil) {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Unregistration with unknown client"];
    }

    [nc removeObserver: self
                  name: NSConnectionDidDieNotification
                object: connection];

    [clients removeObject: info];  
}

- (oneway void) client: (id <VolumeManagerClientProtocol>)client
    addWatcherForEvent: (unsigned int)event
{
    VMClientInfo *info = [self clientInfoForClient: client];

    if (info == nil) {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Cannot add watch for unknown client"];
    }

    [info setEvent: event];
}

- (oneway void) client: (id <VolumeManagerClientProtocol>)client
   addWatcherForEvents: (unsigned int)events
{
    VMClientInfo *info = [self clientInfoForClient: client];

    if (info == nil) {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Cannot add watch for unknown client"];
    }

    [info setEvents: events];
}

- (oneway void)  client: (id <VolumeManagerClientProtocol>)client
  removeWatcherForEvent: (unsigned int)event
{
    VMClientInfo *info = [self clientInfoForClient: client];

    if (info == nil) {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Cannot remove watch for unknown client"];
    }

    [info unsetEvent: event];
}

- (oneway void) client: (id <VolumeManagerClientProtocol>)client
        executeCommand: (unsigned int)command
              withData: (NSData *)data

{
    if ((command < VMC_FIRST_COMMAND) || (command > VMC_LAST_COMMAND)) {
        return;
    }
    NSString *device = [NSUnarchiver unarchiveObjectWithData: data];
    if (command == VMC_VOLUME_EJECT) {
        [volumeManager ejectVolume: device];
    } else if (command == VMC_VOLUME_UNMOUNT) {
        [volumeManager unmountVolume: device];
    }
}

- (NSData *) getMountedVolumes
{
    CREATE_AUTORELEASE_POOL(pool);
    NSData *data = nil;
    NSMutableArray *retData = [NSMutableArray array];
    NSDictionary *volumes = [volumeManager mountedVolumes];
    NSArray *udis = [volumes allKeys];
    NSEnumerator *enumerator = [udis objectEnumerator];
    NSString *udi;

    while ((udi = [enumerator nextObject])) {
        Volume *volume = [volumes objectForKey: udi];
        // We better check now whether we really got an object.
        // It may be that the udi has already been unmounted
        // while we are creating our list.
        if (volume != nil) {
            NSMutableDictionary *info = [NSMutableDictionary dictionary];
            [info setObject: [volume device] forKey: @"device"];
            [info setObject: [volume mountPoint] forKey: @"mountPoint"];
            [info setObject: [volume label] forKey: @"label"];
            [retData addObject: info];
        }
    }

    data = [NSArchiver archivedDataWithRootObject: retData];
    RETAIN(data);
    RELEASE(pool);
    return AUTORELEASE(data);
}

@end

