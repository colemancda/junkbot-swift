# parent_hazard walk parent.ls — Gearbot

**Swift counterpart:** `Simulation.swift` — `simulateGearbot` (469-496).

## What the Lingo does

Two-frame animation; `step()` runs on frame 2, so the gearbot **moves every 2 frames**.
Each step: try `pos + dir` via `checkFitOrMinifig`; if it fits (`fg = 1`) **and**
`checkFloor(pos, 2) > 1` (i.e. **both** columns supported — gearbots never overhang),
move. Otherwise turn around. If a minifig was in the way (`fg` is the minifig part), it
does *not* move (falls through to turn) and damages the minifig (`robottouch4` +
`notify([#damage: #walker])`).

## Matched behavior in Swift

- Hurt-junkbot-then-turn when Junkbot is directly ahead (482-488), including not moving
  into his cell. ✔ (`hurtJunkbot` no-ops when Junkbot is already dying, matching the Lingo
  minifig ignoring `#damage` in `#DEAD` mode.)
- Turn (without sound — Lingo also plays no turn sound for walkers) when blocked or when
  ground ahead is missing. ✔
- Full-support requirement: Lingo demands both columns floored (`> 1`). Swift only tests a
  `CELL_W`-wide rect under the **leading edge** (478-481), but inductively the trailing
  cell is the previously-tested leading cell, so a gearbot that started fully supported
  stays fully supported. ✔ Equivalent in steady state. Edge case: a gearbot *placed* (or
  landing after a fall) with an unsupported trailing cell will happily keep walking in
  Swift but would turn in Lingo — only reachable via editor placement mid-play.
- Gravity: Lingo walkers implicitly stay put vertically (no fall logic in this behavior —
  the playfield's brick-fall handles it); Swift includes gearbots in `simulateGravity`
  (with `direction: 1` support check). Same net effect. ✔

## Differences

1. **[inherited] Cadence.** Lingo moves every **2** frames; Swift moves every **3** ticks
   (`animationFrame > 2` → reset, 470-472). Gearbots are ~33% slower relative to Junkbot in
   the Swift/JS remake than in the original. Speed *ratios* to junkbot: Lingo 1 step/2
   frames vs junkbot 1/5; Swift 1/3 vs 1/5. Faithful to JS, not to Lingo.
2. **[architectural] Damage direction.** Lingo damages the minifig only when the minifig
   occupies the target cell(s) of the gearbot's whole 2-cell shape; Swift tests a
   single-point `entityCollisionTest` at the leading cell. Same practical geometry for the
   2-wide gearbot vs 2-wide junkbot.

## Verdict

Logic-equivalent; only the movement cadence differs (inherited from the JS remake).
