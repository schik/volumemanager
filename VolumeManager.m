/* VolumeManager.m
 *  
 * Copyright (C) 2007,2011 Andreas Schik
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

#include <AppKit/NSPasteboard.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSPanel.h>

#include "VolumeManager.h"
#include "Volume.h"
#include "HalHandler.h"

struct deviceHandler {
    NSString *capability;
    SEL handler;
};

static struct deviceHandler deviceHandlers[] = {
    {@"block", @selector(blockDeviceAdded:)},
    {@"camera", @selector(cameraDeviceAdded:)}
};

static NSString * const SIG_ACTIONINVOKED = @"DKSignal_org.freedesktop.Notifications_ActionInvoked";


@interface VolumeManager (Private)

- (BOOL) mountVolume: (NSString *)udi;

- (BOOL) openFilesystem: (NSString *)device;

- (BOOL) executeAutoOpenActions: (NSString *)udi
                         device: (NSString *)device
                        atPoint: (NSString *)mountPoint;

- (BOOL) udiIsSubfsMount: (NSString *)udi;

/**
 * Notify clients about a newly attached volume.
 */
- (void) volumeAttached;
/**
 * Notify clients about a removed volume.
 */
- (void) volumeRemoved;
/**
 * Notify clients about a newly mounted volume.
 */
- (void) sendVolumeMountedNotification: (NSString *)device
                               atPoint: (NSString *)mountPoint
                             withLabel: (NSString *)label;
/**
 * Notify clients about an unmounted volume.
 */
- (void) volumeUnmounted: (NSString *)label
               fromPoint: (NSString *)mountPoint;

@end


@implementation VolumeManager

- (id) init
{
    self = [super init];
  
    if (self) {
        mountedVolumes = [NSMutableDictionary new];
        halHandler = [[HalHandler alloc] init];
        [halHandler registerDeviceChangedHandler: self];
        [halHandler registerPropertyModifiedHandler: self forDevice: ALL_DEVICES];
        center = [[DKNotificationCenter sessionBusCenter] retain];
        [center addObserver: self
                   selector: @selector(actionInvoked:)
                       name: SIG_ACTIONINVOKED
                     object: nil];
    }
  
    return self;
}

- (void)dealloc
{
    [center removeObserver: self
                      name: SIG_ACTIONINVOKED
                    object: nil];
    [center release];
    [halHandler unregisterDeviceChangedHandler: self];
    [halHandler release];
    RELEASE(mountedVolumes);
    [super dealloc];
}

- (void) setDelegate: (id)object
{
    delegate = object;
}

- (NSDictionary *)mountedVolumes
{
    return mountedVolumes;
}

- (void) mountAll
{
    int mount;
    int i;

    NSArray *devices = [halHandler findDevicesByCapability: @"volume"];
    if (devices == nil) {
        NSDebugLog(@"mountAll: could not find volume devices");
        return;
    }

    for (i = 0; i < [devices count]; i++) {
        NSString *udi = [devices objectAtIndex: i];

        if ([self udiIsSubfsMount: udi]) {
            continue;
        }

        // don't attempt to mount already mounted volumes
        if ([halHandler getBooleanProperty: @"volume.is_mounted"
                                 forDevice: udi]) {
            continue;
        }

        // only mount if the block device has a sensible filesystem
        if ([halHandler propertyExists: @"volume.fsusage"
                             forDevice: udi] == NO) {
            continue;
        }

        NSString *prop = [halHandler getStringProperty: @"volume.fsusage"
                                             forDevice: udi];
        if ((prop == nil)
             || (![prop isEqualToString: @"filesystem"]
                   && ![prop isEqualToString: @"crypto"])) {
            continue;
        }

        // check our mounting policy
        NSString *drive = [halHandler getStringProperty: @"info.parent"
                                                  forDevice: udi];
        if ((drive == nil) || ([drive length] == 0)) {
            continue;
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        BOOL automountDrives = [defaults boolForKey: @"automount_drives"];

        if ([halHandler getBooleanProperty: @"storage.hotpluggable"
                                 forDevice: udi] == YES) {
            mount = automountDrives;
        } else if ([halHandler getBooleanProperty: @"storage.removable"
                                        forDevice: udi] == YES) {
            mount = automountDrives;
        } else {
            mount = [halHandler getBooleanProperty: @"volume.ignore"
                                         forDevice: udi] == NO;
        }
        
        if (!mount) {
            continue;
        }
        // mount the device
        NSString *device = [halHandler getStringProperty: @"block.device"
                                               forDevice: udi];
        if ((device != nil) && ([device length] != 0)) {
            NSDebugLog(@"mountAll: mounting %@\n", device);
            [self mountVolume: udi];
        } else {
            NSDebugLog(@"mountAll: no device for udi %@", udi);
        }
    }
}

- (void) unmountAll
{
    NSDebugLog(@"unmounting all volumes that we mounted in our lifetime");
    NSArray *keys = [mountedVolumes allKeys];
    NSEnumerator *volumes = [keys objectEnumerator];
    id key;

    while ((key = [volumes nextObject])) {
        Volume *vol = [mountedVolumes objectForKey: key];
        if ([vol shouldUnmount]) {
            [vol unmount];
        }
        [mountedVolumes removeObjectForKey: key];
    }
}

- (void) unmountVolume: (NSString *)device
{
    CREATE_AUTORELEASE_POOL(pool);
    NSArray *udis = [mountedVolumes allKeys];
    NSEnumerator *enumerator = [udis objectEnumerator];
    NSString *udi;
    while ((udi = [enumerator nextObject])) {
        Volume *volume = [mountedVolumes objectForKey: udi];
        if ([[volume device] isEqualToString: device]
                || [[volume mountPoint] isEqualToString: device]) {
            [volume unmount];
            break;
        }
    }
    RELEASE(pool);
}

- (void) ejectVolume: (NSString *)device
{
    CREATE_AUTORELEASE_POOL(pool);
    NSArray *udis = [mountedVolumes allKeys];
    NSEnumerator *enumerator = [udis objectEnumerator];
    NSString *udi;
    while ((udi = [enumerator nextObject])) {
        Volume *volume = [mountedVolumes objectForKey: udi];
        if ([[volume device] isEqualToString: device]
                || [[volume mountPoint] isEqualToString: device]) {
            [volume eject];
            break;
        }
    }
    RELEASE(pool);
}

- (void) deviceAdded: (id)data
{
    static int nHandlers = sizeof(deviceHandlers)/sizeof(struct deviceHandler);
    int i;
    NSDictionary *userInfo = [(NSNotification*)data userInfo];
    NSString *udi = [userInfo objectForKey: @"arg0"];

    NSDebugLog(@"Device added: %@", udi);

    NSArray *caps = [halHandler getStrlistProperty: @"info.capabilities"
                                         forDevice: udi];

    if (caps == nil) {
        return;
    }

    id pool = [NSAutoreleasePool new];
    for (i = 0; i < nHandlers; i++) {
        if ([caps containsObject: deviceHandlers[i].capability]) {
            NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:
                udi,
                @"udi",
                deviceHandlers[i].capability,
                @"capability",
                nil];
            if ([self performSelector: deviceHandlers[i].handler withObject: args]) {
                // Notify clients about the change
                [self volumeAttached];
            }
            break;
        }
    }
    [caps release];
    RELEASE(pool);
}

