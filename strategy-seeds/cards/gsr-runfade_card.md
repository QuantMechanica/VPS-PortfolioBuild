---
copy_of: strategy-seeds/cards/approved/QM5_20275_gsr-runfade_card.md
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-GSR-RUNFADE-2026_S04
variant_id: SCHWEIKERT-CME-GSR-RUNFADE-2026_S04
source_id: SCHWEIKERT-CME-GSR-RUN-2026
ea_id: QM5_20275
slug: gsr-runfade
status: APPROVED
g0_status: APPROVED
source_author: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
strategy_mechanic: synchronized-d1-gold-silver-log-ratio-five-consecutive-same-sign-relative-returns-fresh-run-exhaustion-reversion-basket
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
period: D1
pipeline_phase: Q02_ENQUEUED
q01_status: PASS
q02_status: ENQUEUED
last_updated: 2026-08-11
---

# QM5_20275 Gold/Silver Fresh-Run Fade

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20275_gsr-runfade_card.md`.

## Hypothesis

The first completed five-session same-sign run in the synchronized
gold/silver log ratio may be a short-horizon relative-price exhaustion event.
Fade it with opposite XAU/XAG legs and close on the first completed
counter-return.

## Rules

Use seven synchronized completed D1 ratios. Require five newest strict
same-sign relative returns and a sixth return that breaks the run. Fade the
upper run with SELL XAU / BUY XAG and the lower run with BUY XAU / SELL XAG;
close on the first counter-return, invalid package/state, or after twelve
days. The canonical card locks exact shifts, comparisons, sides, aggregate
fixed-risk split, ATR stops, spread caps, and consumed-event contract.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` for
one logical basket. Opposite legs are not proof of neutrality. No live
artifact, portfolio mutation, correlation waiver, or efficacy claim is
authorized.

## Pipeline Status

G0 is OWNER-approved. Q01 passed strict compile, target build validation, and
P1 artifact validation on 2026-08-11. Exactly one current-binary Q02 logical
basket was enqueued below the factory CPU ceiling: work item
`2384e96c-5240-4c0c-8829-c2fab47702b3`, attempt 0 with no verdict at handoff.
