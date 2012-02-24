/* ConnectionManager.m
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

#include <AppKit/AppKit.h>
#include "ConnectionManager.h"


@interface ConnectionManager (Private)
- (void) createMenu;
@end


@implementation ConnectionManager (Private)
- (void) createMenu
{
    NSMenu*         menu;
    NSMenu*         info;
    SEL             action = @selector(method:);

    menu = [[NSMenu alloc] initWithTitle: @"VolumeManager"];

    [menu addItemWithTitle: _(@"Info")
                    action: action
             keyEquivalent: @""];

    [menu addItemWithTitle: _(@"Quit")
                    action: @selector(terminate:)
             keyEquivalent: @"q"];

    info = [NSMenu new];
    [menu setSubmenu: info
             forItem: [menu itemWithTitle: _(@"Info")]];

    [info addItemWithTitle: _(@"Info Panel...")
                    action: @selector(orderFrontStandardInfoPanel:)
             keyEquivalent: @""];

    [[NSApplication sharedApplication] setMainMenu: menu];

    [menu update];
    [menu display];
}

@end


@implementation ConnectionManager

- (id) init
{
    self = [super init];
  
    if (self) {
        clients = [NSMutableSet new];
    }
  
    return self;
}

- (void) applicationWillFinishLaunching: (NSNotification *) notif
{
//    [self createMenu];

    tiController = [[VmIconController alloc] init];
    [tiController setVolumeManager: self];

    volumeManager = [[VolumeManager alloc] init];
    [volumeManager setDelegate: self];
}

- (void) applicationDidFinishLaunching: (NSNotification *) notif
{

    [NSApp registerServicesMenuSendTypes:
        [NSArray arrayWithObjects: @"NSStringPboardType", nil]
                             returnTypes: nil];

    conn = [NSConnection defaultConnection];
    [conn setRootObject: self];
    [conn setDelegate: self];

    NSPortNameServer *svr = [NSPortNameServer systemDefaultPortNameServer];
    NSPort *port = [svr portForName: @"VolumeManager"];
    if (port == nil) {
        if ([conn registerName: @"VolumeManager"] == NO) {
            NSDebugLog(@"unable to register with name server.");
        }
    }
    nc = [NSNotificationCenter defaultCenter];
    [nc addObserver: self
           selector: @selector(connectionBecameInvalid:)
               name: NSConnectionDidDieNotification
             object: conn];

    [volumeManager mountAll];
}

- (void)applicationWillTerminate: (NSNotification *)notif
{
    DESTROY(volumeManager);
    DESTROY(tiController);

    NSEnumerator *enumerator = [clients objectEnumerator];
    VMClientInfo *info;
    while ((info = [enumerator nextObject])) {
        NSConnection *connection =
            [(NSDistantObject *)[info client] connectionForProxy];

        if (connection) {
            [nc removeObserver: self
                          name: NSConnectionDidDieNotification
                        object: connection];
        }
    }

    if (conn) {
        [nc removeObserver: self
                      name: NSConnectionDidDieNotification
                    object: conn];
    }
    DESTROY(clients);
}

- (void) notifyClientsForEvent: (unsigned int)event
                      withInfo: (NSDictionary *)info
{
    CREATE_AUTORELEASE_POOL(pool);
    NSData *data = [NSArchiver archivedDataWithRootObject: info];
    NSEnumerator *enumerator = [clients objectEnumerator];
    VMClientInfo *clinfo;

    if (tiController != nil) {
        [tiController volumeDidChange: data];
    }

    while ((clinfo = [enumerator nextObject])) {
        if ([clinfo watchesEvent: event]) {
            [[clinfo client] volumeDidChange: data];
        }
    }

    RELEASE (pool);  
}

/**
 * <p>Called by the VolumeManager when a mixed mode CD is inserted.</p>
 * <p> The method displays a panel to the user requesting what
 * the service is supposed to do.</p>
 */
- (enum VolumeChangeCommands) requestPlayOrMountFromUser: (NSDictionary *)info
{
    CREATE_AUTORELEASE_POOL(pool);

    NSString *device = [info objectForKey: @"device"];
    NSBundle *bundle = [NSBundle bundleForClass: [self class]];
    NSString *msg = NSLocalizedStringFromTableInBundle( @"RemovableMediaMenulet.message.play.mount", nil, bundle, @"");
    NSString *play = NSLocalizedStringFromTableInBundle( @"RemovableMediaMenulet.button.play", nil, bundle, @"");
    NSString *mount = NSLocalizedStringFromTableInBundle(@"RemovableMediaMenulet.button.mount", nil, bundle, @"");
    int result = NSRunAlertPanel(@"Volume Manager", msg, play, mount, nil, device);
    RELEASE (pool);
    if (result == NSAlertDefaultReturn) {
        return VMC_VOLUME_PLAY;
    } else {
        return VMC_VOLUME_MOUNT;
    }
    return VMC_VOLUME_NOOP;
}

/**
 * <p>Returns an info object from the set of registerd clients.</p>
 * <br />
 * <strong>Inputs</strong>
 * <br />
 * <deflist>
 * <term>client</term>
 * <desc>The client object for which to retrieve the information.</desc>
 * </deflist>
 */
- (VMClientInfo *)clientInfoForClient: (id)client
{
    NSEnumerator *enumerator = [clients objectEnumerator];
    VMClientInfo *info;

    while ((info = [enumerator nextObject])) {
        if ([info client] == client) {
            return info;
        }
    }
    return nil;
}

/**
 * When the connection becomes invalid, we destroy all
 * registered client objects to no longer try to notify
 * them about changes.
 */
- (void) connectionBecameInvalid: (NSNotification *)notification
{
    id connection = [notification object];

    [nc removeObserver: self
                  name: NSConnectionDidDieNotification
                object: connection];

    if (connection == conn) {
        NSDebugLog(@"argh - halHandler server root connection has been destroyed.");
        exit(EXIT_FAILURE);
    } else {
	// Create a snapshot of the client set. This is necessary
	// as we manipulate the original set during enumeration.
        NSArray *clArray = [clients allObjects];
        int i, count = [clArray count];
        for (i = 0; i < count; i++) {
            VMClientInfo *info = [clArray objectAtIndex: i];
	    if ([(NSDistantObject *)[info client] connectionForProxy] == connection) {
		// The info object destroys its inner client object.
                [clients removeObject: info];
            }
        }
    }
}


- (BOOL)applicationShouldTerminate:(id)sender
{
    NSDebugLog(@"Application will exit");
    if (volumeManager != nil) {
        [volumeManager unmountAll];
    }

    return YES;
}


@end

