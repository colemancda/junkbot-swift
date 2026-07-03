# parent_hazard drip parent.ls — Droplet

**Swift counterpart:** `Simulation.swift` — `simulateDroplet` (712-742); spawning in
`simulatePipe` (748-757).

## What the Lingo does

Spawned by the pipe behavior. Purely visual sprite (`auxSprites`) — it is **not** a
playfield part; it probes the grid directly. Each frame while `#falling`: move down **18
pixels (one cell)**, test the destination cell via `checkFitOrMinifig` (footprint
`#BRICK_02`, 2 cells wide); if free keep falling; if it hit something, stop: a minifig
there takes `#damage: #drip` (with `electricity1` sound), anything else plays a random
`drip1..3`. Then a 5-frame splash animation (`dripstate 1..5`) and self-removal.

## Matched behavior in Swift

- Falls exactly one cell (18px) per tick: Swift's inner loop moves 1px × 18 sub-steps,
  checking for a landing after each pixel (718-740) — same net speed, finer landing
  detection. ✔
- Kills Junkbot by water on contact (`hurtJunkbot(cause: 2)` == `#damage: #drip` which the
  minifig maps to `#DEAD_DRIP`). ✔
- Random drip sound from a set of 3 on landing. ✔ (Lingo plays `electricity1` *instead*
  when it kills a minifig; Swift plays a drip sound regardless plus the death sound from
  `hurtJunkbot` — near-equivalent audio, cosmetic.)
- Splash: Lingo 5 frames then done; Swift `animationFrame > 4` → remove (5 frames). ✔
- Droplets are non-solid to everything else in both (Lingo: never placed in the playfield;
  Swift: every collision filter is `isNotDroplet…`). ✔

## Differences

1. **[architectural] Landing granularity.** Lingo lands only on whole-cell boundaries
   (moves 18px, then tests); Swift tests each pixel, so a droplet can land on
   non-grid-aligned things (a mid-drag brick, a falling crate). Richer but strictly a
   superset — grid-aligned levels behave identically.
2. **[architectural] Width semantics.** Lingo probes a 2-cell-wide `#BRICK_02` footprint;
   Swift compares `dx + dw <= g.x || dx >= g.x + g.width` with the droplet's own (narrow)
   width. Lingo's droplet is "wider" for collision purposes; in practice pipes hang over
   grid-aligned columns and both hit the same targets.
3. Lingo droplets damage a minifig only if the minifig is the *first* thing in the landing
   cell; Swift scans all entities at the landing row and can kill Junkbot while also
   splashing on the same tick it touches two overlapping things. Same outcome in real
   levels.

## Verdict

Equivalent behavior at level scale; Swift's pixel-stepping is a refinement, not a
divergence.
