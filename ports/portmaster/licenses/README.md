# Licenses

PortMaster requires a license file here for every bundled dependency:

- `SDL2.txt`, `SDL3.txt`, `SDL2_image.txt`, `SDL3_image.txt`, `SDL2_mixer.txt`,
  `SDL3_mixer.txt` — the zlib licenses of the SDL libraries the two binaries link
  against (fetched from the libsdl-org release tags the port is built with).
- `PureSwift-SDL.txt` — MIT license of the PureSwift/SDL Swift wrapper statically
  compiled into both binaries.
- `swift-runtime.txt` — Apache 2.0 license of the Swift standard library/runtime,
  statically linked into both binaries via `--static-swift-stdlib`.
- `junkbot.txt` — TODO: this project's own license (add a top-level LICENSE file to the
  repo if it doesn't have one yet, and copy it here before submitting).
