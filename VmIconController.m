/*
 *    VmIconController.m
 *
 *    Copyright (c) 2007
 *
 *    Author: Andreas Schik <aheppel@web.de>
 *
 *    This program is free software; you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation; either version 2 of the License, or
 *    (at your option) any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.    See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program; if not, write to the Free Software
 *    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <AppKit/AppKit.h>
#import <DBusKit/DBusKit.h>

#include "VmIconController.h"


@protocol Notifications
- (NSNumber *) Notify: (NSString *) appname
                     : (uint) replaceid
                     : (NSString *) appicon
                     : (NSString *) summary
                     : (NSString *) body
                     : (NSArray *) actions
                     : (NSDictionary *) hints
                     : (int) expires;
@end

static NSString * const DBUS_BUS = @"org.freedesktop.Notifications";
static NSString * const DBUS_PATH = @"/org/freedesktop/Notifications";

static const long MSG_TIMEOUT = 10000;

@interface VmIconController (Private)
- (void) showVolumeManagerWindow: (id)sender;
- (void) setupTooltip: (NSArray *)volumes;
@end

@implementation VmIconController (Private)

- (void) showVolumeManagerWindow: (id)sender
{
    if (volumeWindowController != nil) {
        if ([volumeWindowController window] == nil) {
            DESTROY(volumeWindowController);
        }
    }
    if (volumeWindowController == nil) {
        volumeWindowController = [[VolumeWindowController alloc] init];
        [volumeWindowController setVolumeManager: volumeManager];
    }
    if ((volumeWindowController != nil)
            && ![[volumeWindowController window] isVisible]) {
        [[volumeWindowController window] makeKeyAndOrderFront: self];
    }
}

- (void) setupTooltip: (NSArray *)volumes
{
    if ([volumes count] == 0) {
        [tic setTooltipText: @"No volumes monted."];
    } else {
        NSMutableString *tooltip = [NSMutableString new];
        NSEnumerator *enumerator = [volumes objectEnumerator];
        NSDictionary *volume;
        while ((volume = [enumerator nextObject])) {
            NSString *label = [volume objectForKey: @"label"];
            NSString *mpoint = [volume objectForKey: @"mountPoint"];
            NSString *msg = [NSString stringWithFormat:
                             _(@"VmIconController.msg.mounted_at"), label, mpoint];
            [tooltip appendString: msg];
        }
        [tic setTooltipText: tooltip];
    }
}

@end

@implementation VmIconController

/**
 * <p><init /></p>
 * <p>Establishes the connection to the VolumeManager service.</p>
 */
- (id) init
{
    self = [super init];
    if (self != nil) {
        volumeWindowController = nil;

        NSBundle *bundle = [NSBundle bundleForClass: [self class]];
        NSString *path = nil;
        path = [bundle pathForResource: @"SystrayIcon" ofType: @"tiff"];
        tic = [[TrayIconController alloc] init];
        [tic createButton: path
                   target: self
                   action: @selector(showVolumeManagerWindow:)];
    }
    return self;
}


- (void) dealloc
{
    DESTROY(tic);
    DESTROY(volumeWindowController);
    [super dealloc];
}

- (void) setVolumeManager: (id)manager
{
    ASSIGN(volumeManager, manager);
    if (volumeManager != nil) {
        // Register ourself to receive notifications when volumes are
        // added or removed.
        CREATE_AUTORELEASE_POOL(pool);
        NSData *data = [volumeManager getMountedVolumes];
        NSArray *volumes = [NSUnarchiver unarchiveObjectWithData: data];
        // If there are volumes show the icon
        if ([volumes count] > 0) {
            [tic showTrayIcon];
        } else {
            [tic hideTrayIcon];
        }
        [self setupTooltip: volumes];
        RELEASE(pool);
    }
    if (volumeWindowController != nil) {
        [volumeWindowController setVolumeManager: volumeManager];
    }
}

