ifeq ($(shell uname -s),Darwin)
  ifneq ($(GNUSTEP),1)
    include macOS.mk
  endif
endif

ifeq ($(YOOMP_MACOS),)
GNUSTEP_MAKEFILES ?= $(shell gnustep-config --variable=GNUSTEP_MAKEFILES)
ifeq ($(GNUSTEP_MAKEFILES),)
$(error GNUstep Make is required. Source GNUstep.sh or put gnustep-config on PATH)
endif

include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = Yoomp
Yoomp_OBJC_FILES = Source/Yoomp.m
Yoomp_C_FILES = Source/Game.c
Yoomp_RESOURCE_FILES = Resources/Tunnel.wav Resources/Yoomp.png
Yoomp_APPLICATION_ICON = Yoomp.png
ADDITIONAL_OBJCFLAGS = -std=gnu89 -Wall -Wextra
ADDITIONAL_CFLAGS = -std=gnu89 -Wall -Wextra
ADDITIONAL_GUI_LIBS = -lm

include $(GNUSTEP_MAKEFILES)/application.make
endif
