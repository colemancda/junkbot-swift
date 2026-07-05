.PHONY: all clean serve codegen sdl3 sdl2 portmaster android

# Web (WASM) build - delegates to ports/Web, whose own Makefile does the actual
# `swift package ... js --product JunkbotWASM` build and copies the result to web/Package/
# (relative to repo root) so index.html's `./web/Package/index.js` import keeps working
# unchanged. Kept as `make all`/`make serve` here so existing muscle memory and local
# dev-server configs don't need to change.
all:
	$(MAKE) -C ports/Web all

serve:
	$(MAKE) -C ports/Web serve

clean:
	$(MAKE) -C ports/Web clean

codegen:
	python3 tools/generate_render_tables.py
	swift run -c release --package-path tools/LevelDump LevelDump . Sources/JunkbotCore/Generated

# SDL3 dev build - delegates to ports/SDL3.
sdl3:
	$(MAKE) -C ports/SDL3 build

# SDL2 dev build - delegates to ports/SDL2.
sdl2:
	$(MAKE) -C ports/SDL2 build

# Portmaster package (both SDL3 and SDL2 binaries) - delegates to ports/portmaster.
portmaster:
	$(MAKE) -C ports/portmaster package

# Android debug APK - delegates to ports/Android. First run needs `make -C ports/Android vendor`
# once to download the SDL3 Android prebuilts (see ports/Android/README.md).
android:
	$(MAKE) -C ports/Android apk
