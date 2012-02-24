/* HalHandler.h
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

#ifndef HalHandler_H
#define HalHandler_H

#include <Foundation/Foundation.h>
#include <DBusKit/DKNotificationCenter.h>

#define ALL_DEVICES @"ALL_DEVICES"

/**
 * <p><code>HalHandler</code> is a wrapper class around the HAL library.</p>
 *
 * <p>It receives events from the HAL service such as property modified
 * events or device added/removed events and if an appropriate selector
 * has been registered for such an event calls it.</p>
 */
@interface HalHandler: NSObject
{
    DKNotificationCenter *center;
    NSMutableDictionary *propertyModifiedHandlers;
    id deviceChangedHandler;
}

- (id) init;
- (void) dealloc;

- (NSArray *) findDevicesByCapability: (NSString *)capability;

- (BOOL) registerPropertyModifiedHandler: (id)handler
                               forDevice: (NSString *)device;
- (void) unregisterPropertyModifiedHandler: (id)handler
                                 forDevice: (NSString *)device;

- (BOOL) registerDeviceChangedHandler: (id)handler;
- (void) unregisterDeviceChangedHandler: (id)handler;

- (NSArray *) getStrlistProperty: (NSString *) property
                       forDevice: (NSString *) device;
- (BOOL) getBooleanProperty: (NSString *) property
                  forDevice: (NSString *) device;
- (NSString *) getStringProperty: (NSString *) property
                       forDevice: (NSString *) device;
- (BOOL) propertyExists: (NSString *) property
              forDevice: (NSString *) device;

@end


/*@interface HalNotificationData: NSObject
{
@public
    LibHalContext *context;
    const char *udi;
    const char *key;
}

- (id) init;

@end
*/

#endif
