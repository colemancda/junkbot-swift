.PHONY: build clean

# Overridable by callers (e.g. ports/portmaster/Makefile passes
# SWIFT_BUILD_FLAGS=--static-swift-stdlib, so the packaged handheld binary doesn't depend on a
# system-installed Swift runtime) - empty by default for ordinary dev builds.
SWIFT_BUILD_FLAGS ?=

build:
	swift build --product JunkbotSDL2 -c release $(SWIFT_BUILD_FLAGS)

clean:
	rm -rf .build
