# parent_hazard slick pipe parent.ls — Pipe (drip source)

**Swift counterpart:** `Simulation.swift` — `simulatePipe` (748-757); constants
`MIN_DRIP_PERIOD = 20`, `MAX_DRIP_PERIOD = 50` (`Types.swift`).

## What the Lingo does

State machine `#DRY`/`#wet`. While `#DRY`, waits `drip_time` wall-clock ticks since the
last drip, where the wait follows a **3-phase cycle** (`drip_cycle` 1→2→3→1…):

- cycle 1: `160 + random(40)` ticks (~2.7-3.3s) — one long gap
- cycles 2, 3: `80 + random(20)` ticks (~1.3-1.7s) — two short gaps

i.e. the original pipe has a *rhythm*: long pause, drip, short pause, drip, short pause,
drip, repeat. When the wait elapses (and no droplet of its own is still alive — `voidp(myDrip)`
gate), it enters `#wet`: a 7-frame wetting animation, and only at the *end* of that animation
spawns the droplet and returns to `#DRY`.

Also defines `checkMiniFig` (kill a minifig hugging the pipe outlet) — **dead code**: nothing
in the file calls it (`stepFrame` only animates and forwards to the droplet).

## Matched behavior in Swift

- Random-interval dripping from the pipe position, droplet spawned below. ✔
- Wet/animation phase before the drip: Swift's renderer derives the "wet" look from
  `timer <= 6 && timer > -1` (RenderList `pipe` case), so the visual wet-then-drip ordering
  survives. ✔
- One droplet at a time per pipe: Lingo enforces via `voidp(myDrip)`; Swift doesn't
  explicitly, but the minimum period (20 ticks) exceeds any droplet's fall+splash lifetime
  on ordinary levels, making overlap practically impossible. ≈✔

## Differences

1. **[divergence] Drip rhythm.** Swift draws every interval uniformly from
   `20..<50` sim-ticks (~1.1-2.8s) with no cycle structure. The original's distinctive
   long-short-short cadence is gone — average rate is similar, pattern is not. Gameplay
   timing puzzles built around anticipating the long gap would feel different. (This is
   inherited from the JS remake.)
2. **[architectural] Clock base.** Wall-clock ticks (60/s, frame-rate independent) vs
   simulation ticks (18/s, pause/rewind-aware). Swift's is the better fit for
   deterministic replay/rewind — intentional.
3. Lingo *guarantees* no concurrent droplets; Swift only makes it unlikely (see above). A
   level with a pipe suspended extremely high could double-drip in Swift.

## Verdict

Functionally similar, but the original's 3-phase drip cadence was simplified to a uniform
random interval — the one Lingo "personality" detail this file loses.
