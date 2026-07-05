# Start from the official libdragon toolchain image (mips64-elf GCC).
# The image ships only the compiler toolchain, so we build and install the
# libdragon library + n64.mk build system into $N64_INST.
FROM --platform=linux/amd64 ghcr.io/dragonminded/libdragon:latest

ARG LIBDRAGON_REF=trunk

RUN git clone --depth 1 --branch ${LIBDRAGON_REF} \
        https://github.com/DragonMinded/libdragon /libdragon

WORKDIR /libdragon
RUN make -j"$(nproc)" install && make tools-install

WORKDIR /workspace
