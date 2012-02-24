/*
 *    VolumeWindowController.h
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

#ifndef __VOLUMEWINDOWCONTROLLER_H_INCLUDED
#define __VOLUMEWINDOWCONTROLLER_H_INCLUDED

#include <AppKit/AppKit.h>
#include <VolumeManagerProtocols.h>


@interface VolumeWindowController: NSObject <VolumeManagerClientProtocol>
{
    IBOutlet NSWindow *window;
    IBOutlet NSTableView *mountedVolumes;
    IBOutlet NSButton *unmountButton;

    id volumeManager;
    NSMutableDictionary *mounts;
}

- (IBAction) unmountClicked: (id)sender;
- (IBAction) volumeSelected: (id)sender;

- (NSWindow *) window;

- (void) setVolumeManager: (id)manager;

@end

#endif
