# V4 Legacy Risk-Review Snapshot — NOT a V5 input

> **STATUS: ARCHIVE / LEGACY ONLY (2026-04-26).** This document captures the V4 portfolio risk review state as it existed on the laptop on 2026-04-18 / lock v3 2026-04-19. **It is not a V5 input.** V5 is a clean restart: V5 will source new strategies, build a new EA framework, and run them through the V5 / V2.1 pipeline from scratch. None of the SM_XXX sleeves below carry into V5 unless they are independently re-derived from new research and pass every V5 gate.
>
> See `decisions/2026-04-26_v5_restart_clean_slate.md` and `docs/ops/V5_RESTART_SCOPE_BOUNDARY.md` for the explicit boundary between what V5 inherits (process model, pipeline shape, hard rules, learnings) and what V5 does not inherit (strategy bestand, locked basket, magic numbers, set files, EA framework).

## Purpose Of This File

This snapshot is preserved only as a historical reference and as evidence for the *learnings* that justified V5's stricter pipeline (PBO gate, V2.1 additive gates, lane-drift caution). It must not be cited as the V5 starting composition.

## V4 Legacy Lineup (2026-04-19, lock v3) — for historical reference only

Source: laptop `Company/Results/V5_COMPOSITION_LOCK_20260418.md` (the file is named "V5" but predates the V5 clean-restart decision and represents late V4 portfolio state).

| SM_ID | V4 lock symbol | V4 weight | P5b receipt symbol | Lane drift? |
|---|---|---|---|---|
| `SM_124` | UK100 | 1.00x | UK100 | none |
| `SM_221` | AUDUSD | 0.25x | AUDUSD | none |
| `SM_345` | AUDNZD | 1.00x | EURGBP | yes |
| `SM_157` | AUDNZD | 1.00x | EURCAD | yes |
| `SM_640` | XTIUSD | 1.00x | AUDUSD | yes |

V4 excluded outliers: `SM_890 AUDUSD`, `SM_890 EURUSD`, `SM_882 WS30`.

## Why It Was Tempting To Treat This As A V5 Input

The Codex laptop reconstruction (`docs/ops/CANONICAL_LAPTOP_STATE_2026-04-25.md`) framed this lineup as something the VPS build "must inherit". That phrasing is wrong for V5: the lineup is laptop project state at the moment of the rebuild decision, not a deliverable that V5 must accept. The reconstruction is a **historical record**, not a backlog.

OWNER confirmed on 2026-04-26 that V5 builds new strategies on a new framework and does not import any old SM_XXX sleeve.

## Useful Learnings From The Snapshot (these DO carry into V5 thinking)

These are not "the locked basket" — they are *reasons V5's pipeline is what it is*:

1. **Lane drift is a real failure mode.** Three of five locked sleeves had a lock symbol that differed from the P5b receipt symbol. V5 must require the gate evidence to be on the deploy lane, not on a "neighbouring" lane justified by cross-sectional robustness alone. (`PIPELINE_PHASE_SPEC.md` already enforces full-history starting at P5; the V5 process must add a "lock lane = evidence lane" check before P9b.)
2. **Waiver creep.** Multi-seed P6 reports were waived for four of five sleeves. V5 must treat waivers as a counted exception, not a default.
3. **YELLOW decisions need formal acceptance criteria.** SM_221 was YELLOW with strict-FAIL / proxy-PASS — V5 needs a documented YELLOW resolution rule before Quality-Tech sign-off, not a per-sleeve narrative.
4. **Setup-data failures must not look like strategy failures.** This rule is already in CLAUDE.md and `PIPELINE_PHASE_SPEC.md`; the V4 risk review confirmed it was the right call.

## What V5 Does NOT Inherit From This Snapshot

- The five SM_XXX sleeves and their parameters
- Any magic-number assignments
- Any set file
- Any per-sleeve weight (1.00x / 0.25x)
- The deploy lane choices
- The `Company/VPS/V6/` deploy folder layout
- Any open V4 waiver

Everything above gets re-derived in V5 or stays unbuilt.
