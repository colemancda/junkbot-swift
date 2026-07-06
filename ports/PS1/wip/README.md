# Parked work-in-progress: GameState/FixedArray-based game state

These three files (`FixedArray.swift`, `GameState.swift`, `PS1RenderList.swift`) implement the
`InlineArray`-backed fixed-capacity replacement for `JunkbotCore`'s `GameEngine`, per the plan
doc's "Phase 2" section. They are **not currently compiled** — `compile-swift.sh` only globs
`source/*.swift`, and this directory is intentionally outside `source/`.

They were pulled out of `source/` while bisecting a hang, per the user's request to descope
down to "just statically render the viewport, no game engine" (see `../KNOWN_ISSUES.md`
"Update 5"). That bisection found the actual bug was unrelated to these files (a global `let`
pointer-cast initializer, fixed in `../source/Renderer.swift`) — `FixedArray` itself is still
believed sound (its own isolated tests all passed). These files just haven't been re-verified
against the current, fixed `Renderer.swift`/`main.swift` shape yet.

**To resume this work:** move these files back into `../source/`, reconcile `blitSprite`'s
signature (the current `../source/Renderer.swift` takes `spritePixels` as a parameter computed
locally per KNOWN_ISSUES.md's "Update 5" fix, rather than as a global — `PS1RenderList.swift`
predates that fix and will need the same treatment), and re-run the same milestone-by-milestone
verification in DuckStation described in the plan doc.