- (void) deviceRemoved: (id)data
{
    NSDictionary *userInfo = [(NSNotification*)data userInfo];
    NSString *udi = [userInfo objectForKey: @"arg0"];

    NSDebugLog(@"Device removed: %@", udi);

    id pool = [NSAutoreleasePool new];
    BOOL mounted = [halHandler getBooleanProperty: @"volume.is_mounted"
                                        forDevice: udi];
    if ((mounted == NO) && ([mountedVolumes objectForKey: udi] != nil)) {
        NSDebugLog(@"Removed: %@\n", udi);
        [mountedVolumes removeObjectForKey: udi];
        // Notify clients about the change
        [self volumeRemoved];
    }
    RELEASE(pool);
}

- (void) propertyModified: (id)data
{
    NSDictionary *userInfo = [(NSNotification*)data userInfo];

    BOOL found = NO;
    int numProps = [[userInfo objectForKey: @"arg0"] intValue];
    NSArray *props = [userInfo objectForKey: @"arg1"];
    int i;
    for (i = 0; (i < numProps) && (found == NO); i++) {
        NSArray *prop = [props objectAtIndex: i];
        NSString *propName = [prop objectAtIndex: 0];
        found = [propName isEqualToString: @"volume.is_mounted"];
    }

    // on mount key may be is_mounted and mount_point
    if (found == NO) {
        return;
    }

    CREATE_AUTORELEASE_POOL(pool);
    NSString *udi = [userInfo objectForKey: @"path"];
    BOOL mounted = [halHandler getBooleanProperty: @"volume.is_mounted"
                                        forDevice: udi];
    Volume *vol = [mountedVolumes objectForKey: udi];
    if (vol != nil) {
        RETAIN(vol);
    }
    if (mounted) {
        NSDebugLog(@"Mounted: %@\n", udi);

        // If the volume was not mounted by us (not in the dict)
        // we mark it as being unmountable.
        if (vol == nil) {
            vol = [[Volume alloc] initWithUdi: udi
                                        andHalHandler: halHandler];
            [vol setShouldUnmount: NO];
        }
        [mountedVolumes setObject: vol forKey: udi];
        [self executeAutoOpenActions: udi
                              device: [vol device]
                             atPoint: [vol mountPoint]];
        // send notification to clients
        [self sendVolumeMountedNotification: [vol device]
                                    atPoint: [vol mountPoint]
                                  withLabel: [vol label]];
    } else {
        NSDebugLog(@"Unmounted: %@\n", udi);
        
        if (vol != nil) {
            // Remove it from the list first, as clients may
            // check this list during their actions and expect it
            // to be up-to-date.
            [mountedVolumes removeObjectForKey: udi];
            [self volumeUnmounted: [vol label] fromPoint: [vol mountPoint]];
        }
    }
    if (vol != nil) {
        RELEASE(vol);
    }
    RELEASE(pool);
}

- (void) actionInvoked: (id)data
{
    NSDictionary *userInfo = [(NSNotification*)data userInfo];
    NSString *actionKey = [userInfo objectForKey: @"arg1"];

    NSDebugLog(@"action invoked, key: %@\n", actionKey);
    if ((nil != actionKey) && (0 != [actionKey length])) {
	NSRange r = [actionKey rangeOfString: @"openfs "];
	if (r.location != NSNotFound) {
            [self openFilesystem: [actionKey substringFromIndex: r.length]];
        }
    }
}

@end

