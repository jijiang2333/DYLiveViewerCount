TARGET = iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

SCHEME ?= rootless
ifeq ($(SCHEME),roothide)
export THEOS_PACKAGE_SCHEME = roothide
else ifeq ($(SCHEME),rootful)
unexport THEOS_PACKAGE_SCHEME
else ifeq ($(SCHEME),rootless)
export THEOS_PACKAGE_SCHEME = rootless
else
$(error Unknown SCHEME=$(SCHEME); use rootless, rootful, or roothide)
endif

export DEBUG = 0
INSTALL_TARGET_PROCESSES = Aweme

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DYLiveViewerCount

DYLiveViewerCount_FILES = Sources/Hooks/DYLVCHooks.xm \
	Sources/Core/DYLVCCore.m \
	Sources/UI/DYLVCBadgeView.m \
	Sources/UI/DYLVCModeControl.m \
	Sources/UI/DYLVCRefreshIntervalView.m \
	Sources/Settings/DYLVCSettings.m \
	Sources/Settings/DYLVCSettingsViewController.m

DYLiveViewerCount_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations \
	-ISources/Core \
	-ISources/UI \
	-ISources/Settings
DYLiveViewerCount_FRAMEWORKS = UIKit Foundation QuartzCore
DYLiveViewerCount_LDFLAGS = -lobjc

include $(THEOS_MAKE_PATH)/tweak.mk
