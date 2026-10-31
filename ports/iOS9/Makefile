# ports/iOS9 -- Junkbot for iOS 9 / armv7 (iPhone 4S era devices), built with
# Embedded Swift.
#
#   make           build build/Junkbot.app
#   make install   copy it to a jailbroken device over SSH
#   make ipa       package it as build/Junkbot.ipa
#   make sdk       unpack the iOS 9.3 SDK from SDK_ARCHIVE
#
# The game is JunkbotCore plus the Darwin port's SpriteKit renderer, scene,
# menus and game shell (../Darwin/JunkbotMobile.swiftpm/Sources/JunkbotMobile),
# compiled unchanged for the bare-metal armv7-apple-none-macho target. Embedded
# Swift can't import Apple's frameworks, so Sources/Foundation, Sources/UIKit
# and Sources/SpriteKit provide just the API those files use, implemented over
# the real iOS 9 frameworks by the Objective-C Backend/.
#
# Prerequisites:
#   - A swift.org toolchain with the armv7-apple-none-macho Embedded stdlib
#     (6.4.2 or later; set SWIFT_TOOLCHAIN).
#   - The iOS 9.3 SDK, since current SDKs no longer link armv7: put
#     iPhoneOS9.3.sdk.tar.xz at SDK_ARCHIVE and run `make sdk`, or set SDK.
#   - A development signing identity (SIGN_IDENTITY, TEAM_ID); AppSync on the
#     device accepts it without a provisioning profile.

APP     := Junkbot
BUNDLE  := build/$(APP).app
MIN_IOS := 9.0
ARCH    := armv7

REPO_ROOT := ../..
DARWIN    := ../Darwin/JunkbotMobile.swiftpm/Sources
SHARED    := $(DARWIN)/JunkbotMobile

SDK         ?= sdk/iPhoneOS9.3.sdk
SDK_ARCHIVE ?= iPhoneOS9.3.sdk.tar.xz

SWIFT_TOOLCHAIN ?= $(HOME)/Library/Developer/Toolchains/swift-6.4.2-RELEASE.xctoolchain
SWIFTC := $(SWIFT_TOOLCHAIN)/usr/bin/swiftc
SWIFT_EMBEDDED_LIB := $(SWIFT_TOOLCHAIN)/usr/lib/swift/embedded/armv7-apple-none-macho
CC     := xcrun clang

# iOS clobbers r9, which the bare-metal ABI treats as callee-saved, so Swift
# code leaves it alone; everything is ARM (not Thumb) code.
CFLAGS := -arch $(ARCH) -isysroot $(SDK) -miphoneos-version-min=$(MIN_IOS) \
          -marm -fobjc-arc -O2 -Wall -IBackend/include
LDFLAGS := -arch $(ARCH) -isysroot $(SDK) -miphoneos-version-min=$(MIN_IOS) \
           -framework UIKit -framework SpriteKit -framework AVFoundation -framework GameController \
           -framework CoreGraphics -framework Foundation \
           -Wl,-dead_strip $(SWIFT_EMBEDDED_LIB)/libswiftUnicodeDataTables.a
SWIFTFLAGS := -target armv7-apple-none-macho -enable-experimental-feature Embedded \
              -wmo -Osize -Xcc -marm -Xcc -ffixed-r9 -parse-as-library \
              -IBackend/include -Ibuild/modules

CORE_SRCS = $(shell find $(DARWIN)/JunkbotCore -name '*.swift')
# The Darwin port's game files, shared with the SDL ports; GamepadInput.swift,
# Audio.swift and the app/view controller are replaced by Sources/Junkbot.
SHARED_SRCS = $(addprefix $(SHARED)/,GameActor.swift GameInput.swift GameRender.swift \
              GameScene.swift GameShell.swift MenuFocus.swift Screens.swift \
              SpriteKitRenderer.swift TextRenderer.swift)
