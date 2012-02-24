/* Volume.m
 *  
 * Copyright (C) 2007, 2011 Andreas Schik
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

#include <sys/stat.h>
#include <unistd.h>

#include "Volume.h"


@interface Volume (Private)

- (void) setLabel;
- (void) setMountPoint;
- (void) setDevice;

@end


@implementation Volume (Private)

- (void) setLabel
{
    // Try to get the volume label. If we fail here we will
    // generate a label from the mount point.
    label = [halHandler getStringProperty: @"volume.label"
                                forDevice: udi];

    if ((label == nil) || ([label length] == 0)) {
        NSString *mp = [self mountPoint];
        if (mp) {
            label = [[mp lastPathComponent] copy];
        } else {
            label = nil;
        }
    }
}

- (void) setMountPoint
{
    mountPoint = [halHandler getStringProperty: @"volume.mount_point"
                                     forDevice: udi];
}

- (void) setDevice
{
    device = [halHandler getStringProperty: @"block.device"
                                 forDevice: udi];
}

@end


@implementation Volume

- (id) initWithUdi: (NSString *)anUdi andHalHandler: (HalHandler *)handler;
{
    self = [super init];
  
    if (self) {
        shouldUnmount = YES;
        udi = [anUdi copy];
        halHandler = handler;
	RETAIN(halHandler);
        [self setLabel];
        [self setDevice];
        // we do not have a mount point, yet
        mountPoint = nil;
    }
    return self;
}

- (void)dealloc
{
    RELEASE(halHandler);
    RELEASE(label);
    RELEASE(mountPoint);
    RELEASE(device);
    RELEASE(udi);
    [super dealloc];
}

- (NSString *)label
{
    static int unknownVolCount = 0;
    if (label == nil) {
        [self setLabel];
    }
    if (label == nil) {
        // If label is still nil it means we do not have a mount point, yet.
        // Return a temporary label. May the next time...
        return [NSString stringWithFormat: @"Unknown Volume %d", ++unknownVolCount];

    }
    return label;
}

- (NSString *)mountPoint
{
    if (mountPoint == nil) {
        [self setMountPoint];
    }
    return mountPoint;
}

- (NSString *)device
{
    return device;
}

- (BOOL) shouldUnmount
{
    return shouldUnmount;
}

- (void) setShouldUnmount: (BOOL)unmount
{
    shouldUnmount = unmount;
}

@end

