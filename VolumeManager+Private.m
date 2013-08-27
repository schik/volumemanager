/* VolumeManager+Private.m
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

#include <AppKit/NSPasteboard.h>
#include <AppKit/NSApplication.h>

#include "ConnectionManager.h"
#include "VolumeManager.h"
#include "VolumeManagerProtocols.h"
#include "Volume.h"



@interface VolumeManager (Private)

- (BOOL) mediaChanged: (NSString *)udi
            andDevice: (NSString *)device;

- (BOOL) mediaIsCDROM: (NSString *)device;

- (BOOL) handleCDROM: (NSString *)udi;

- (BOOL) playCDA: (NSString *)device;

- (BOOL) playDVD: (NSString *)device;

- (BOOL) openFilesystem: (NSString *)device;

- (BOOL) mountVolume: (NSString *)udi;

- (BOOL) udiIsSubfsMount: (NSString *)udi;

- (BOOL) udiIsCamera: (NSString *)udi;

// Callback selectors
- (id) blockDeviceAdded: (id) args;
- (id) cameraDeviceAdded: (id) args;

- (BOOL) checkDirectory: (NSString *)directory forName: (NSString *)name;

@end


@implementation VolumeManager (Private)

- (BOOL) mediaChanged: (NSString *)udi
            andDevice: (NSString *)device
{
    BOOL handled = NO;
    
    // Refuse to enforce policy on removable media if drive is locked
    if ([halHandler propertyExists: @"info.locked" forDevice: device]
        && [halHandler getBooleanProperty: @"info.locked" forDevice: device]) {
        NSDebugLog(@"Drive with udi %@ is locked through hal; skipping policy", device);
        // we return YES here because the device is locked - we can pretend we handled it
        return YES;
    }

    if ([self mediaIsCDROM: device]) {
        handled = [self handleCDROM: udi];
    }

    return handled;
}

- (BOOL) executeAutoOpenActions: (NSString *) udi
                         device: (NSString *) device
                        atPoint: (NSString *) mountPoint
{
    BOOL result = NO;

    BOOL is_dvd = [self checkDirectory: mountPoint forName: @"video_ts"];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL autoplayDVD = [defaults boolForKey: @"autoplay_dvd"];
    
    if (is_dvd && autoplayDVD) {
        result = [self playDVD: device];
    } else {
        BOOL autoopenFS = [defaults boolForKey: @"autoopen_fs"];
        if (autoopenFS == YES) {
            result = [self openFilesystem: mountPoint];
        }
    }
    return result;
}

/**
 * Checks whether the file @c name exists at path @c directory.
 * The method does a full enumeration of the directory as we must do
 * a case insensitive file name comparison.
 */
- (BOOL) checkDirectory: (NSString *)directory forName: (NSString *)name
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm directoryContentsAtPath: directory];
    unsigned int count = [contents count];
    unsigned int i;
    for (i = 0; i < count; i++) {
        NSString *item = [contents objectAtIndex: i];
        if ([item caseInsensitiveCompare: name] == NSOrderedSame) {
            return YES;
        }
    }
    return NO;
}

- (BOOL) mediaIsCDROM: (NSString *)device
{
    BOOL is_cdrom = NO;
    NSString *mediaType;

    mediaType = [halHandler getStringProperty: @"storage.drive_type"
                                    forDevice: device];
    if (mediaType != nil) {
        is_cdrom = [mediaType isEqualToString: @"cdrom"];
    }
    
    return is_cdrom;
}
/*
*/

