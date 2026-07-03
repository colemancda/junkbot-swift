# Lingo → Swift logic analysis

File-per-file comparison of the original Macromedia Director Lingo sources (from the 2001
Junkbot game, checked in under `Sources/JunkbotCore/play/` etc.) against this repo's Swift
simulation (`Sources/JunkbotCore/Simulation.swift`, `Input.swift`, `Collision.swift`).

**Important context for reading these:** the Swift code was ported from `src/game.js` (the
HTML5 remake), which was itself a reimplementation of the Lingo original. So differences fall
into three buckets, labeled in each analysis:

- **[inherited]** — a deliberate JS-remake redesign the Swift port faithfully carries
  (e.g. momentum-based jump ballistics instead of Lingo's fixed trajectory table).
- **[architectural]** — a consequence of the different world models. Lingo simulates on a
  coarse cell grid (`playfield[x][y]` occupancy, one part index per cell, 15×18-px cells)
  with wall-clock (`the ticks`, 60/sec) timers; Swift/JS use pixel-rect collision at 18
  simulation ticks/sec.
- **[divergence]** — a real behavioral difference that could produce different outcomes on
  the same level, worth review.

Lingo collision primitives referenced throughout (defined in
`editor/parent_playfield manager.ls`):

| Primitive | Semantics |
|---|---|
| `checkFit(pos, typ)` | 1 iff every cell of the piece's shape is empty and in bounds |
| `checkFitOrGoal` | like `checkFit`, but a goal (bin) in the way returns the bin part instead of failing |
| `checkFitOrMinifig` | like `checkFit`, but a minifig in the way returns the minifig part |
| `checkFitMiniFigHit` | strict `checkFit` (minifig still blocks), but records the hit minifig in `glob.PLAYER.minifigHit` |
| `checkFloor(pos, w)` | counts columns (of `w`) supported by a **brick or slick-brick** below, or by the playfield bottom edge — minifigs/enemies never count as floor |
| `checkPlaceable` | drag-drop placement: `#fit`/`#above`/`#below`/`#nofit`, slick bricks refuse attachment |

## Files analyzed (play/ — the simulation logic)

| Lingo file | Swift counterpart | Verdict |
|---|---|---|
| [parent_minifig walk parent.ls](minifig-walk-parent.md) | `simulateJunkbot`/`walk`/`hurtJunkbot` | Mostly equivalent; several inherited redesigns, 2 divergences |
| [parent_play manager.ls](play-manager.md) | `Input.swift`, `GameEngine.tick`, `winOrLose` | Equivalent core; drag threshold + move counting differ |
| [parent_game manager.ls](game-manager.md) | JS shell (`src/game.js` GUI) | Out of sim scope; metadata only |
| [parent_hazard walk parent.ls](hazard-walk-parent.md) | `simulateGearbot` | Equivalent logic, cadence differs |
| [parent_hazard climb parent.ls](hazard-climb-parent.md) | `simulateClimbbot` | Same state machine, 2 subtle differences |
| [parent_hazard float parent.ls](hazard-float-parent.md) | `doEyebotTargeting`/`doEyebotMovement` | Same idea, different speed/timeout model |
| [parent_hazard dumbfloat parent.ls](hazard-dumbfloat-parent.md) | `simulateFlybot` | Equivalent |
| [parent_hazard drip parent.ls](hazard-drip-parent.md) | `simulateDroplet` | Equivalent; fall speed modeled differently |
| [parent_hazard slick pipe parent.ls](hazard-slick-pipe-parent.md) | `simulatePipe` | Drip scheduling differs (cycle pattern lost) |
| [parent_hazard slick fan parent.ls](hazard-slick-fan-parent.md) | `simulateFansAndLasers` (fan half) | Equivalent column model; float physics differ upstream |
| [parent_hazard slick fire parent.ls](hazard-slick-fire-parent.md) | `simulateJunkbot`'s ground check | Inverted responsibility; same net effect |
| [parent_hazard slick jump parent.ls](hazard-slick-jump-parent.md) | `simulateJump` + junkbot jump trigger | Cooldown model differs |
| [parent_hazard slick shield parent.ls](hazard-slick-shield-parent.md) | junkbot `.shield` ground case | Equivalent trigger; duration model differs |
| [parent_hazard slick switch parent.ls](hazard-slick-switch-parent.md) | junkbot `.switch` ground case | **Divergence: edge-trigger vs step-trigger** |
| [behavior_Master.Box.Out.ls](master-box-out.md) | none | Trivial UI glue, nothing to port |

Directories **not** analyzed (no simulation logic): `Internal/` (Director shell, sound
mixer, tooltips, frame loop), `editor/` (level editor UI; its `parent_playfield manager.ls`
collision primitives are covered inline above and in each analysis), `catalog/`,
`screens_by_peter/`, `loading/`, `dynamic/`, `peter 101/` (menus/screens/network glue).
