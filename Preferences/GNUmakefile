include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = VolumeManager

BUNDLE_EXTENSION = .prefPane


ifeq ($(findstring darwin, $(GNUSTEP_TARGET_OS)), darwin)
  ADDITIONAL_GUI_LIBS += -lGSPreferencePanes
else
  ADDITIONAL_GUI_LIBS += -lPreferencePanes
endif

#ADDITIONAL_CPPFLAGS += -DSYSPREFS=1

VolumeManager_HAS_RESOURCE_BUNDLE = yes

VolumeManager_LANGUAGES = English German

VolumeManager_LOCALIZED_RESOURCE_FILES = \
	VolumeManager.gorm

VolumeManager_RESOURCE_FILES = \
	Images/VolumeManager.tiff \
	VolumeManagerInfo.plist


VolumeManager_OBJC_FILES = VolumeManager.m

VolumeManager_HEADERS = VolumeManager.h

VolumeManager_PRINCIPAL_CLASS= VolumeManager

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.preamble
-include GNUmakefile.postamble