- (void) showMessage: (NSTimer *)timer
{
    NSDictionary *info = [timer userInfo];
    NSString *event = [info objectForKey: @"event"];
    NSString *msg = nil;
    NSArray *actions = [NSArray array];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if([defaults boolForKey: @"disable_notifications"] == YES) {
        return;
    }

    if ([event isEqual: @"VME_VOLUME_MOUNTED"]) {
	BOOL autoopenFS = [defaults boolForKey: @"autoopen_fs"];
        NSString *label = [info objectForKey: @"label"];
        NSString *mpoint = [info objectForKey: @"mountPoint"];
        
	msg = [[NSString alloc] initWithFormat: _(@"VmIconController.msg.mounted_at"), label, mpoint];
        NSDebugLog(_(@"VmIconController.msg.mounted_at"), label, mpoint);

        // If a mounted device is not opened automatically we offer
        // an action in the notification, by which the user can do
	// it manually.
        if (NO == autoopenFS) {
            NSString *serviceName = [defaults objectForKey: @"autoopen_fs_service"];
            if (serviceName && [serviceName length]) {
                actions = [NSArray arrayWithObjects: [NSString stringWithFormat: @"openfs %@", mpoint], serviceName, nil];
            }
        }
    }
    if (msg != nil) {
        NSConnection *c;
        NSNumber *dnid;
        id <NSObject,Notifications> remote;
        BOOL handled = NO;

	// Try to deliver the message via DBus to a notification handler.
	// If this does not work display the message via the system tray.
        NS_DURING {
            c = [NSConnection
                connectionWithReceivePort: [DKPort port]
                                 sendPort: [[DKPort alloc] initWithRemote: DBUS_BUS]];

            if (c) {
                remote = (id <NSObject,Notifications>)[c proxyAtPath: DBUS_PATH];
                if (remote) {
                    NSBundle *bundle = [NSBundle bundleForClass: [self class]];
                    NSString *iconPath = [bundle pathForResource: @"AppIcon" ofType: @"tiff"];

                    dnid = [remote Notify: @"VolumeManager" 
                                         : 0 
                                         : iconPath 
                                         : _(@"VmIconController.volume.mounted") 
                                         : msg
                                         : actions 
                                         : [NSDictionary dictionary]
                                         : MSG_TIMEOUT];
                    handled = YES;
                }
                [c invalidate];
            }
        }
        NS_HANDLER
        {
        }
        NS_ENDHANDLER
        if (handled == NO) {
            [self sendMessage: msg timeout: MSG_TIMEOUT];
        }
        RELEASE(msg);
    }
}

/**
 * <p>Called by the VolumeManager service when a volume changed its
 * mount status.</p>
 * <p>The method adds the volume to the list of mounted volumes or removes
 * it from the list as appropriate.</p>
 * <br />
 * <strong>Inputs</strong>
 * <br />
 * <deflist>
 * <term>volumeChangeInfo</term>
 * <desc>Contains the information about the changed volume and
 * whether it was mounted or unmounted.</desc>
 * </deflist>
 */
- (oneway void) volumeDidChange: (NSData *)volumeChangeInfo
{
    CREATE_AUTORELEASE_POOL(pool);
    NSData *data = [volumeManager getMountedVolumes];
    NSArray *volumes = [NSUnarchiver unarchiveObjectWithData: data];
    // If there are volumes show the icon
    NSDebugLog(@"No of mounted volumes is %lu", (unsigned long)[volumes count]);
    if ([volumes count] > 0) {
        [tic showTrayIcon];
    } else {
        [tic hideTrayIcon];
    }
    [self setupTooltip: volumes];

    // For some reason the icon is not displayed properly
    // if we send the message directly. Hence we set up a
    // timer to display the systray message with a slight delay.
    NSDictionary *info = [NSUnarchiver unarchiveObjectWithData: volumeChangeInfo];
    [NSTimer scheduledTimerWithTimeInterval: 0.2
                                     target: self
                                   selector: @selector(showMessage:)
                                   userInfo: info
                                    repeats: NO];
    RELEASE(pool);
    if (volumeWindowController != nil) {
        [volumeWindowController volumeDidChange: volumeChangeInfo];
    }
}


@end
