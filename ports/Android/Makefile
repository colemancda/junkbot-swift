# Android build. End to end:
#
#   make vendor    # once: download SDL3/SDL3_image/SDL3_mixer Android prebuilts into Vendor/
#   make apk       # cross-compile Swift -> stage native libs -> gradle assembleDebug
#   make install   # adb install + launch on the connected device/emulator
#
# Prereqs: the Swift Android SDK (swift sdk list should show *_android), an Android NDK (r27+)
# under ~/Library/Android/sdk/ndk (the ndk-sysroot link is set up automatically), and an Android
# SDK + JDK for the Gradle step.

REPO_ROOT := ../..

# arm64-v8a (default) or x86_64 (Intel-hosted emulators).
ABI ?= arm64-v8a
ifeq ($(ABI),arm64-v8a)
SWIFT_ARCH := aarch64
else ifeq ($(ABI),x86_64)
SWIFT_ARCH := x86_64
else
$(error unsupported ABI '$(ABI)' - use arm64-v8a or x86_64)
endif
API_LEVEL ?= 28
TRIPLE    := $(SWIFT_ARCH)-unknown-linux-android$(API_LEVEL)

VENDOR     := $(CURDIR)/Vendor
SDK_BUNDLE := $(wildcard $(HOME)/Library/org.swift.swiftpm/swift-sdks/swift-*-RELEASE_android.artifactbundle/swift-android)
NDK_HOME   ?= $(lastword $(sort $(wildcard $(HOME)/Library/Android/sdk/ndk/*)))

.PHONY: vendor sysroot build jnilibs apk install clean

vendor:
	scripts/fetch-sdl.sh

# The Swift Android SDK ships without NDK headers/libs; its setup script links them in from a
# locally installed NDK (idempotent, re-run only when ndk-sysroot is missing).
sysroot:
	@if [ ! -d "$(SDK_BUNDLE)/ndk-sysroot" ]; then \
		ANDROID_NDK_HOME="$(NDK_HOME)" "$(SDK_BUNDLE)/scripts/setup-android-sdk.sh"; \
	fi

# PKG_CONFIG_PATH + the explicit -Xcc/-Xlinker flags both point at Vendor/ so PureSwift/SDL's
# CSDL3* system-library targets resolve to the Android prebuilts (never Homebrew's macOS ones).
build: sysroot
	PKG_CONFIG_PATH=$(VENDOR)/lib/$(ABI)/pkgconfig \
	swift build --swift-sdk $(TRIPLE) --product JunkbotAndroid -c release \
		-Xcc -I$(VENDOR)/include -Xlinker -L$(VENDOR)/lib/$(ABI)

jnilibs: build
	scripts/stage-jnilibs.sh $(ABI) $(TRIPLE) $(SWIFT_ARCH)

# Prefer Android Studio's bundled JDK for Gradle: AGP's jlink-based android.jar transform
# chokes on very new JDKs (e.g. Homebrew's OpenJDK 26).
JBR := /Applications/Android Studio.app/Contents/jbr/Contents/Home
apk: jnilibs
	ANDROID_HOME=$${ANDROID_HOME:-$(HOME)/Library/Android/sdk} \
	JAVA_HOME="$$( [ -d '$(JBR)' ] && echo '$(JBR)' || echo "$$JAVA_HOME" )" \
	gradle -p AndroidApp :app:assembleDebug
	@echo "✓ APK at AndroidApp/app/build/outputs/apk/debug/app-debug.apk"

install: apk
	adb install -r AndroidApp/app/build/outputs/apk/debug/app-debug.apk
	adb shell am start -n org.junkbot.game/.MainActivity

clean:
	rm -rf .build AndroidApp/app/build AndroidApp/.gradle AndroidApp/app/src/main/jniLibs
