# parent_play manager.ls — Play-mode manager (drag & drop, win/lose, actor loop)

**Swift counterparts:** `Input.swift` (whole file — `mouseDown`/`mouseMove`/`mouseUp`,
`possibleGrabsInDirections`, `findAttachedGroup`, `canRelease`), `GameEngine.tick` /
`simulate()` dispatch loop, `winOrLose` (Simulation.swift 13-26). Cursor/GUI parts remain
in `src/game.js`.

## What the Lingo does

- **Actor loop:** `stepFrame` iterates `myactors` (one behavior instance per active part),
  the direct ancestor of `simulate()`'s type-dispatch loop. Actors are instantiated from a
  type→script map at `setLevel`; bins are "goals" counted up front (`numGoals`).
- **Win/lose:** event-driven, not recomputed: `addStatus(#damage, 1)` = instant LOSE (any
  minifig death ends the level); `addStatus(#goals, 1)` decrements `numGoals`, and 0 = WIN.
- **Drag & drop** (`#move`/`#pressing`/`#dragging` tool modes):
  - Press on a part: `findPieceGroup(pos, #down)` and `(pos, #UP)` compute the two candidate
    grab groups; cursor shows grab-up/down/both.
  - `doPressing`: direction resolved when the mouse moves **> 3 px** vertically (or
    immediately if only one direction has a group). On resolution: erase group from the
    playfield, blend sprites to 75%, `blockpickup` sound, **`addStatus(#moves, 1)` — the
    move is counted at pickup**.
  - `#dragging`: ghost follows the mouse; per-part `checkPlaceable` classifies contact as
    `#above`/`#below`/`#nofit`, requiring **all parts to agree on one attachment direction**
    (mixed above+below = not placeable, `fitDir` conflict check) and at least one actual
    attachment (`voidp(fitDir)` = floating = not placeable). Placeable: 75% blend; not: 25%.
    Release (or second click — note `mousestate = #press` *also* places) commits with
    `blockdrop`; releasing while unplaceable **keeps dragging** (toolmode stays `#dragging`).
- **doSwitch:** label-based broadcast to parts (see switch analysis).
- **pause/leave/instantWin** (authoring), status text fields: UI shell.

## Matched behavior in Swift

- Two-direction grab model with pending-direction resolution and grab-up/down/both cursors
  (`possibleGrabsInDirections`, `pendingGrabUpward/Downward`). ✔
- Invalid release keeps the drag active (`mouseUp` gated on `canRelease()`). ✔ Faithful to
  the Lingo `#dragging` loop never exiting without a placeable commit.
- Single-attachment-direction placement rule: `canRelease`'s `allConnectedToFixed`-based
  logic enforces the same "must attach, and coherently" idea; JS/Swift additionally reject
  fire/fan adjacency (an Undercover-era rule, no Lingo counterpart here).
- Drag alpha 75%/25% == Swift renderer's 80/30 grabbed alpha. ≈✔ (5-point value drift,
  cosmetic, inherited from JS.)
- Move counting at **pickup** (`startDrag` increments `moves`) == `addStatus(#moves, 1)` in
  `doPressing`. ✔ Both count a pickup even if you place it back where it was.
- Win/lose: Swift recomputes `winOrLose()` each tick instead of event-counting. Same
  outcomes, with one deliberate JS-inherited nuance: a junkbot can *win then die* if a
  hazard kills him post-collection — Lingo's event model ends the level at the WIN moment,
  fully preventing the "Both won and lost" class of issue the current JS/Swift test suite
  tracks as 8 known failures. **The original architecture made those bugs impossible.**
  [divergence, root of a known issue family]
- Pixel drag threshold: Lingo ±3 px; JS used 10 canvas px; Swift uses `CELL_H/2` (9) world
  px. All "small nudge resolves direction"; feel differs slightly. [inherited]

## Differences

1. **Win/lose model** — see above; the biggest conceptual divergence found in this whole
   analysis, and it maps 1:1 onto the known "wins then dies" test failures.
2. **[inherited] Click-to-place:** Lingo places on *either* a fresh press or release while
   placeable (`(mousestate = #press) or (mousestate = #release)`, 268) — i.e. sticky drag
   with click-to-drop. Swift/JS only place on release (`mouseUp`). Original supported
   "click, move, click" dragging without holding the button.
3. **[architectural] Erase-while-dragging:** Lingo removes the group from the playfield
   grid during the drag (it stops colliding); Swift keeps entities in `entities` flagged
   `grabbed` with every collision filter skipping them. Equivalent.
4. Lingo's `moveoffset` anchors the ghost to the group's top-left; JS/Swift preserve the
   original grab offset. Cosmetic.

## Verdict

Drag mechanics are faithfully ported (via JS) including the subtle keep-dragging-on-invalid
rule and pickup-time move counting. The event-driven vs recomputed win/lose model is the
one deep divergence — it explains why "wins then dies" bugs can exist here and couldn't in
the original.
