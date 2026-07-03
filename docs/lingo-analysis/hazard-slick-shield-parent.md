# parent_hazard slick shield parent.ls — Shield pickup

**Swift counterpart:** `Simulation.swift` — the `.shield` ground case in `simulateJunkbot`
(418-425); shield lifecycle in `hurtJunkbot` (47-49) + decay (219-227).

## What the Lingo does

While `#on`: probe the two cells above (same both-probes-same-minifig alignment test as
the jump brick). On a match: `notify([#SHIELD: 1])` — the minifig plays its `#SHIELDON`
animation (14 frames) and sets `SHIELD = 1` — and the pad flips itself `#off`
(single-use), redrawing.

On the minifig side (see minifig analysis): the shield absorbs the **first** damage event,
which starts a 120-tick (2s) `shieldticks` countdown with sprite flicker; when it expires,
`SHIELD = 0` with a powerdown sound. Notably the Lingo shield is **not consumed by the
hit itself** — it keeps absorbing *all* damage during the 2s flicker window and only then
expires.

## Matched behavior in Swift

- Single-use pad (`used = true`, 423) with pickup sounds (`getShield` + `getPowerup` ==
  Lingo's `h_powerup1` + `shieldon2`). ✔
- Pickup only when not already shielded (`!junkbot.armored` guard == Lingo minifig's
  `mode <> #SHIELDON` implicit gate — Lingo actually *re-grants* freely; see below). ~
- Getting-shield animation freeze (11 ticks, `gettingShield`) ≈ Lingo's 14-frame
  `#SHIELDON`. ✔ (~3 frames shorter; cosmetic.)
- Post-hit behavior: shield absorbs the hit, flickers for 2 seconds (36 sim-ticks == 120
  wall-ticks), keeps absorbing during that window (`hurtJunkbot`: `losingShield` already
  set → hits are silent no-ops), then expires with a powerdown sound. ✔ Faithful.

## Differences

1. **[divergence] Re-pickup while shielded.** Lingo's pad triggers for any aligned minifig
   — including one already shielded (its `notify(#SHIELD)` handler re-runs `SHIELDON`,
   resetting `shieldticks` to VOID, i.e. refreshing a decaying shield to full). Swift only
   grants when `junkbot.losingShield || !junkbot.armored` (418) — a junkbot with a *healthy*
   shield walks over the pad without consuming it, whereas in Lingo he'd consume it as a
   (pointless) refresh. Swift's is arguably a fix; pad-inventory counts differ on levels
   with multiple shields.
2. **[architectural] Trigger inversion + walk gating** — same as fire/jump: Lingo probes
   every frame; Swift checks underfoot on walk frames with full-span alignment. Delay ≤ 5
   ticks; straddle-the-edge pickups that Lingo would grant, Swift doesn't.

## Verdict

Faithful shield lifecycle (absorb → 2s flicker → expire). The only real difference is
pad consumption when already shielded (item 1) — Swift preserves the pad, the original
wasted it.
