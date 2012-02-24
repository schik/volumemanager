/* Volume+Pmount.m
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

#include <sys/stat.h>
#include <unistd.h>

#include "Volume.h"


@interface Volume (Pmount)

- (NSString *)which: (NSString *)name;

@end


@implementation Volume (Pmount)

- (NSString *)which: (NSString *)name
{
    int i, count;
    NSDictionary   *env;
    NSString *pathEnv;
    NSArray *pathList;
    NSString *test;
    NSFileManager *fileMan = [NSFileManager defaultManager];

    // Test the file name as is. Maybe we do not need to
    // walk through the whole search path.
    if ([fileMan isExecutableFileAtPath: name])
        return name;

    env = [[NSProcessInfo processInfo] environment];
    pathEnv = [env objectForKey: @"PATH"];

    if (!pathEnv || [pathEnv length] == 0) {
        return nil;
    }

    pathList = [pathEnv componentsSeparatedByString: @":"];
    count = [pathList count];

    for (i = 0; i < count; i++) {
        test = [[pathList objectAtIndex: i] stringByAppendingPathComponent: name];

        if ([fileMan isExecutableFileAtPath: test])
            return test;
    }

    return nil;
}

@end


@implementation Volume (Mount)

- (BOOL) mount
{
    NSDebugLog(@"mounting %@...", udi);

    // Try to find pmount-hal first. This is a safer method as
    // HAL must be set up properly, i.e. it needs the proper
    // helper script which is not always there...
    NSString *mount = [self which: @"pmount-hal"];

    if (mount != nil) {
        NSTask *task = [[NSTask alloc] init];
        NSArray *args = [NSArray arrayWithObject: udi];
        [task setLaunchPath: mount];
        [task setArguments: args];
        NS_DURING
        {
            [task launch];
        }
        NS_HANDLER
        {
            NSDebugLog(@"Unable to launch %@.", mount);
            DESTROY(task);
            return NO;
        }
        NS_ENDHANDLER
        [task waitUntilExit];

        if ([task terminationStatus]) {
            NSDebugLog(@"executing %@ %@ failed with status %i\n", mount, udi, [task terminationStatus]);
            DESTROY(task);
            return NO;
        }

        DESTROY(task);
        return YES;
    } else {
        NSLog(@"Cannot find pmount-hal. Not mounting device %@", udi);
    }
    return NO;
}

- (BOOL) unmount
{
    NSDebugLog(@"unmounting %@...", udi);
    // Try to find pumount first. This is a safer method as
    // HAL must be set up properly, i.e. it needs the proper
    // helper script which is not always there...
    NSString *umount = [self which: @"pumount"];

    if ((umount != nil) && (device != nil)) {
        NSTask *task = [[NSTask alloc] init];

        NSArray *args = [NSArray arrayWithObjects: device, nil];

        [task setLaunchPath: umount];
        [task setArguments: args];
        NS_DURING
        {
            [task launch];
        }
        NS_HANDLER
        {
            NSDebugLog(@"Unable to launch %@.", umount);
            DESTROY(task);
            return NO;
        }
        NS_ENDHANDLER
        [task waitUntilExit];

        if ([task terminationStatus]) {
            NSDebugLog(@"executing %@ %@ failed with status %i\n", umount, device, [task terminationStatus]);
            DESTROY(task);
            return NO;
        }

        DESTROY(task);
        return YES;
    } else {
        NSLog(@"Cannot find pumount. Not unmounting device %@", udi);
    }
    return NO;
}

- (BOOL) eject
{
    NSDebugLog(@"ejecting %@...", udi);

    NSString *eject = [self which: @"eject"];

    if ((eject != nil) && (device != nil)) {
        NSTask *task = [[NSTask alloc] init];

        NSArray *args = [NSArray arrayWithObjects: device, nil];

        [task setLaunchPath: eject];
        [task setArguments: args];
        NS_DURING
        {
            [task launch];
        }
        NS_HANDLER
        {
            NSDebugLog(@"Unable to launch %@.", eject);
            DESTROY(task);
            return NO;
        }
        NS_ENDHANDLER
        [task waitUntilExit];

        if ([task terminationStatus]) {
            NSDebugLog(@"executing %@ %@ failed with status %i\n", eject, udi, [task terminationStatus]);
            DESTROY(task);
            return NO;
        }

        DESTROY(task);
        return YES;
    } else {
        NSLog(@"Cannot find eject. Not ejecting device %@", udi);
    }
    return NO;
}

@end