- (BOOL) handleCDROM: (NSString *)udi
{
    BOOL hasAudio = NO;
    BOOL hasData = NO;
    NSString *device = nil;
    BOOL handled = NO;

    device = [halHandler getStringProperty: @"block.device"
                                 forDevice: udi];
    if (device == nil) {
        NSLog(@"cannot get block.device for %@", udi);
        return handled;
    }
    
    BOOL discIsBlank = [halHandler getBooleanProperty: @"volume.disc.is_blank"
                                            forDevice: udi];

    if (discIsBlank == YES) {
#if 0
        int type;
        if ((type = gvm_cdrom_media_is_writable (udi)))
            gvm_run_cdburner (udi, type, device, NULL);
#endif
    } else {
        hasAudio = [halHandler getBooleanProperty: @"volume.disc.has_audio"
                                        forDevice: udi];
        hasData = [halHandler getBooleanProperty: @"volume.disc.has_data"
                                       forDevice: udi];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        BOOL autoplayCDA = [defaults boolForKey: @"autoplay_cda"];
        BOOL automountDrives = [defaults boolForKey: @"automount_drives"];
        if (hasAudio && hasData) {
	    if (autoplayCDA && automountDrives) {
                // Ask GUI client if registered. If no GUI client is registered
                // ignore this medium
                if ((delegate != nil)
                        && ([delegate respondsToSelector: @selector(requestPlayOrMountFromUser:)])) {
                    CREATE_AUTORELEASE_POOL(pool);
                    NSMutableDictionary *info = [NSMutableDictionary dictionary];
                    [info setObject: device forKey: @"device"];

                    enum VolumeChangeCommands cmd = [delegate requestPlayOrMountFromUser: info];
                    RELEASE (pool);
                    if (cmd == VMC_VOLUME_MOUNT) {
                        hasAudio = NO;
                    } else if (cmd == VMC_VOLUME_PLAY) {
                        hasData = NO;
                    } else {
                        hasData = hasAudio = NO;
                    }
                }
            } else if (autoplayCDA) {
                hasData = NO;
            } else if (automountDrives) {
                hasAudio = NO;
            }
        }
        if (hasAudio) {
            if (autoplayCDA) {
                handled = [self playCDA: device];
            } else {
                // TODO: Send notification about inserted CDA
            }
        } else if (hasData) {
            if (automountDrives && ![self udiIsSubfsMount: udi]) {
                [self mountVolume: udi];
                handled = YES;
            }
        }
    }
    
    return handled;
}

- (BOOL) playCDA: (NSString *)device
{
    BOOL handled = NO;
    NSPasteboard *pboard;
    NSArray    *urlPboardTypes;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *serviceName = [defaults objectForKey: @"autoplay_cda_service"];

    if (serviceName && [serviceName length]) {
        pboard = [NSPasteboard pasteboardWithUniqueName];
        urlPboardTypes = [NSArray arrayWithObjects: NSStringPboardType, nil];
        [pboard declareTypes: urlPboardTypes owner: nil];
        [pboard setString: device forType: NSStringPboardType];
        NSPerformService(serviceName, pboard);
        handled = YES;
    } else {
        NSDebugLog(@"No service known for playing audio CDs.");
    }
    return handled;
}

- (BOOL) playDVD: (NSString *)device
{
    BOOL handled = NO;
    NSPasteboard *pboard;
    NSArray    *urlPboardTypes;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *domain = [defaults persistentDomainForName: @"VolumeManager"];
    NSString *serviceName = [domain objectForKey: @"autoplay_dvd_service"];

    if (serviceName && [serviceName length]) {
        pboard = [NSPasteboard pasteboardWithUniqueName];
        urlPboardTypes = [NSArray arrayWithObjects: NSStringPboardType, nil];
        [pboard declareTypes: urlPboardTypes owner: nil];
        [pboard setString: device forType: NSStringPboardType];
        NSPerformService(serviceName, pboard);
        handled = YES;
    } else {
        NSDebugLog(@"No service known for playing DVDs.");
    }
    return handled;
}

- (BOOL) openFilesystem: (NSString *)path
{
    BOOL handled = NO;
    NSPasteboard *pboard;
    NSArray    *urlPboardTypes;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *serviceName = [defaults objectForKey: @"autoopen_fs_service"];

    if (serviceName && [serviceName length]) {
        pboard = [NSPasteboard pasteboardWithUniqueName];
        urlPboardTypes = [NSArray arrayWithObjects: NSStringPboardType, nil];
        [pboard declareTypes: urlPboardTypes owner: nil];
        [pboard setString: path forType: NSStringPboardType];
        NSPerformService(serviceName, pboard);
        handled = YES;
    } else {
        NSDebugLog(@"No service known for opening the file system.");
    }
    return handled;
}

