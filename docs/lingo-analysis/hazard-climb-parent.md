# parent_hazard climb parent.ls — Climbbot

**Swift counterpart:** `Simulation.swift` — `simulateClimbbot` (503-588).

## What the Lingo does

State machine over `part.state` ∈ {`#walk_l`, `#WALK_R`, `#FLOAT_UP`, `#FLOAT_DOWN`} with
`dir` as a point vector, `oldhoriz` remembering the last horizontal direction, `climbstart`
the y where the current climb began, and `climb_up = 3` limiting climb height. Steps on
frame 6 of a 6-frame animation cycle (**every 6 frames**). Uses `checkFitMiniFigHit`
everywhere: a minifig blocks movement *and* gets damaged (`robottouch4`,
`#damage: #climber`) at the end of any step in which it was touched.

- **Walking:** if no floor under it and the cell below is free → start `#FLOAT_DOWN`
  (remember `oldhoriz`). Else if blocked ahead → start `#FLOAT_UP` (reset `climbstart`).
  Else move forward.
- **FLOAT_UP:** if back at start height and can still move up… (first branch); else if it
  can resume horizontally in `oldhoriz` direction *with floor there* → do that; else try
  the opposite horizontal (with floor); else if it has climbed ≥ `climb_up` cells → flip to
  descending; else continue up if free, else flip to descending.
- **FLOAT_DOWN:** keep descending while free; else resume `oldhoriz` horizontal; else
  opposite horizontal; else flip to `#FLOAT_UP` (new `climbstart`).

## Matched behavior in Swift

Swift encodes the same machine with `facingY` (-1 up / 0 walk / +1 down), `facing`
(horizontal), and `energy` as the remaining climb budget (reset to 3 == `climb_up = 3`). ✔

- Climb height limit of 3 cells. ✔
- "Resume horizontal as soon as a floored cell to the side appears" while climbing
  (533-536 == Lingo FLOAT_UP second branch). ✔
- Descend when falling off an edge; resume horizontal on landing; reverse when boxed in. ✔
- Junkbot blocks movement and takes damage on contact (527-530). ✔

## Differences

1. **[inherited] Cadence.** Lingo steps every **6** frames; Swift every **7** ticks
   (`animationFrame > 6` → reset). ~17% slower relative to everything else.
2. **[divergence] Climb-resume direction preference.** Lingo, while climbing/descending,
   tries `oldhoriz` **then its opposite** — it can reverse horizontal direction mid-climb
   if only the far side has floor. Swift only tests the current `facing` side while
   ascending (`aside`/`groundAside`, 533) and handles reversal separately in the
   `facingY == 1` landing logic (547-561). On geometry where a climbbot climbs a wall whose
   *near* side never opens but *far* side does, Lingo switches direction mid-climb one step
   earlier than Swift's up-then-down-then-reverse path. Net path can differ by a few cells
   around complex overhangs.
3. **[divergence] Floor requirement when resuming from a climb.** Lingo requires
   `checkFloor(...) > 0` on the side cell before resuming horizontal travel; Swift's
   `groundAside` uses `isNotBinOrDroplet` — a **bin counts as blocking** the ground query
   differently, and enemy bots can count as ground for a climbbot in Swift but never in
   Lingo (`checkFloor` counts only bricks). Only matters when bots stack on bots.
4. **[architectural] Damage timing.** Lingo damages at most one minifig per step, *after*
   moving, via the `minifigHit` global; Swift damages before deciding movement. Same tick,
   same outcome.

## Verdict

Same state machine and climb budget; cadence inherited from JS; two subtle path-choice
divergences (items 2-3) possible on unusual wall geometry.
