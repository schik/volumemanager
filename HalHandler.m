/* HalHandler.m
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

#import <DBusKit/DBusKit.h>
#import "HalHandler.h"
#import "VolumeManagerProtocols.h"

static int nrHandlers = 0;
static NSLock *hhLock = nil;


static NSString * const DBUS_SVCHAL = @"org.freedesktop.Hal";
static NSString * const DBUS_IFDEVICE = @"org.freedesktop.Hal.Device";
static NSString * const HAL_MANAGER_PATH = @"/org/freedesktop/Hal/Manager";
static NSString * const SIG_PROP_MODIFIED = @"DKSignal_org.freedesktop.Hal.Device_PropertyModified";
static NSString * const SIG_DEVICE_ADDED = @"DKSignal_org.freedesktop.Hal.Manager_DeviceAdded";
static NSString * const SIG_DEVICE_REMOVED = @"DKSignal_org.freedesktop.Hal.Manager_DeviceRemoved";

/**
 * The protocol for org.freedesktop.Hal.Device
 */
@protocol HalDevice

- (NSArray *) GetPropertyStringList: (NSString *)property;
- (NSNumber *) GetPropertyBoolean: (NSString *)property;
- (NSNumber *) PropertyExists: (NSString *)property;
- (NSString *) GetPropertyString: (NSString *)property;
- (NSArray *) FindDeviceByCapability: (NSString *)capability;
@end

@interface HalHandler (Private)

- (id) deviceChangedHandler;
- (id) propertyModifiedHandlerForDevice: (NSString *)device;
@end


@implementation HalHandler (Private)

- (id) deviceChangedHandler
{
    return deviceChangedHandler;
}

- (id) propertyModifiedHandlerForDevice: (NSString *)device
{
    return [propertyModifiedHandlers objectForKey: device];
}

@end


@implementation HalHandler: NSObject

+ (void) initialize
{
    hhLock = [NSLock new];
}

- (id) init
{
    NS_DURING
    {
        [hhLock lock];
        nrHandlers++;
        [hhLock unlock];
    }
    NS_HANDLER
    {
        // unlock then re-raise the exception
        [hhLock unlock];
        [localException raise];
    }
    NS_ENDHANDLER

    propertyModifiedHandlers = nil;
    deviceChangedHandler = nil;

    id h = [super init];
    if (h != nil) {
	center = [[DKNotificationCenter systemBusCenter] retain];
        propertyModifiedHandlers = [NSMutableDictionary new];
        self = h;
    } else {
        [self dealloc];
        self = nil;
    }

    return self;
}

- (void) dealloc
{
    DESTROY(propertyModifiedHandlers);
    [center release];

    [hhLock lock];
    nrHandlers--;
    [hhLock unlock];
    [super dealloc];
}

- (BOOL) registerPropertyModifiedHandler: (id)handler
                               forDevice: (NSString *)device
{
    if (![handler respondsToSelector: @selector(propertyModified:)]) {
        return NO;
    }
    if ([propertyModifiedHandlers objectForKey: device] != nil) {
        return NO;
    }

    if ([device isEqualToString: ALL_DEVICES]) {
        [center addObserver: handler
                   selector: @selector(propertyModified:)
                       name: SIG_PROP_MODIFIED
                     object: nil];
    } else {
//TODO        success = libhal_device_add_property_watch(halContext, [device cString], &error);
    }

    [propertyModifiedHandlers setObject: handler forKey: device];
    return YES;
}

- (void) unregisterPropertyModifiedHandler: (id)handler
                                 forDevice: (NSString *)device
{
    if ([propertyModifiedHandlers objectForKey: device] != handler) {
        return;
    }

    [propertyModifiedHandlers removeObjectForKey: device];

    [center removeObserver: handler
                      name: SIG_PROP_MODIFIED
                    object: nil];
}

- (BOOL) registerDeviceChangedHandler: (id)handler
{
    if (![handler respondsToSelector: @selector(deviceAdded:)]) {
        return NO;
    }
    if (![handler respondsToSelector: @selector(deviceRemoved:)]) {
        return NO;
    }
    if (deviceChangedHandler != nil) {
        return (deviceChangedHandler == handler);
    }
    ASSIGN(deviceChangedHandler, handler);

    [center addObserver: handler
               selector: @selector(deviceAdded:)
                  name: SIG_DEVICE_ADDED
                object: nil];
    [center addObserver: handler
               selector: @selector(deviceRemoved:)
                  name: SIG_DEVICE_REMOVED
                object: nil];
    return YES;
}

- (void) unregisterDeviceChangedHandler: (id)handler
{
    if (deviceChangedHandler != handler) {
        return;
    }
    [center removeObserver: handler
                      name: SIG_DEVICE_ADDED
                    object: nil];
    [center removeObserver: handler
                      name: SIG_DEVICE_REMOVED
                    object: nil];
    DESTROY(deviceChangedHandler);
}

