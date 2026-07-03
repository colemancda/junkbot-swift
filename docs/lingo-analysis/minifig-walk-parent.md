# parent_minifig walk parent.ls — Junkbot behavior

**Swift counterpart:** `Simulation.swift` — `simulateJunkbot` (197), `walk` (108),
`hurtJunkbot` (36); shield decay in `simulateJunkbot` 219-227.

## What the Lingo does

A mode machine (`#WALK/#FALL/#jump/#EAT/#DEAD/#SHIELDON/#SHIELDOFF`) advanced by
`stepFrame` each frame. Walking runs on a 10-frame animation cycle, calling `step()` on
frames 6 and 1 (2 moves per 10 frames). `step()` tries, in order: straight ahead
(`checkFitOrGoal` + `checkFloor(pos,2)`), then step **down** 1, then step **up** 1, else
turn around (`turn1` sound). Bins are "goals": `checkFitOrGoal` returns the bin part when
walking into one, triggering the 19-frame `#EAT` animation and `erasePiece`. Damage arrives
via `notify([#damage: cause])` from hazard behaviors; with `SHIELD=1` the first hit starts a
120-tick (2s wall-clock) `shieldticks` countdown with sprite flicker; otherwise `#DEAD`
(13-frame death anim, then `addStatus(#damage, 1)` = lose). Fan lift is `notify([#FAN])` →
`fanAnim` moves up 1 cell if it fits. Jumping is a **fixed 7-entry trajectory table**
`[[0,-1],[1,-1],[1,-1],[1,0],[1,1],[1,1],[0,1]]` (with per-step pixel offsets for smooth
rendering), aborted into `#FALL` (+ `headbonk1`) on any collision. Falling moves down 1
cell/frame with no horizontal component and no momentum.

## Matched behavior in Swift

- Walk cadence: Lingo's 2 steps / 10 frames == Swift's `animationFrame % 5 == 4` (1 per 5). ✔
- Step-straight / step-up-1 / step-down-1 / else-turn-with-sound envelope in `walk()`. ✔
- Bins don't block walking and get collected on contact (`checkFitOrGoal` ≈ the
  `isNotBinOr…` collision filters + the explicit `binAhead` check at 450-459). ✔
- Shield: absorbs one hit, then decays with flicker before expiring (`losingShield`,
  36 sim-ticks at 18/s = 2s == Lingo's 120 wall-ticks at 60/s = 2s). ✔ Equivalent duration.
- Fire/enemy/water deaths all route through one `hurtJunkbot` just as all Lingo damage
  routes through one `notify(#damage)` handler. ✔
- Death animation length: Lingo 12 frames (frameMax 13, transition at ≥12) vs Swift
  `animationFrame >= 10` — close but not identical; cosmetic only, win/lose state timing
  shifts by ~2 ticks. [inherited]
- Eat animation: Lingo 19 frames vs Swift 17 (`collectingBin`, 231-239). Cosmetic ~2-tick
  difference in when the win is registered. [inherited]

## Differences

1. **[inherited] Jump ballistics.** Lingo uses the fixed 7-step trajectory table; Swift/JS
   use momentum physics (`momentumY = -3`, `momentumX = facing * 5`, gravity +1/tick,
   clamped ±5 — 292-333). The arcs are similar (up ~3, across, down) but not
   cell-identical, and Swift can chain vertical momentum in ways the table cannot (e.g.
   double-jump-pad boosts). Any Lingo-era level solution depending on the exact arc could
   differ.
2. **[inherited] Falling.** Lingo: 1 cell/frame straight down, mode `#FALL`, no horizontal
   carry. Swift: ballistic with `momentumX` preserved from a jump and gravity accel. Pure
   vertical falls behave the same; falls *out of a jump* carry sideways in Swift.
3. **[divergence] Step preference order.** Lingo `step()` tries **down before up**
   (lines 108-135: straight → step_down loop → step_up loop). Swift `walk()` tries **up
   before straight before down** (108-169). In the common cases these are mutually
   exclusive so order doesn't matter, but on geometry where both a legal step-up and a
   legal step-down exist ahead (e.g. walking off a ledge whose far side has both a raised
   ledge and a lower floor within 1 cell), Lingo picks down, Swift picks up. Rare but
   constructible.
4. **[divergence] What counts as floor.** Lingo `checkFloor` counts **only bricks and
   slick-bricks** — another minifig or an enemy is never floor. Swift's ground filter
   `isNotBinOrDropletOrEnemyBot` excludes enemy bots but still counts *another junkbot* as
   ground (only relevant on multi-junkbot levels), and counts crates (crates don't exist in
   the original Lingo game, so this half is moot).
5. **[architectural] Damage plumbing.** Lingo hazards *push* damage into the minifig via
   `notify`; Swift's junkbot *pulls* (checks the ground under itself for fire, etc.) while
   enemy bots push via `hurtJunkbot`. Net effects match; the fire-check geometry is compared
   in [hazard-slick-fire-parent.md](hazard-slick-fire-parent.md).
6. **[architectural] Shield flicker asymmetry.** Lingo flickers the left-facing walk at a
   6-tick period but right-facing at 10 (`doWalkState` 168 vs 182 — almost certainly an
   original bug). Swift renders flicker uniformly (`af % 4 < 2`). Cosmetic.
7. **Head-bonk / head-load.** Swift tracks `headLoaded` (something non-fixed resting on
   Junkbot's head, 200-217) with a bonk sound; the Lingo minifig has no such concept —
   only the jump-collision `headbonk1`. JS-remake addition. [inherited]
8. **Crate pushing** (Swift 360-378) has no Lingo counterpart — crates are a Junkbot
   Undercover feature; this Lingo file is from the original game. Same for teleports,
   lasers, and eyebots referenced elsewhere in `simulateJunkbot`. [inherited]

## Verdict

Core walking/eating/shield/death behavior is equivalent. The jump/fall physics is a
knowing JS-remake redesign. The two true divergences worth remembering: **step-down vs
step-up preference order** (item 3) and **junkbot-as-floor** (item 4) — both only matter on
unusual geometry.
