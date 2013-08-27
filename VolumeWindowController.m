/*
 *    VolumeWindowController.m
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

#include "VolumeWindowController.h"


@interface VolumeWindowController (Private)
- (void) initWithNibName: (NSString *) nibName;
@end


@implementation VolumeWindowController (Private)

/**
 * <p>Loads the window from the GORM file.</p>
 * <br />
 * <strong>Inputs</strong>
 * <br />
 * <deflist>
 * <term>nibName</term>
 * <desc>The base name of the GORM file to load the window from.</desc>
 * </deflist>
 */
- (void) initWithNibName: (NSString *) nibName
{
    if (![NSBundle loadNibNamed: nibName owner: self]) {
        NSLog (@"Could not load nib \"%@\".", nibName);
    } else {
        volumeManager = nil;
        mounts = [NSMutableDictionary new];
	[window orderOut: self];
        [window setExcludedFromWindowsMenu: YES];
        [window setFrameAutosaveName: @"VolumeManagerWindow"];
        [window setFrameUsingName: @"VolumeManagerWindow"];
    }
}

@end


@implementation VolumeWindowController


/**
 * <p><init /></p>
 * <p>Establishes the connection to the VolumeManager service.</p>
 */
- (id) init
{
    self = [super init];
    if (self != nil) {
        [self initWithNibName: @"RemovableMedia"];
    }
    return self;
}


- (void) dealloc
{
    RELEASE(mounts);
    [super dealloc];
}


/**
 * <p>Finalizes the setup of the window.</p>
 * <p>This is necessary as GORM seems to have some glitches.</p>
 */
- (void)awakeFromNib
{
    // Set the table headings. For some reason this does not work
    // with GORM.
    NSTableColumn *col = [mountedVolumes tableColumnWithIdentifier: @"label"];
    [[col headerCell] setStringValue: @"Label"];

    col = [mountedVolumes tableColumnWithIdentifier: @"mpoints"];
    [[col headerCell] setStringValue: @"Mount point"];

    [self setVolumeManager: nil];
}

- (void)windowWillClose:(NSNotification *)notification
{
    if ([[notification object] isEqual: window]) {
        window = nil;
    }
}

/**
 * <p>Returns the window.</p>
 */
- (NSWindow *) window
 {
    return window;
}

- (void) setVolumeManager: (id)manager
{
    volumeManager = manager;
    if (volumeManager != nil) {
        // Register ourself to receive notifications when volumes are
        // added or removed.
        CREATE_AUTORELEASE_POOL(pool);
        [mounts removeAllObjects];
        NSData *data = [volumeManager getMountedVolumes];
        NSArray *volumes = [NSUnarchiver unarchiveObjectWithData: data];
        NSEnumerator *enumerator = [volumes objectEnumerator];
        NSDictionary *volume;
        while ((volume = [enumerator nextObject])) {
            NSString *label = [volume objectForKey: @"label"];
            NSString *mpoint = [volume objectForKey: @"mountPoint"];
            [mounts setObject: mpoint forKey: label];
        }
        RELEASE(pool);
    } else {
        [mounts removeAllObjects];
        [unmountButton setEnabled: NO];
    }
    [mountedVolumes reloadData];
}


/**
 * <p>Action of the unmount button.</p>
 * <p>The method sends an eject command for the selected volume
 * to the VolumeManager service if a connection exists.</p>
 * <br />
 * <strong>Inputs</strong>
 * <br />
 * <deflist>
 * <term>sender</term>
 * <desc>The sender of the notification. Usually the button itself.</desc>
 * </deflist>
 */
- (IBAction) unmountClicked: (id)sender
{
    if (volumeManager == nil) {
        return;
    }
    int index = [mountedVolumes selectedRow];
    if (index < 0) {
        return;
    }
    CREATE_AUTORELEASE_POOL(pool);
    NSArray *labels = [mounts allKeys];
    NSString *label = [labels objectAtIndex: index];
    NSString *mpoint = [mounts objectForKey: label];
    NSData *data = [NSArchiver archivedDataWithRootObject: mpoint];
    [volumeManager client: self executeCommand: VMC_VOLUME_EJECT withData: data];
    RELEASE(pool);
}


/**
 * <p>Enables the unmount button if a volume is selected.</p>
 */
- (IBAction) volumeSelected: (id)sender
{
    [unmountButton setEnabled: ([(NSTableView*)sender numberOfSelectedRows] == 1)];
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
    NSDictionary *info = [NSUnarchiver unarchiveObjectWithData: volumeChangeInfo];
    NSString *event = [info objectForKey: @"event"];

    if ([event isEqual: @"VME_VOLUME_MOUNTED"]) {
        NSString *label = [info objectForKey: @"label"];
        NSString *mpoint = [info objectForKey: @"mountPoint"];
        [mounts setObject: mpoint forKey: label];
    } else if ([event isEqual: @"VME_VOLUME_UNMOUNTED"]) {
        NSString *label = [info objectForKey: @"label"];
        [mounts removeObjectForKey: label];
    }
    RELEASE(pool);
    [mountedVolumes reloadData];
    [mountedVolumes deselectAll: self];
    [unmountButton setEnabled: NO];
}


/**
 * <p>Returns the number of mounted volumes.</p>
 */
- (int) numberOfRowsInTableView: (NSTableView *)tableView
{
    return [mounts count];
}


/**
 * <p>Returns the label or mount point for a certain volume
 * to be displayed in the table.</p>
 */
- (id) tableView: (NSTableView *) tableView
 objectValueForTableColumn: (NSTableColumn *) tableColumn 
               row: (int) row
{
    NSArray *keys = [mounts allKeys];
    NSString *key = [keys objectAtIndex: row];
    if ([[tableColumn identifier] isEqual: @"label"]) {
        return  key;
    } else {
        return [mounts objectForKey: key];
    }

    return @"";
}


@end
