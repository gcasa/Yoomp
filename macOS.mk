YOOMP_MACOS = 1

CC = clang
CFLAGS ?= -O2
APP = Yoomp.app
BINARY = $(APP)/Contents/MacOS/Yoomp
RESOURCES = $(addprefix $(APP)/Contents/Resources/,Tunnel.wav Yoomp.icns)

.PHONY: all clean
all: $(BINARY) $(APP)/Contents/Info.plist $(RESOURCES)

$(BINARY): Source/Yoomp.m Source/Game.c Source/Game.h macOS.mk
	mkdir -p $(APP)/Contents/MacOS
	$(CC) $(CPPFLAGS) $(CFLAGS) -std=gnu89 -Wall -Wextra -fno-objc-arc \
	  -Wno-deprecated-declarations Source/Yoomp.m Source/Game.c \
	  $(LDFLAGS) -framework Cocoa -o $@

$(APP)/Contents/Info.plist: Info.plist
	mkdir -p $(APP)/Contents
	cp $< $@

$(APP)/Contents/Resources/%: Resources/%
	mkdir -p $(APP)/Contents/Resources
	cp $< $@

clean:
	rm -rf $(APP)
