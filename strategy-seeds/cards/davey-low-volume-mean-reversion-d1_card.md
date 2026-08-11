---
ea_id: QM5_11401
strategy_id: DAVEY_LOW_VOLUME_MEAN_REVERSION_D1
slug: davey-low-volume-mean-reversion-d1
type: strategy
source_id: fcee8d26-0910-56f3-a0f4-7a0d0a1dfdc9
sources:
  - "[[sources/kevin-davey-kjtradingsystems-my-5-favorite-entries]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/volume-filter]]"
  - "[[concepts/n-bar-extreme]]"
indicators:
  - "[[indicators/volume]]"
  - "[[indicators/atr]]"
period: D1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX]
source_citation: "Kevin J. Davey, My 5 Favorite Entries (kjtradingsystems.com webinar), Entry #3: Mean Reversion Low Volume, locally preserved PDF and extracted text."
source_citations:
  - "Kevin J. Davey, My 5 Favorite Entries, Entry #3: Mean Reversion Low Volume."
markets: [FX]
timeframes: [D1]
primary_target_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX]
g0_status: APPROVED
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-08-11
expected_trades_per_year_per_symbol: 8
expected_trade_frequency: "approximately 8 trades per year per symbol"
risk_class: bounded_fixed_risk
ml_required: false
modules_used: [trade_entry, trade_management, trade_close, no_trade]
hard_rules_at_risk: [tick_volume_history_availability]
target_modules: [Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NoTradeFilter]
card_body_incomplete: false
card_body_missing: ""
status: draft
g0_approval_reasoning: "R1 named professional source lineage retained; R2 deterministic low-volume N-bar-extreme entry with fixed ATR exits and conservative 8/year cadence; R3 tick volume and D1 prices available on listed DWX FX symbols; R4 deterministic, ML-free, one-position compatible."
expected_pf: 1.2
expected_dd_pct: 20.0
---

# QM5_11401 Davey Low-Volume Mean Reversion (D1)

## Source

- Kevin J. Davey, *My 5 Favorite Entries*, Entry #3, "Mean Reversion — Low Volume."
- Approved farm artifact:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11401_davey-low-volume-mean-reversion-d1.md`.
- Locally preserved source extraction:
  `D:/QM/strategy_farm/artifacts/extracted/374755020-My-5-Favorite-Entries.txt`.
- The named-author source supplies the entry hypothesis and mechanical form.
  It is not treated as a symbol-specific performance claim for any DWX pair.

## Hypothesis

A closed D1 bar that reaches a recent closing-price extreme on below-average
tick volume represents a weakly sponsored move. The next-bar reversal is a
low-frequency structural hypothesis testable from native price and tick-volume
history without learned state, discretionary chart interpretation, or
high-frequency execution.

## Rules

The fixed baseline mechanics are separated below by framework module.

## 4. Entry Rules

- Evaluate only after a new D1 bar and use closed bars.
- Starting volume lookback is 5 bars and the closing-price extreme lookback is
  20 bars.
- Long when closed-bar tick volume is below its five-bar average and its close
  is within five points of the 20-bar lowest close.
- Short when closed-bar tick volume is below its five-bar average and its close
  is within five points of the 20-bar highest close.
- Skip a flat-range window that simultaneously satisfies both directions.
- Enter at market on the next eligible bar after framework and spread
  clearance.

## 5. Exit Rules

- Initial stop: `1.5 * ATR(14)`, capped at 80 pips.
- Initial target: `2.0 * ATR(14)`.
- No additional discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Allow one position per registered `(ea_id, symbol_slot)` magic.
- Block new entries above a 25-pip spread; existing-position management
  remains enabled.

## 7. Trade Management Rules

- Move the stop to breakeven after favorable movement of `1.0 * ATR(14)`.
- Initial stop and target remain authoritative after entry.
- Existing-position management remains enabled when the fresh-entry spread
  filter is blocking new orders.

## Risk

- Backtest mode uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- No grid, martingale, pyramiding, adaptive sizing, online fitting, banned
  indicator, or ML component is authorized.
- Framework kill-switch, news, Friday-close, and one-position protections
  remain active.

## Parameters to Test

- `strategy_extreme_lookback`: 10, 20, 30.
- `strategy_vol_lookback`: 5, 10.
- `strategy_atr_tp_mult`: 1.5, 2.0, 2.5.
- The Q02 baseline remains the fixed starting tuple in the canonical setfile;
  no parameter rescue is authorized by this Card normalization.

## Framework Alignment

- Trade entry: `Strategy_EntrySignal` implements the closed-bar volume and
  closing-price-extreme comparisons plus the fixed ATR/capped-stop package.
- Trade management: `Strategy_ManageOpenPosition` implements the one-ATR
  breakeven step.
- Trade close: `Strategy_ExitSignal` adds no discretionary close; the fixed
  stop and target remain authoritative.
- No-trade: framework defaults plus the Card-authorized fresh-entry spread cap.

## Traceability

This file normalizes the already OWNER-approved farm Card into the repository
schema required for deterministic rebuilds. It does not change the approved
mechanics or authorize live use.
