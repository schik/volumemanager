/* VolumeManager.m
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

#include <AppKit/AppKit.h>
#include "VolumeManager.h"


static NSUserDefaults    *defaults = nil;
static NSMutableDictionary  *domain = nil;



@implementation VolumeManager

- (void) dealloc
{
  [super dealloc];
}

/**
 * After the window has been loaded, the method reads the defaults
 * for VolumeManager and poulates the controls.
 */
- (void)mainViewDidLoad
{
  if (loaded == YES) {
    return;
  }

  defaults = [NSUserDefaults standardUserDefaults];
  domain = [[defaults persistentDomainForName: @"VolumeManager"] mutableCopy];
  [defaults synchronize];
  if (domain == nil) {
    domain = [NSMutableDictionary new];
    [defaults setPersistentDomain: domain forName: @"VolumeManager"];
    [defaults synchronize];
  }
  id entry;

  entry = [domain objectForKey: @"disable_notifications"];
  if (entry) {
    [disableNotifications setState: ([entry boolValue] ? NSOnState : NSOffState)];
  } else {
    [disableNotifications setState: NSOffState];
  }

  entry = [domain objectForKey: @"automount_drives"];
  if (entry) {
    [automountDrives setState: ([entry boolValue] ? NSOnState : NSOffState)];
  } else {
    [automountDrives setState: NSOffState];
  }

  entry = [domain objectForKey: @"autoopen_fs_service"];
    
  if (entry) {
    [autoopenFSService setStringValue: entry];
  } else {
    [autoopenFSService setStringValue: @""];
  }

  entry = [domain objectForKey: @"autoopen_fs"];
  if (entry) {
    [autoopenFilesystem setState: ([entry boolValue] ? NSOnState : NSOffState)];
  } else {
    [autoopenFilesystem setState: NSOffState];
  }

  entry = [domain objectForKey: @"autoplay_cda"];
  if (entry) {
    [autoplayAudioCDs setState: ([entry boolValue] ? NSOnState : NSOffState)];
  } else {
    [autoplayAudioCDs setState: NSOffState];
  }

  entry = [domain objectForKey: @"autoplay_cda_service"];
    
  if (entry) {
    [autoplayCDAService setStringValue: entry];
  } else {
    [autoplayCDAService setStringValue: @""];
  }

  entry = [domain objectForKey: @"autoplay_dvd"];
  if (entry) {
    [autoplayDVDs setState: ([entry boolValue] ? NSOnState : NSOffState)];
  } else {
    [autoplayDVDs setState: NSOffState];
  }

  entry = [domain objectForKey: @"autoplay_dvd_service"];
    
  if (entry) {
    [autoplayDVDService setStringValue: entry];
  } else {
    [autoplayDVDService setStringValue: @""];
  }

  loaded = YES;
}

/*
 * The following methods react on changes done by the user
 * and immediately write back the changed values to the defaults
 * for VolumeManager.
 */

- (IBAction) setButtonClicked: (id)sender
{
  CREATE_AUTORELEASE_POOL(pool);

  [domain setObject: [NSNumber numberWithBool: ([disableNotifications state] == NSOnState)]
             forKey: @"disable_notifications"];
  [domain setObject: [NSNumber numberWithBool: ([automountDrives state] == NSOnState)]
             forKey: @"automount_drives"];
  [domain setObject: [NSNumber numberWithBool: ([autoopenFilesystem state] == NSOnState)]
             forKey: @"autoopen_fs"];
  [domain setObject: [NSNumber numberWithBool: ([autoplayAudioCDs state] == NSOnState)]
             forKey: @"autoplay_cda"];
  [domain setObject: [NSNumber numberWithBool: ([autoplayDVDs state] == NSOnState)]
             forKey: @"autoplay_dvd"];
  [domain setObject: [autoplayCDAService stringValue] forKey: @"autoplay_cda_service"];
  [domain setObject: [autoopenFSService stringValue] forKey: @"autoopen_fs_service"];
  [domain setObject: [autoplayDVDService stringValue] forKey: @"autoplay_dvd_service"];
  [defaults setPersistentDomain: domain forName: @"VolumeManager"];
  [defaults synchronize];
  RELEASE(pool);
}


@end
