# Junkbot (PortMaster)

A native port of Junkbot, a LEGO puzzle-platformer, packaged for PortMaster.

Two binaries are bundled per architecture: one built against SDL3/SDL3_image/SDL3_mixer
(`ports/SDL3`) and one built against the older SDL2/SDL2_image/SDL2_mixer family
(`ports/SDL2`). `Junkbot.sh` detects at launch time which SDL3 libraries are actually
present on the device (present on newer firmwares like ROCKNIX; not yet on most others) and
picks the matching binary, falling back to the SDL2 build automatically - no separate port
submission needed per SDL version.

## Controls

- Left stick / D-pad: move cursor / navigate menus
- A: pick up or place a brick, activate the highlighted menu item
- Start: back out to the level-select screen (same as Escape)

## Building this port

This directory holds the PortMaster distribution templates (`port.json`, `gameinfo.xml`,
`Junkbot.sh`, `junkbot.gptk`), the `Dockerfile` defining the aarch64 Linux build
environment, and the `Makefile` that builds and assembles everything. With Docker
running, `make package` from here will:
1. Build the Docker image (Swift 6.3 on Ubuntu jammy; both SDL families built from
   source at pinned releases - devices supply their own SDL at runtime, the image only
   needs them for linking).
2. Cross-compile `ports/SDL3` and `ports/SDL2` in release mode for aarch64 Linux inside
   the container (native-speed on Apple Silicon; Linux build products go to a separate
   `.build-linux-aarch64` scratch dir so they never collide with host dev builds).
3. Assemble a ready-to-submit port folder at `.build-package/junkbot/` containing both
   release binaries (`junkbot3.aarch64`, `junkbot2.aarch64`), bundled assets, and these
   template files.

`make zip` additionally produces `.build-package/junkbot.zip` (the artifact named by
`port.json`). `make docker-build` runs just the cross-compile step.

CI also builds this on every push: the `portmaster` job in
`.github/workflows/swift.yml` runs `make zip` on GitHub's native arm64 runner
(`ubuntu-24.04-arm`) and uploads the archive as the `junkbot-portmaster-aarch64`
workflow artifact.

The binaries statically link the Swift runtime (`--static-swift-stdlib`) so no Swift
installation is needed on the device; glibc is still linked dynamically, hence
`min_glibc: 2.35` (jammy's) in `port.json`. Only aarch64 is packaged for now - an x86_64
release would need the same Docker build run on/for that platform.

## Credits

- Original Junkbot game: LEGO / Media Design Interactive.
- HTML5 remake this port is based on: Isaiah Odhner.
- This native Swift/SDL port: colemancda.

## TODO before submitting to PortMaster

- [ ] Add a `screenshot.png` (≥640×480, 4:3, real gameplay — not the title screen).
- [ ] Add a `cover.png` (used by `gameinfo.xml`).
- [ ] Add this project's own license: create a top-level LICENSE file in the repo and copy
      it to `licenses/junkbot.txt` (the SDL, PureSwift wrapper, and Swift runtime licenses
      are already in `licenses/`).
- [ ] Test the SDL3->SDL2 fallback logic in `Junkbot.sh` on both a device that has SDL3
      system-wide (e.g. ROCKNIX) and one that only has SDL2, to confirm the right binary gets
      picked on each - not verifiable in this dev environment.
- [ ] Test on real PortMaster-supported hardware/firmware before submitting a PR.
