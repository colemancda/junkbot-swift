# parent_hazard slick fan parent.ls — Fan

**Swift counterpart:** `Simulation.swift` — fan half of `simulateFansAndLasers` (816-848);
Junkbot float handling in `simulateJunkbot` (273-285); wind rendering in
`RenderList.swift` (`appendWindCommands`).

## What the Lingo does

When `#on` (switchable via `notify([#switch: state])`): every frame, for each of its **2
interior columns** (`part.pos + point(1, y)` and `point(2, y)`), scan upward cell by cell
(`checkFitOrMinifig` with a 1-cell `#BRICK_01` probe): empty cells extend that column's
`airjet_height`; the first occupied cell stops the column — if it's a **minifig**, it
becomes `gotMinifig`. If any column caught a minifig, `notify([#FAN: part])` lifts it (the
minifig's `fanAnim` then moves it up one cell if it fits) and the `fan` sound plays once
per continuous contact (`switch` latch). Air-jet sprites are drawn per column with height
`airjet_height` and a 7-phase animation cycle (`airjet_cycle`, randomized start).

## Matched behavior in Swift

- Per-column upward raycast from the fan's interior columns, stopped by the first solid
  non-droplet obstacle, with per-column extent recorded for rendering (`WindEffect`
  extents == `airjet_height`). ✔
- Junkbot in the stream floats up one cell per tick if the cell above is free
  (`floating` → 273-285 == `fanAnim`). ✔
- Fan sound only on the *start* of lift: Lingo's `switch` latch == Swift's
  `!other.wasFloating` check (833). ✔
- Switch-controlled on/off. ✔
- 7-phase air animation (renderer `fan.animationFrame % 7`). ✔ (Lingo randomizes each
  fan's starting phase, `airjet_cycle = random(7)`; Swift fans animate in lockstep —
  cosmetic.)

## Differences

1. **[architectural] Scan cap.** Lingo scans until it exits the playfield top; Swift stops
   at `y > -200` (~11 cells above world origin) — beyond any real level's airspace.
2. **[divergence] What blocks the stream.** Lingo: a *minifig* terminates the column scan
   (it "catches" the wind — nothing above a caught minifig is lifted, and its column's
   air-jet stops at him). Swift: a floating junkbot does **not** stop the wind column
   (832-835 marks him floating and continues scanning up; only non-junkbot solids break).
   Two junkbots stacked in one stream would both float in Swift; in Lingo only the lower
   one is lifted. Also the *rendered* air column extends through Junkbot in Swift but
   visually stopped at him in Lingo. Single-junkbot levels: no difference in outcome.
3. **[architectural] Lift mechanics.** Lingo pushes lift through `notify(#FAN)` →
   `fanMode` consumed next `stepFrame`; Swift marks `floating` this tick, consumed by
   `simulateJunkbot` next dispatch, with `wasFloating` handover per tick (924-927). Same
   one-cell-per-tick net rate.

## Verdict

Equivalent for real levels; the through-junkbot wind continuation (item 2) is the only
observable divergence and needs stacked minifigs to matter.
