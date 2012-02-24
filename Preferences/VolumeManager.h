/* VolumeManager.h
 *  
 * Copyright (C) 2007, 2011 Andreas Schik
 *
 * Author: Andreas Schik <andreas@schik.de>
 *
 * This file is part of the preferences pane for VolumeManager.app.
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

#ifndef __VOLMAN_H_INCLUDED
#define __VOLMAN_H_INCLUDED

#include <AppKit/AppKit.h>

#include <PreferencePanes/PreferencePanes.h>

@interface VolumeManager: NSPreferencePane
{
  IBOutlet NSTextField *autoopenFSService;
  IBOutlet NSTextField *autoplayCDAService;
  IBOutlet NSTextField *autoplayDVDService;
  IBOutlet NSButton *automountDrives;
  IBOutlet NSButton *disableNotifications;
  IBOutlet NSButton *autoopenFilesystem;
  IBOutlet NSButton *autoplayAudioCDs;
  IBOutlet NSButton *autoplayDVDs;
  BOOL loaded;
}

- (IBAction) setButtonClicked: (id)sender;

@end

#endif
