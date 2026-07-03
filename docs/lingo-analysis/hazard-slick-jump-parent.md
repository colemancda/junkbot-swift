# parent_hazard slick jump parent.ls — Jump brick

**Swift counterpart:** `Simulation.swift` — `simulateJump` (763-769) and the two jump
triggers in `simulateJunkbot` (ground case 426-432, mid-air re-trigger 335-354).

## What the Lingo does

Every frame (unless paused by a switch — `notify(#stop/#Start)`): probe the two cells above
(`point(0,-1)` and `point(1,-1)`, 1-cell probes); if **both return the same minifig**
(i.e. the minifig is aligned squarely on top) and at least **60 ticks (1s wall-clock)**
have passed since the last launch, play `jump3`, `notify([#jump: part])` (starting the
minifig's fixed jump trajectory), and enter `#Active` for a 4-frame launch animation.
Otherwise the active animation plays out back to `#dormant`.

## Matched behavior in Swift

- Requires full alignment: Lingo's "both probes return the same minifig" == Swift's
  `jb.x <= junkbot.x && jb.x + jb.width >= junkbot.x + junkbot.width` (339). ✔
- Launch sound + launch animation + inert period while animating. ✔
- Switch-pausable: Lingo `#stop`/`#Start`; Swift jump bricks toggle `on` via the shared
  switch wiring. ✔ (Lingo also resets state to `#dormant` on resume; Swift equivalent
  via `active = false`.)

## Differences

1. **[divergence] Cooldown model.** Lingo: hard 60-tick (1s) cooldown independent of the
   animation (`last_jump`). Swift: the brick is refractory only while `active`, i.e. its
   **5-tick** launch animation (`animationFrame >= 5` → `active = false`, ~0.28s). Swift
   jump bricks re-arm ~3.6× sooner. Combined with Swift's momentum ballistics (a landing
   junkbot can immediately re-trigger, 335-354 even applies mid-air when falling onto it),
   rapid bounce chains are possible in Swift that the original's 1s lockout prevented.
2. **[inherited] Launch effect.** Lingo starts the fixed 7-step trajectory; Swift sets
   `momentumY = -3, momentumX = facing * 5` (see
   [minifig-walk-parent.md](minifig-walk-parent.md) item 1).
3. **[architectural] Trigger direction.** Fire-style inversion: Lingo's brick detects the
   minifig; Swift's junkbot detects the brick underfoot (walk-frame ground scan + the
   airborne landing check). The airborne check (335-354) means Swift can trigger on the
   tick of landing rather than the next walk frame — closer to Lingo's every-frame probe
   than the fire case is.

## Verdict

Same trigger geometry; the cooldown semantics differ meaningfully (1s in the original vs
animation-length in Swift) — noticeable in levels with repeated bounce use.
