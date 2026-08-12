---
copy_of: strategy-seeds/cards/approved/QM5_20273_wti-signrun-tr_card.md
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_SIGNRUN12_S22
variant_id: MOP-TSMOM-2012_XTI_SIGNRUN12_S22
source_id: MOP-WTI-SIGNRUN-2026
ea_id: QM5_20273
slug: wti-signrun-tr
status: APPROVED
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: monthly-wti-prior-twelve-adjacent-return-dominant-longest-four-sign-run-trend
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: Q01_PASS
q01_status: PASS
q02_status: NOT_ENQUEUED
last_updated: 2026-08-10
---

# QM5_20273 WTI Dominant Sign-Run Trend

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20273_wti-signrun-tr_card.md`.

## Hypothesis

A uniquely dominant same-sign run of at least four months inside WTI's prior
twelve completed monthly returns may represent a sustained oil regime more
cleanly than a cumulative endpoint return or unordered sign count. This is a
direct crude-oil structural carrier, not a profitability or decorrelation
claim.

## Rules

At each genuine broker-month transition, reconstruct thirteen consecutive
completed `XTIUSD.DWX` month-end closes and form the twelve chronological
adjacent log returns. Exact zeros reset both runs. Buy when the longest
positive run is at least four and strictly longer than the longest negative
run; sell under the symmetric rule; consume ties and below-threshold states
flat. Renew at the next month boundary. The canonical card locks endpoints,
orientation, zero handling, run updates, threshold, tie rule, persisted
attempt, ATR stop, spread cap, and lifecycle.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, one frozen `3.5 * ATR(20,D1)` hard stop, and no
take-profit. No live artifact, portfolio mutation, correlation claim, or
waiver is authorized.

## Pipeline Status

G0 is approved under the durable OWNER mission decision. Deterministic
allocation and build/Q01 are PASS; Q02 enqueue remains pending.