- (BOOL) mountVolume: (NSString *)udi
{
    BOOL mounted;
    Volume *vol = [[Volume alloc] initWithUdi: udi andHalHandler: halHandler];
    [mountedVolumes setObject: vol forKey: udi];
    if((mounted = [vol mount]) != YES) {
        [mountedVolumes removeObjectForKey: udi];
    }
    RELEASE(vol);
    return mounted;
}

- (BOOL) udiIsSubfsMount: (NSString *)udi
{
    BOOL subfs = NO;
    NSArray *callouts;
    int i;
    
    if ((callouts = [halHandler getStrlistProperty: @"info.callouts.add"
                                         forDevice: udi])) {
        for (i = 0; i < [callouts count]; i++) {
            if ([[callouts objectAtIndex: i] isEqualToString: @"hald-block-subfs"]) {
                NSDebugLog(@"subfs to handle mounting of %@; skipping\n", udi);
                subfs = YES;
                break;
            }
        }
    }
    
    return subfs;
}

- (BOOL) udiIsCamera: (NSString *)udi
{
    BOOL isCamera = YES;
    NSString *accessMethod;
    NSString *driver;
    
    accessMethod = [halHandler getStringProperty: @"camera.access_method"
                                       forDevice: udi];
    if (accessMethod == nil) {
        return NO;
    }
    
    if ([accessMethod isEqualToString: @"storage"]) {
        NSDebugLog(@"camera is mass-storage device");
        // we only want to match non-storage cameras
        isCamera = NO;
        goto done;
    } else if ([accessMethod isEqualToString: @"ptp"]) {
        NSDebugLog(@"camera is PTP device");
        // ptp cameras are supported by libgphoto2 always
        isCamera = YES;
        goto done;
    } else if ([accessMethod isEqualToString: @"libgphoto2"]) {
        NSDebugLog(@"camera is libgphoto2 device");
        driver = [halHandler getStringProperty: @"info.linux.driver"
                                     forDevice: udi];
        if (driver != nil) {
            // the old fdi files marked everything as access_method="libgphoto2" so check that
            // this is a non-mass-storage camera
            if ([driver isEqualToString: @"usb-storage"]) {
                isCamera = NO;
            }
        } else {
            isCamera = YES;
        }
        
        goto done;
    }
    
    NSDebugLog(@"Non Mass-Storage Camera detected: %@\n", udi);
    isCamera = [halHandler getBooleanProperty: @"camera.libgphoto2.support"
                                    forDevice: udi];
    
done:
    
    return isCamera;
}

