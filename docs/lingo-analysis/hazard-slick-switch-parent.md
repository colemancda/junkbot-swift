# parent_hazard slick switch parent.ls — Floor switch

**Swift counterpart:** `Simulation.swift` — the `.switch` ground case in `simulateJunkbot`
(398-409).

## What the Lingo does

Every frame: probe the two cells above (both-probes-same-minifig alignment). Uses a
`stepped_on` latch: on the **rising edge** (minifig newly on the switch), toggle
`#on`/`#off` with click + on/off sounds and broadcast `play_manager.doSwitch([#label,
#state])`, which `notify([#switch: state])`s every part sharing the switch's label
(fires, fans, jump bricks…). The latch resets only after the probe comes up empty —
standing on the switch toggles it exactly **once** no matter how long you stand.

## Matched behavior in Swift

- Toggling the switch toggles every entity sharing its `switchID` (402-407 == `doSwitch`
  by label). ✔
- Click + directional on/off sounds. ✔
- Junkbot alignment requirement (full-span, 393). ✔

## Differences

1. **[divergence — the big one in this file] Edge-trigger vs step-trigger.** Lingo
   toggles once per *continuous occupancy* (rising-edge latch; standing still never
   re-toggles). Swift toggles on every **walk frame in which the junkbot stands on it**
   while moving — but because the ground check runs only when `!turnedAround` on a walk
   frame, a junkbot *walking across* a switch toggles it on each walk step that ends
   fully-aligned on it. A 2-cell switch under a 2-cell junkbot is exactly one aligned
   step, so ordinary crossings toggle once in both. However:
   - A junkbot who walks onto the switch and is then **blocked** (turns around on it)
     can re-toggle on subsequent walk frames in Swift (each non-turning step that
     re-lands on it), where Lingo's latch would stay silent. The regression level
     "Switch Off At Edge Case" exists precisely to pin this behavior — and note it is
     one of the 8 known "wins then dies" failures in the current suite, so this edge is
     already a known soft spot in the JS-remake lineage the Swift port follows.
   - Junkbot standing permanently on a switch: neither re-toggles (Swift's ground scan
     only runs on walk frames, and a stationary junkbot doesn't walk — he always walks
     unless blocked, in which case he alternates turn/walk; a turn frame is skipped via
     `!turnedAround`). Behavior interleaves in ways the Lingo latch made trivially
     predictable.
2. **[architectural] Broadcast mechanism.** Label-based `notify` fan-out vs `switchID`
   field scan — equivalent linkage semantics, including many-to-many (multiple switches
   sharing a label/ID).

## Verdict

The linkage and sounds are faithful, but the trigger discipline differs: the original is a
clean edge-trigger, the Swift/JS lineage re-derives it from walk-step geometry. This is the
most gameplay-relevant divergence in the hazard set (and its edge case is a known
pre-existing test failure).
