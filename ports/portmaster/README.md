# Junkbot (PortMaster)

A native SDL3 port of Junkbot, a LEGO puzzle-platformer.

## Controls

- Left stick / D-pad: move cursor / navigate menus
- A: pick up or place a brick, activate the highlighted menu item
- Start: back out to the level-select screen (same as Escape)

## Building this port

This directory (`ports/Linux/packaging/`) holds the PortMaster distribution templates
(`port.json`, `gameinfo.xml`, `Junkbot.sh`, `junkbot.gptk`). Run `make package` from
`ports/Linux/` to assemble a ready-to-submit port folder at `ports/Linux/.build-package/junkbot/`
containing the release binary, bundled assets, and these template files.

## Credits

- Original Junkbot game: LEGO / Media Design Interactive.
- HTML5 remake this port is based on: Isaiah Odhner.
- This native Swift/SDL3 port: TODO — your name/handle.

## TODO before submitting to PortMaster

- [ ] Fill in `porter` in `port.json` and this README's credits section.
- [ ] Add a `screenshot.png` (≥640×480, 4:3, real gameplay — not the title screen).
- [ ] Add a `cover.png` (used by `gameinfo.xml`).
- [ ] Fill in `licenses/` with the license text for every bundled dependency (SDL3, SDL3_image,
      SDL3_mixer, swift-lingo, and this project's own license) — required by PortMaster's
      packaging guidelines and not something this scaffold can fill in for you.
- [ ] Test on real PortMaster-supported hardware/firmware before submitting a PR.
