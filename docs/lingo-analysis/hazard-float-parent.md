# parent_hazard float parent.ls — Eyebot (targeting floater)

**Swift counterpart:** `Simulation.swift` — `doEyebotTargeting` (620-644),
`doEyebotMovement` (649-672).

## What the Lingo does

Moves every 2 frames (`pSpeed = 2`). Each move: advance one cell in `pDir` (any of the 4
axis directions) if it fits (`checkFitMiniFigHit` — minifigs block and get damaged
`#damage: #floater`), else mark `#TURN` and reverse. Playfield edges also turn it.

Then it **scans all four axis directions from its current cell to the playfield edge**
(four `repeat` loops over `getPart`): empty cells are skipped (see-through), the first
non-minifig part blocks the scan in that direction, and if a **minifig** is seen first, the
eyebot locks on: `pTarget = 1`, `pTimer = the timer`, `pDir` set toward the minifig, siren
sound, and any pending turn is cancelled. Target lock expires after 120 ticks (2s) without
re-sighting. `pTarget` only affects the sprite state (`#Active` vs `#inactive`) and the
direction snap — **speed is constant** either way.

## Matched behavior in Swift

- 4-direction line-of-sight scan blocked by the first solid thing, locking direction toward
  a sighted Junkbot with a siren-adjacent "active" state. ✔ (`raycast` with
  `maxSteps: 50`, two parallel rays per direction to cover the eyebot's 2-cell cross
  section — geometrically equivalent to Lingo scanning from its own occupied cells.)
- Turn at obstacles; Junkbot blocks movement and is hurt on contact. ✔
- Targeting runs as a separate pass after movement (Swift 920-922), matching Lingo's
  scan-after-move ordering inside one step. ✔

## Differences

1. **[divergence] Speed while active.** Lingo eyebots always move every 2 frames; Swift
   moves **every tick** while `activeTimer > 0` and every 2 otherwise (653). Swift's
   eyebots are twice as fast when hunting — a JS-remake gameplay change (Undercover-era
   behavior), not in this Lingo file.
2. **[inherited] Lock duration.** Lingo: re-sight window of 120 wall-ticks = 2s. Swift:
   `activeTimer = 110` sim ticks at 18/s ≈ 6s. Swift eyebots stay agitated ~3× longer.
3. **[architectural] Scan range.** Lingo scans to the playfield edge; Swift raycasts
   `maxSteps: 50` cells — longer than any real level, effectively equal.
4. **[architectural] Diagonals.** Both restrict to the 4 axes; Lingo's `pDir` and Swift's
   `facing`/`facingY` pairs are equivalent encodings.

## Verdict

Same sensing model; the JS remake deliberately made hunting eyebots faster and more
persistent, and Swift inherits that. If original-fidelity ever matters, items 1-2 are the
knobs.
