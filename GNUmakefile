
# Install into the system root by default
GNUSTEP_INSTALLATION_DOMAIN=LOCAL

include $(GNUSTEP_MAKEFILES)/common.make

# The application to be compiled
APP_NAME=VolumeManager

VolumeManager_APPLICATION_ICON=AppIcon.tiff

#
# Additional libraries
#
VolumeManager_GUI_LIBS = -lDBusKit -lTrayIconKit

#
# Resource files
#

VolumeManager_RESOURCE_FILES = \
	Images/*.tiff

VolumeManager_LANGUAGES = English German
VolumeManager_LOCALIZED_RESOURCE_FILES = \
	RemovableMedia.gorm \
	Localizable.strings

# The Objective-C source files to be compiled

VolumeManager_OBJC_FILES = main.m \
	ConnectionManager.m \
	ConnectionManager+VMSProtocol.m \
	VolumeManager.m \
	VolumeManager+Private.m \
	Volume.m \
	HalHandler.m \
	VolumeWindowController.m \
	VmIconController.m \
        Volume+Pmount.m

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make

-include GNUmakefile.postamble