APP_SRCS = $(wildcard Sources/Junkbot/*.swift) $(SHARED_SRCS)

OBJS := build/obj/$(APP).o build/obj/JunkbotCore.o build/obj/SpriteKit.o build/obj/UIKit.o \
        build/obj/Foundation.o build/obj/Backend.o

# Bundled the way the Darwin port bundles them: the art, the font and the
# audio transcoded to .caf. Levels are compiled into JunkbotCore.
RESOURCES := images/backgrounds images/sprites images/menus images/cursors font/font.png TranscodedAudio

SIGN_IDENTITY ?= Apple Development
TEAM_ID       ?= 4W79SG34MW
BUNDLE_ID      = $(shell plutil -extract CFBundleIdentifier raw Info.plist)

SSH_CONF ?= $(HOME)/.ssh/config
SSH_HOST ?= iphone

.PHONY: all install ipa sdk clean
.DEFAULT_GOAL := all

all: $(BUNDLE)/$(APP)

# Each Swift rule also writes build/modules/<Module>.swiftmodule.
build/obj/Foundation.o: $(wildcard Sources/Foundation/*.swift) Backend/include/JunkbotBackend.h
	@mkdir -p build/obj build/modules
	$(SWIFTC) $(SWIFTFLAGS) -module-name Foundation \
	  -emit-module -emit-module-path build/modules/Foundation.swiftmodule -c $(wildcard Sources/Foundation/*.swift) -o $@

build/obj/UIKit.o: $(wildcard Sources/UIKit/*.swift) build/obj/Foundation.o
	$(SWIFTC) $(SWIFTFLAGS) -module-name UIKit \
	  -emit-module -emit-module-path build/modules/UIKit.swiftmodule -c $(wildcard Sources/UIKit/*.swift) -o $@

build/obj/SpriteKit.o: $(wildcard Sources/SpriteKit/*.swift) build/obj/UIKit.o
	$(SWIFTC) $(SWIFTFLAGS) -module-name SpriteKit \
	  -emit-module -emit-module-path build/modules/SpriteKit.swiftmodule -c $(wildcard Sources/SpriteKit/*.swift) -o $@

# Without build/modules, since JunkbotCore uses Foundation if it can import it,
# and the stand-in here doesn't have what it's looking for. The shared menus
# need EmbeddedLevelCatalog, which Embedded builds leave out unless asked.
build/obj/JunkbotCore.o: $(CORE_SRCS)
	@mkdir -p build/obj build/modules
	$(SWIFTC) $(filter-out -Ibuild/modules,$(SWIFTFLAGS)) -D EMBEDDED_LEVEL_CATALOG -module-name JunkbotCore \
	  -emit-module -emit-module-path build/modules/JunkbotCore.swiftmodule -c $(CORE_SRCS) -o $@

# The shared files name the main actor without importing anything, so the
# stand-in in UIKit is imported implicitly.
build/obj/$(APP).o: $(APP_SRCS) build/obj/SpriteKit.o build/obj/JunkbotCore.o
	$(SWIFTC) $(SWIFTFLAGS) -Xfrontend -import-module -Xfrontend UIKit \
	  -module-name $(APP) -c $(APP_SRCS) -o $@

build/obj/Backend.o: Backend/Backend.m Backend/include/JunkbotBackend.h
	@mkdir -p build/obj
	$(CC) $(CFLAGS) -c $< -o $@

# The linker warns "no platform load command found" for the Swift objects
# (bare-metal target) and assumes iOS, which is what we want.
$(BUNDLE)/$(APP): $(OBJS) Info.plist
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)
	$(CC) $(LDFLAGS) $(OBJS) -o $@
	plutil -convert binary1 -o $(BUNDLE)/Info.plist Info.plist
	printf 'APPL????' > $(BUNDLE)/PkgInfo
	for resource in $(RESOURCES); do \
	  mkdir -p $(BUNDLE)/$$(dirname $$resource) && cp -R $(SHARED)/$$resource $(BUNDLE)/$$(dirname $$resource)/; \
	done
	printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict><key>application-identifier</key><string>%s.%s</string><key>com.apple.developer.team-identifier</key><string>%s</string></dict></plist>\n' \
	  $(TEAM_ID) $(BUNDLE_ID) $(TEAM_ID) > build/$(APP).entitlements
	codesign -f -s "$(SIGN_IDENTITY)" --entitlements build/$(APP).entitlements $(BUNDLE)

ipa: build/$(APP).ipa

build/$(APP).ipa: $(BUNDLE)/$(APP)
	rm -rf build/ipa $@
	mkdir -p build/ipa/Payload
	cp -R $(BUNDLE) build/ipa/Payload/
	cd build/ipa && COPYFILE_DISABLE=1 zip -qry ../$(APP).ipa Payload
	rm -rf build/ipa

# Copies the app into /Applications and refreshes the home screen.
install: $(BUNDLE)/$(APP)
	COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -C build -cf - $(APP).app | \
	  ssh -F $(SSH_CONF) $(SSH_HOST) 'cd / && rm -rf /Applications/$(APP).app && tar -C /Applications -xf - && chown -R root:wheel /Applications/$(APP).app && su mobile -c uicache'

# The 9.3 SDK's .tbd stubs list Intel slices current linkers reject, and its
# libsystem_platform doesn't export the memory functions the Embedded stdlib
# calls.
sdk:
	rm -rf $(SDK) && mkdir -p $(dir $(SDK))
	tar -xJf $(SDK_ARCHIVE) -C $(dir $(SDK))
	find $(SDK) -name '*.tbd' -type f -print0 | xargs -0 sed -i '' -E \
	  's/(archs: *\[ armv7, armv7s, arm64), i386, x86_64 \]/\1 ]/'
	perl -0pi -e 's/(symbols: *\[ )/$$1_bzero, _memcmp, _memcpy, _memmove, _memset, /' \
	  $(SDK)/usr/lib/system/libsystem_platform.tbd

clean:
	rm -rf build
