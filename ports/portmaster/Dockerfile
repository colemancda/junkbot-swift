# Build environment for the PortMaster aarch64 Linux binaries (see Makefile's
# `docker-build` target, which mounts the repo into this image and runs swift build).
#
# jammy (Ubuntu 22.04, glibc 2.35) rather than a newer base so the produced binaries run
# on the older glibc found on most PortMaster device firmwares; port.json's min_glibc
# must stay in sync with this choice.
#
# The devices supply their own SDL shared libraries at runtime (Junkbot.sh picks the
# SDL3 or SDL2 binary based on what's present on the device), so the SDL builds here
# only need to provide link-time headers/stubs with the right ABI - no video drivers or
# audio codecs are required in this image. Both SDL families are built from source at
# pinned releases: the SDL3 family isn't packaged for jammy at all, and jammy's apt
# SDL2_mixer (2.0.4) is too old for the PureSwift/SDL wrapper - it defines
# Mix_LoadWAV/Mix_PlayChannel as function-like C macros (unimportable from Swift);
# they only became real functions in SDL2_mixer 2.6.
FROM swift:6.3-jammy

# The X11 dev headers make SDL's CMake build the X11 video backend; without any video
# backend SDL3's configure hard-fails. libxtst-dev is required (not optional) once the
# other X11 headers are present - SDL3 auto-enables X11 and then errors on missing XTest.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake ninja-build git ca-certificates pkg-config \
      libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxfixes-dev \
      libxi-dev libxss-dev libxtst-dev \
    && rm -rf /var/lib/apt/lists/*

ARG SDL2_VERSION=2.32.8
ARG SDL2_IMAGE_VERSION=2.8.8
ARG SDL2_MIXER_VERSION=2.8.1
ARG SDL3_VERSION=3.4.12
ARG SDL3_IMAGE_VERSION=3.4.4
ARG SDL3_MIXER_VERSION=3.2.4

RUN git clone --depth 1 --branch "release-${SDL2_VERSION}" \
      https://github.com/libsdl-org/SDL /tmp/SDL2 \
    && cmake -S /tmp/SDL2 -B /tmp/SDL2/build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /tmp/SDL2/build \
    && cmake --install /tmp/SDL2/build \
    && rm -rf /tmp/SDL2 && ldconfig

RUN git clone --depth 1 --branch "release-${SDL2_IMAGE_VERSION}" \
      https://github.com/libsdl-org/SDL_image /tmp/SDL2_image \
    && cmake -S /tmp/SDL2_image -B /tmp/SDL2_image/build -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DSDL2IMAGE_SAMPLES=OFF -DSDL2IMAGE_TESTS=OFF \
    && cmake --build /tmp/SDL2_image/build \
    && cmake --install /tmp/SDL2_image/build \
    && rm -rf /tmp/SDL2_image && ldconfig

RUN git clone --depth 1 --branch "release-${SDL2_MIXER_VERSION}" \
      https://github.com/libsdl-org/SDL_mixer /tmp/SDL2_mixer \
    && cmake -S /tmp/SDL2_mixer -B /tmp/SDL2_mixer/build -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DSDL2MIXER_SAMPLES=OFF \
      -DSDL2MIXER_OPUS=OFF -DSDL2MIXER_FLAC=OFF -DSDL2MIXER_MOD=OFF \
      -DSDL2MIXER_MIDI=OFF -DSDL2MIXER_WAVPACK=OFF \
    && cmake --build /tmp/SDL2_mixer/build \
    && cmake --install /tmp/SDL2_mixer/build \
    && rm -rf /tmp/SDL2_mixer && ldconfig

RUN git clone --depth 1 --branch "release-${SDL3_VERSION}" \
      https://github.com/libsdl-org/SDL /tmp/SDL \
    && cmake -S /tmp/SDL -B /tmp/SDL/build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /tmp/SDL/build \
    && cmake --install /tmp/SDL/build \
    && rm -rf /tmp/SDL && ldconfig

RUN git clone --depth 1 --branch "release-${SDL3_IMAGE_VERSION}" \
      https://github.com/libsdl-org/SDL_image /tmp/SDL_image \
    && cmake -S /tmp/SDL_image -B /tmp/SDL_image/build -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DSDLIMAGE_SAMPLES=OFF -DSDLIMAGE_TESTS=OFF \
    && cmake --build /tmp/SDL_image/build \
    && cmake --install /tmp/SDL_image/build \
    && rm -rf /tmp/SDL_image && ldconfig

RUN git clone --depth 1 --branch "release-${SDL3_MIXER_VERSION}" \
      https://github.com/libsdl-org/SDL_mixer /tmp/SDL_mixer \
    && cmake -S /tmp/SDL_mixer -B /tmp/SDL_mixer/build -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DSDLMIXER_SAMPLES=OFF \
    && cmake --build /tmp/SDL_mixer/build \
    && cmake --install /tmp/SDL_mixer/build \
    && rm -rf /tmp/SDL_mixer && ldconfig

# The repo must be mounted at a path whose basename is `junkbot-swift`: the SDL2/SDL3
# port manifests reference the root package via `.package(path: "../..")`, and SwiftPM
# derives the package identity from the directory name - mounting at e.g. /workspace
# makes dependency resolution fail with "unknown package 'junkbot-swift'".
WORKDIR /junkbot-swift
