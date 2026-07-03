# parent_game manager.ls — Game/meta manager

**Swift counterpart:** none in `JunkbotCore` (correctly). The equivalent responsibilities
live in `src/game.js`'s GUI/routing/localStorage regions and the level-listing loaders.

## What the Lingo does

Meta-game shell, no simulation logic:

- **Level catalog:** reads every member of the `levels` cast, parses level text
  (`config_manager.parseParams`), groups into 4 buildings × 15 levels, tracks lock state.
- **Progress records:** `encodeREcord`/`decodeRecord` — a comma-separated
  `index moves` string persisted via `database_manager` (server-backed), plus derived
  stats: keys (levels completed), gold (moves ≤ par), plaque rank thresholds
  (10/20/30/40/60 golds → day/week/Month/year/president), Hall-of-Fame at 60 keys.
- **Flow:** startLevel/restartLevel/endLevel(#WIN/#LOSE), intermission (award box),
  music start/stop per level (`level1..5` random track).

## Comparison

- The JS remake (and thus this repo) replaces buildings/keys/plaques with hash-routed
  level selection and `localStorage` best-solution records — an intentional redesign, not
  a port gap.
- Move counting semantics carried over: `glob.current.moves` snapshotted into the record
  at WIN == JS saving the solution/moves on win.
- Par (`goal`) comparison for gold (`goal >= moves`) matches the JS remake's par display
  semantics (par met = moves ≤ par).
- Nothing here needs Swift porting: the Swift engine's `moves` counter (incremented at
  pickup, reported via `engineTick` result) already feeds the JS shell exactly the datum
  this manager consumed.

## Verdict

Out of simulation scope. No divergences that affect gameplay; the surrounding meta-game
was deliberately reimagined in the remake.