- (NSArray *) getStrlistProperty: (NSString *) property
                       forDevice: (NSString *) device
{
    NSConnection *c;
    NSArray *propList;
    id <NSObject,HalDevice> remote;

    c = [NSConnection connectionWithReceivePort:[DKPort systemBusPort]
                                       sendPort:[[DKPort alloc] initWithRemote: DBUS_SVCHAL
                                                                         onBus: DKDBusSystemBus]];

    remote = (id <NSObject,HalDevice>)[c proxyAtPath: device];
    [remote setPrimaryDBusInterface: DBUS_IFDEVICE];
    NS_DURING
    {
      propList = [remote GetPropertyStringList: property];
    }
    NS_HANDLER
    {
	NSDebugLog(@"Exception %@ querying prop %@ for device %@. Reason:\n%@",
            [localException name], property, device, [localException reason]);
        propList = nil;
    }
    NS_ENDHANDLER

    [c invalidate];
    return [propList retain];
}

- (BOOL) getBooleanProperty: (NSString *) property
                  forDevice: (NSString *) device
{
    NSConnection *c;
    NSNumber *result;
    id <NSObject,HalDevice> remote;

    c = [NSConnection connectionWithReceivePort:[DKPort systemBusPort]
                                       sendPort:[[DKPort alloc] initWithRemote: DBUS_SVCHAL
                                                                         onBus: DKDBusSystemBus]];

    remote = (id <NSObject,HalDevice>)[c proxyAtPath: device];
    [remote setPrimaryDBusInterface: DBUS_IFDEVICE];
    NS_DURING
    {
      result = [remote GetPropertyBoolean: property];
    }
    NS_HANDLER
    {
	NSDebugLog(@"Exception %@ querying prop %@ for device %@. Reason:\n%@",
            [localException name], property, device, [localException reason]);
        result = [NSNumber numberWithBool: NO];
    }
    NS_ENDHANDLER

    [c invalidate];
    return [result boolValue];
}

- (NSString *) getStringProperty: (NSString *) property
                       forDevice: (NSString *) device
{
    NSConnection *c;
    NSString *result;
    id <NSObject,HalDevice> remote;

    c = [NSConnection connectionWithReceivePort:[DKPort systemBusPort]
                                       sendPort:[[DKPort alloc] initWithRemote: DBUS_SVCHAL
                                                                         onBus: DKDBusSystemBus]];

    remote = (id <NSObject,HalDevice>)[c proxyAtPath: device];
    [remote setPrimaryDBusInterface: DBUS_IFDEVICE];
    NS_DURING
    {
      result = [remote GetPropertyString: property];
    }
    NS_HANDLER
    {
	NSDebugLog(@"Exception %@ querying prop %@ for device %@. Reason:\n%@",
            [localException name], property, device, [localException reason]);
        result = nil;
    }
    NS_ENDHANDLER

    [c invalidate];
    return [result retain];
}

- (BOOL) propertyExists: (NSString *) property
              forDevice: (NSString *) device
{
    NSConnection *c;
    NSNumber *result;
    id <NSObject,HalDevice> remote;

    c = [NSConnection connectionWithReceivePort:[DKPort systemBusPort]
                                       sendPort:[[DKPort alloc] initWithRemote: DBUS_SVCHAL
                                                                         onBus: DKDBusSystemBus]];

    remote = (id <NSObject,HalDevice>)[c proxyAtPath: device];
    [remote setPrimaryDBusInterface: DBUS_IFDEVICE];
    NS_DURING
    {
      result = [remote PropertyExists: property];
    }
    NS_HANDLER
    {
	NSDebugLog(@"Exception %@ querying prop %@ for device %@. Reason:\n%@",
            [localException name], property, device, [localException reason]);
        result = [NSNumber numberWithBool: NO];
    }
    NS_ENDHANDLER

    [c invalidate];
    return [result boolValue];
}

- (NSArray *) findDevicesByCapability: (NSString *)capability
{
    NSConnection *c;
    NSArray *result;
    id <NSObject,HalDevice> remote;

    c = [NSConnection connectionWithReceivePort:[DKPort systemBusPort]
                                       sendPort:[[DKPort alloc] initWithRemote: DBUS_SVCHAL
                                                                         onBus: DKDBusSystemBus]];

    remote = (id <NSObject,HalDevice>)
                         [c proxyAtPath: HAL_MANAGER_PATH];
    [remote setPrimaryDBusInterface: DBUS_IFDEVICE];
    NS_DURING
    {
      result = [remote FindDeviceByCapability: capability];
    }
    NS_HANDLER
    {
	NSDebugLog(@"Exception %@ querying devices with capability %@. Reason:\n%@",
            [localException name], capability, [localException reason]);
        result = nil;
    }
    NS_ENDHANDLER

    [c invalidate];
    return result;
}


@end
