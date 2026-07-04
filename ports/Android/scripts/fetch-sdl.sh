#!/usr/bin/env bash
# Downloads the official libsdl-org Android release archives (the *-devel-*-android.zip assets,
# each containing a prebuilt .aar) and lays their pieces out under ports/Android/Vendor/ the way
# Package.swift/Makefile/the Gradle app expect:
#
#   Vendor/include/SDL3/…, SDL3_image/…, SDL3_mixer/…   merged C headers
#   Vendor/lib/<abi>/libSDL3*.so                        prebuilt shared libraries per ABI
#   Vendor/lib/<abi>/pkgconfig/sdl3*.pc                 generated so SwiftPM's pkg-config lookup
#                                                       (PureSwift/SDL's CSDL3* system-library
#                                                       targets) resolves to these Android copies
#                                                       instead of Homebrew's macOS ones
#   Vendor/java/SDL3-android.jar                        SDL's Java glue (SDLActivity & friends)
#   Vendor/licenses/                                    upstream license texts
#
# Versions intentionally match what the desktop build uses via Homebrew (see ports/SDL3).
set -euo pipefail

SDL3_VERSION=3.4.12
IMAGE_VERSION=3.4.4
MIXER_VERSION=3.2.4
ABIS=(arm64-v8a x86_64)

cd "$(dirname "$0")/.."
VENDOR="$PWD/Vendor"
DOWNLOADS="$VENDOR/downloads"
mkdir -p "$DOWNLOADS"

fetch() { # url -> cached file path on stdout
  local url="$1" file="$DOWNLOADS/$(basename "$1")"
  [ -f "$file" ] || curl -fsSL -o "$file" "$url"
  echo "$file"
}

SDL3_ZIP=$(fetch "https://github.com/libsdl-org/SDL/releases/download/release-$SDL3_VERSION/SDL3-devel-$SDL3_VERSION-android.zip")
IMAGE_ZIP=$(fetch "https://github.com/libsdl-org/SDL_image/releases/download/release-$IMAGE_VERSION/SDL3_image-devel-$IMAGE_VERSION-android.zip")
MIXER_ZIP=$(fetch "https://github.com/libsdl-org/SDL_mixer/releases/download/release-$MIXER_VERSION/SDL3_mixer-devel-$MIXER_VERSION-android.zip")

rm -rf "$VENDOR/include" "$VENDOR/lib" "$VENDOR/java" "$VENDOR/licenses" "$VENDOR/.extract"
mkdir -p "$VENDOR/include" "$VENDOR/java" "$VENDOR/licenses" "$VENDOR/.extract"

extract_aar() { # zip name -> extracted aar dir on stdout
  local zip="$1" name="$2"
  local dir="$VENDOR/.extract/$name"
  mkdir -p "$dir"
  unzip -oq "$zip" -d "$dir"
  local aar
  aar=$(ls "$dir"/*.aar)
  mkdir -p "$dir/aar"
  unzip -oq "$aar" -d "$dir/aar"
  cp "$dir/LICENSE.txt" "$VENDOR/licenses/$name-LICENSE.txt"
  echo "$dir/aar"
}

SDL3_AAR=$(extract_aar "$SDL3_ZIP" SDL3)
IMAGE_AAR=$(extract_aar "$IMAGE_ZIP" SDL3_image)
MIXER_AAR=$(extract_aar "$MIXER_ZIP" SDL3_mixer)

cp -R "$SDL3_AAR/prefab/modules/SDL3-Headers/include/SDL3" "$VENDOR/include/SDL3"
cp -R "$IMAGE_AAR/prefab/modules/SDL3_image-shared/include/SDL3_image" "$VENDOR/include/SDL3_image"
cp -R "$MIXER_AAR/prefab/modules/SDL3_mixer-shared/include/SDL3_mixer" "$VENDOR/include/SDL3_mixer"
cp "$SDL3_AAR/classes.jar" "$VENDOR/java/SDL3-android.jar"

write_pc() { # abi name libname version
  local abi="$1" name="$2" libname="$3" version="$4"
  cat > "$VENDOR/lib/$abi/pkgconfig/$name.pc" <<EOF
prefix=$VENDOR
includedir=\${prefix}/include
libdir=\${prefix}/lib/$abi

Name: $name
Description: $libname prebuilt for Android ($abi)
Version: $version
Cflags: -I\${includedir}
Libs: -L\${libdir} -l$libname
EOF
}

for abi in "${ABIS[@]}"; do
  mkdir -p "$VENDOR/lib/$abi/pkgconfig"
  cp "$SDL3_AAR/prefab/modules/SDL3-shared/libs/android.$abi/libSDL3.so" "$VENDOR/lib/$abi/"
  cp "$IMAGE_AAR/prefab/modules/SDL3_image-shared/libs/android.$abi/libSDL3_image.so" "$VENDOR/lib/$abi/"
  cp "$MIXER_AAR/prefab/modules/SDL3_mixer-shared/libs/android.$abi/libSDL3_mixer.so" "$VENDOR/lib/$abi/"
  write_pc "$abi" sdl3 SDL3 "$SDL3_VERSION"
  write_pc "$abi" sdl3-image SDL3_image "$IMAGE_VERSION"
  write_pc "$abi" sdl3-mixer SDL3_mixer "$MIXER_VERSION"
done

rm -rf "$VENDOR/.extract"
echo "✓ SDL3 $SDL3_VERSION / SDL3_image $IMAGE_VERSION / SDL3_mixer $MIXER_VERSION vendored for: ${ABIS[*]}"
