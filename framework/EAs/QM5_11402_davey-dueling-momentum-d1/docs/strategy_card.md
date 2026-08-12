---
ea_id: QM5_11402
slug: davey-dueling-momentum-d1
type: strategy
source_id: fcee8d26-0910-56f3-a0f4-7a0d0a1dfdc9
sources:
  - "[[sources/kevin-davey-kjtradingsystems-my-5-favorite-entries]]"
concepts:
  - "[[concepts/counter-trend]]"
  - "[[concepts/dual-lookback-momentum]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/atr]]"
period: D1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX]
source_citation: "Kevin J. Davey, My 5 Favorite Entries (kjtradingsystems.com webinar), Entry #5: Dueling Momentum, locally preserved PDF and extracted text."
g0_status: APPROVED
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-08-11
expected_trades_per_year_per_symbol: 20
card_body_incomplete: false
card_body_missing: ""
status: draft
g0_approval_reasoning: "R1 named professional source lineage retained; R2 deterministic dual-lookback momentum entry with ATR exits and conservative 20/year cadence; R3 testable on listed DWX FX symbols; R4 deterministic, ML-free, one-position compatible."
expected_pf: 1.2
expected_dd_pct: 18.0
---

# QM5_11402 Davey Dueling Momentum (D1)

## Source

- Kevin J. Davey, *My 5 Favorite Entries*, Entry #5, "Dueling Momentum."
- Approved farm artifact:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11402_davey-dueling-momentum-d1.md`.
- Locally preserved source extraction:
  `D:/QM/strategy_farm/artifacts/extracted/374755020-My-5-Favorite-Entries.txt`.
- The source supplies the named entry mechanic. It is not treated as a
  symbol-specific performance claim for GBPUSD or the other DWX pairs.

## Hypothesis

Short-horizon momentum that opposes longer-horizon momentum identifies a
temporary rebound inside the longer move. Entering in the short-horizon
direction is a bounded counter-trend hypothesis whose edge can be tested on
closed D1 prices without learned state, discretionary chart interpretation,
or high-frequency execution.

## Rules

- Evaluate only after a new D1 bar and use closed bars.
- Starting lookbacks are `sl=5` and `slx=25`.
- Long when `Close[1] > Close[1+sl]` and
  `Close[1] < Close[1+slx]`.
- Short when `Close[1] < Close[1+sl]` and
  `Close[1] > Close[1+slx]`.
- Enter at market on the next eligible bar after framework and spread
  clearance.
- Initial stop: `1.5 * ATR(14)`, capped at 60 pips.
- Initial target: `1.5 * ATR(14)`.
- Move the stop to breakeven after favorable movement of `1.0 * ATR(14)`.
- Close a long if short-term momentum flips down; close a short if it flips
  up.
- Allow one position per registered `(ea_id, symbol_slot)` magic.
- Block new entries above a 25-pip spread; existing-position management
  remains enabled.

## Risk

- Backtest mode uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- No grid, martingale, pyramiding, adaptive sizing, online fitting, or ML is
  authorized.
- Framework kill-switch, news, Friday-close, and one-position protections
  remain active.

## Parameters to Test

- `strategy_sl_lookback`: 3, 5, 10.
- `strategy_slx_lookback`: 20, 25, 40.
- `strategy_atr_tp_mult`: 1.0, 1.5, 2.0.
- The Q02 baseline remains the fixed starting tuple in the canonical setfile;
  no parameter rescue is authorized by this Card normalization.

## Framework Alignment

- Trade entry: `Strategy_EntrySignal` implements the two closed-price
  comparisons and fixed ATR/capped-stop package.
- Trade management: `Strategy_ManageOpenPosition` implements the one-ATR
  breakeven step.
- Trade close: `Strategy_ExitSignal` implements the short-lookback momentum
  flip.
- No-trade: framework defaults plus the Card-authorized spread cap.

## Traceability

This file normalizes the already OWNER-approved farm Card into the repository
schema required for deterministic rebuilds. It does not change the approved
mechanics or authorize live use.
