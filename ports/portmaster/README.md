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
`Junkbot.sh`, `junkbot.gptk`) and the `Makefile` that builds and assembles them. Run
`make package` from here to:
1. Build `ports/SDL3` and `ports/SDL2` in release mode.
2. Assemble a ready-to-submit port folder at `.build-package/junkbot/` containing both release
   binaries (`junkbot3.<arch>`, `junkbot2.<arch>`), bundled assets, and these template files.

Note: this only packages binaries for the CURRENT host architecture (a dev machine, not a
cross-compilation setup) - for a real aarch64/x86_64 Linux release, build on/for the target arch
first, then re-run `make package`.

## Credits

- Original Junkbot game: LEGO / Media Design Interactive.
- HTML5 remake this port is based on: Isaiah Odhner.
- This native Swift/SDL port: TODO — your name/handle.

## TODO before submitting to PortMaster

- [ ] Fill in `porter` in `port.json` and this README's credits section.
- [ ] Add a `screenshot.png` (≥640×480, 4:3, real gameplay — not the title screen).
- [ ] Add a `cover.png` (used by `gameinfo.xml`).
- [ ] Fill in `licenses/` with the license text for every bundled dependency (SDL2, SDL3,
      SDL2_image, SDL3_image, SDL2_mixer, SDL3_mixer, swift-lingo, and this project's own
      license) — required by PortMaster's packaging guidelines and not something this scaffold
      can fill in for you.
- [ ] Test the SDL3->SDL2 fallback logic in `Junkbot.sh` on both a device that has SDL3
      system-wide (e.g. ROCKNIX) and one that only has SDL2, to confirm the right binary gets
      picked on each - not verifiable in this dev environment.
- [ ] Test on real PortMaster-supported hardware/firmware before submitting a PR.