- (id) blockDeviceAdded: (id) args
{
    NSDictionary *argsDict = (NSDictionary *)args;
    NSString *udi = [argsDict objectForKey: @"udi"];
    BOOL mountable = NO;
    BOOL partTableChanged = NO;
    BOOL removable = NO;
    NSString *device = nil;
    NSString *fsusage = nil;
    BOOL crypto = NO;
    NSString *storageDevice = nil;

    // is this a mountable volume?
    mountable = [halHandler getBooleanProperty: @"block.is_volume"
                                     forDevice: udi];
    if (mountable == NO) {
        NSDebugLog(@"not a mountable volume: %@\n", udi);
        goto out;
    }
    
    // if it is a volume, it must have a device node
    device = [halHandler getStringProperty: @"block.device"
                                 forDevice: udi];
    if (device == nil) {
        NSDebugLog(@"cannot get block.device for %@\n", udi);
        goto out;
    }
    
    // only mount if the block device has a sensible filesystem
    fsusage = [halHandler getStringProperty: @"volume.fsusage"
                                  forDevice: udi];
    if (fsusage == nil) {
        NSDebugLog(@"unable to get fsusage for %@\n", udi);
        mountable = NO;
    } else if ([fsusage isEqualToString: @"crypto"]) {
        NSDebugLog(@"encrypted volume found: %@\n", udi);
        // TODO: handle encrypted volumes
        mountable = NO;
        crypto = YES;
    } else if (![fsusage isEqualToString: @"filesystem"]) {
        NSDebugLog(@"no sensible filesystem for %@\n", udi);
        mountable = NO;
    }
    
    // get the backing storage device
    storageDevice = [halHandler getStringProperty: @"block.storage_device"
                                        forDevice: udi];
    if (storageDevice == nil) {
        NSDebugLog(@"cannot get block.storage_device for %@\n", udi);
        goto out;
    }
    
    // if the partition_table_changed flag is set, we don't want
    // to mount as a partitioning tool might be modifying this
    // device
    partTableChanged = [halHandler getBooleanProperty: @"storage.partition_table_changed"
                                            forDevice: storageDevice];
    if (partTableChanged == YES) {
        NSDebugLog(@"partition table changed for %@\n", storageDevice);
        goto out;
    }

    // Does this device support removable media?  Note that we
    // check storage_device and not our own UDI
    removable = [halHandler getBooleanProperty: @"storage.removable"
                                     forDevice: storageDevice];
    if (removable == YES) {
        // we handle media change events separately
        NSDebugLog(@"Changed: %@\n", device);
        if ([self mediaChanged: udi
                     andDevice: storageDevice])
            goto out;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL automountDrives = [defaults boolForKey: @"automount_drives"];
    if (automountDrives && (mountable || crypto)) {
        if (![self udiIsSubfsMount: udi]) {
            if (![halHandler getBooleanProperty: @"volume.ignore"
                                      forDevice: udi]) {
                if ([self mountVolume: udi])
                    goto out;
            } else {
                NSDebugLog(@"volume.ignore set to true on %@, not mounting\n", udi);
            }
        }
    }
out:
    [device release];
    [fsusage release];
    [storageDevice release];
    
    return self;
}

- (id) cameraDeviceAdded: (id) args
{
    NSDictionary *argsDict = (NSDictionary *)args;
    NSString *udi = [argsDict objectForKey: @"udi"];

    // Check that the camera is a non-storage camera.
    // Mass-storage cameras are mounted as file systems and can be viewed
    // using GWorkspace, for example. For all others we need a special app,
    // such as Camera or PhotoTransfer.
    if (![self udiIsCamera: udi]) {
        return self;
    }
    // TODO: Take some action here
    // Currently I do not know what to do exactly, We probably
    // need to find out where the camera is and pass this on to
    // an app, thus saving the app from autodetection
    return self;
}

- (void) volumeAttached
{
}


- (void) volumeRemoved
{
}

- (void) sendVolumeMountedNotification: (NSString *)device
                               atPoint: (NSString *)mountPoint
                             withLabel: (NSString *)label
{
    NSDebugLog(@"Volume %@ (%@) mounted on %@", device, label, mountPoint);
    CREATE_AUTORELEASE_POOL(pool);
    NSMutableDictionary *eventInfo;

    eventInfo = [NSMutableDictionary dictionary];
    [eventInfo setObject: @"VME_VOLUME_MOUNTED" forKey: @"event"];
    [eventInfo setObject: device forKey: @"device"];
    [eventInfo setObject: mountPoint ? mountPoint : (NSString*)@"" forKey: @"mountPoint"];
    [eventInfo setObject: label forKey: @"label"];
    if ((delegate != nil)
        && ([delegate respondsToSelector: @selector(notifyClientsForEvent:withInfo:)])) {
        [delegate notifyClientsForEvent: VME_VOLUME_MOUNTED withInfo: eventInfo];
    }

    RELEASE (pool);
}


- (void) volumeUnmounted: (NSString *)label
               fromPoint: (NSString *)mountPoint
{
    NSDebugLog(@"Volume %@ unmounted", label);
    CREATE_AUTORELEASE_POOL(pool);
    NSMutableDictionary *eventInfo;

    eventInfo = [NSMutableDictionary dictionary];
    [eventInfo setObject: @"VME_VOLUME_UNMOUNTED" forKey: @"event"];
    [eventInfo setObject: label forKey: @"label"];
    [eventInfo setObject: mountPoint ? mountPoint : (NSString*)@"" forKey: @"mountPoint"];
    if ((delegate != nil)
        && ([delegate respondsToSelector: @selector(notifyClientsForEvent:withInfo:)])) {
        [delegate notifyClientsForEvent: VME_VOLUME_UNMOUNTED withInfo: eventInfo];
    }

    RELEASE (pool);
}

- (void) actionInvoked
{
}


@end


