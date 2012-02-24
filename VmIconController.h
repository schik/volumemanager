/*
 *    VmIconController.h
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

#ifndef __VMICONCONTROLLER_H_INCLUDED
#define __VMICONCONTROLLER_H_INCLUDED

#include <AppKit/AppKit.h>
#include <VolumeWindowController.h>
#include <VolumeManagerProtocols.h>

#include <TrayIconKit/TrayIconKit.h>


@interface VmIconController: TrayIconController <VolumeManagerClientProtocol>
{
    id volumeManager;
    VolumeWindowController *volumeWindowController;
    TrayIconController *tic;
}

- (id) init;
- (void) setVolumeManager: (id)manager;

@end

#endif
