# parent_hazard slick fire parent.ls — Fire

**Swift counterpart:** `Simulation.swift` — the `.fire where ground.on` case inside
`simulateJunkbot`'s ground-reaction switch (410-417); animation via the default
`animationFrame` increment (913-914) + renderer ping-pong.

## What the Lingo does

When `#on`: every frame, probe the 2-cell area directly **above** the fire
(`part.pos + point(1, -1)`, footprint `#BRICK_02`) with `checkFitOrMinifig`; if a minifig
is standing there, play `fire` and `notify([#damage: #fire])`. Switchable on/off via
`notify([#switch: state])`; 7-frame flame animation while on, frame 1 when off.

## Matched behavior in Swift

- Junkbot standing directly on a lit fire dies by fire (`hurtJunkbot(cause: 1)` ==
  `#damage: #fire` → the minifig's generic death). ✔
- Off fires are harmless and static. ✔ Switch-linkable (`switchID` toggling `on` in the
  junkbot `.switch` case == Lingo's `doSwitch` → `notify(#switch)`). ✔
- Shield protects (both routes go through the shield-absorb path). ✔

## Differences

1. **[architectural] Inverted responsibility + probe geometry.** Lingo: the *fire* checks
   for a minifig above it every frame. Swift: the *junkbot* checks what's under its feet —
   but only **on its walk-cadence frames** (`animationFrame % 5 == 4`, 360) and only when
   `!turnedAround`, requiring the fire to span his full width (`ground.x <= junkbot.x &&
   ground.x + ground.width >= junkbot.x + junkbot.width`, 393).
   Consequences:
   - **[divergence] Standing still on a fire that switches on:** Lingo kills the minifig
     the frame the fire turns on. Swift kills him only on his next walk frame *while
     standing exactly on it* — but since a walking junkbot re-walks every 5 ticks, the
     practical delay is ≤ 5 ticks (~0.28s). A junkbot in a non-walking state (collecting a
     bin, getting a shield) standing over a fire survives in Swift until the state ends;
     in Lingo the fire kills him immediately (his `#EAT` mode doesn't block `notify`
     damage — it goes straight to `#DEAD`).
   - **[divergence] Partial overlap:** Lingo's probe is the fire's own 2-cell top — a
     minifig overlapping just *one* cell of the fire still matches (`checkFitOrMinifig`
     returns the minifig if any probed cell holds him). Swift requires the fire to fully
     span the junkbot. A junkbot straddling the edge of a fire burns in Lingo but not in
     Swift.
2. **[inherited] Animation.** Lingo cycles 7 flame frames linearly; Swift's renderer
   ping-pongs 8 ticks over 5 frames (`m4 = af%4; af%8<4 ? m4 : 4-m4`) — the JS remake's
   look. Cosmetic.

## Verdict

Same rule ("don't stand on a lit fire"), but the edge semantics differ: Lingo is
edge-inclusive and immediate; Swift is full-overlap and walk-frame-gated. The JS remake
chose these; levels designed for the original could be slightly more forgiving here.
