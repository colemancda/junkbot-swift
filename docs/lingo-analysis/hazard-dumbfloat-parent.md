# parent_hazard dumbfloat parent.ls — Flybot (dumb floater)

**Swift counterpart:** `Simulation.swift` — `simulateFlybot` (594-612).

## What the Lingo does

Identical skeleton to the float parent minus all targeting: moves every 2 frames
(`pSpeed = 2`) in a fixed horizontal `pDir` (initial `#L`/`#r` state), advancing one cell
if `checkFitMiniFigHit` passes, else turning around. Playfield edges turn it. A minifig in
the way blocks it (strict fit) and takes `#damage: #floater`. Two-frame wing animation.

## Matched behavior in Swift

- Move every 2 ticks (`animationFrame % 2 == 0`). ✔ — same cadence, unlike
  gearbot/climbbot where the remake changed it.
- Straight-line horizontal flight ignoring gravity (flybots are excluded from
  `simulateGravity`, 70). ✔
- Blocked-by-Junkbot + hurt + turn (602-606). ✔
- Turn at any obstacle; level bounds act as the playfield edge. ✔
- 2-frame animation cycle (renderer uses `af % 2`). ✔

## Differences

None of consequence. The only nuance: Lingo damages the minifig and reverses in the same
step *without* moving (strict fit blocks); Swift does exactly the same (hurt, `facing *= -1`,
no move). ✔

## Verdict

Equivalent.
