---
ea_id: QM5_11435
strategy_id: CARTER_T_ADX35_PRIORDAY_RANGE_H1
slug: carter-t-adx35-priorday-range-h1
type: strategy
source_id: b20a1c94-74f8-58a3-aeac-bfab2f1dbbf0
sources:
  - "[[sources/carter-20-tf-systems]]"
concepts:
  - "[[concepts/prior-day-range]]"
  - "[[concepts/stop-order-entry]]"
  - "[[concepts/adx-filter]]"
indicators:
  - "[[indicators/adx]]"
period: H1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX]
source_citation: "Thomas Carter, 20 Multi-Timeframe Trading Systems, Strategy 11 (online/self-published); named-author Tier-C source with no symbol-specific performance claim."
source_citations:
  - "Thomas Carter, 20 Multi-Timeframe Trading Systems, Strategy 11."
markets: [FX]
timeframes: [H1]
primary_target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX]
g0_status: APPROVED
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-08-11
expected_trades_per_year_per_symbol: 50
expected_trade_frequency: "Approximately 35-60 trades per year per symbol after same-day expiry and the one-position constraint."
risk_class: bounded_fixed_risk
ml_required: false
modules_used: [trade_entry, trade_management, trade_close, no_trade]
hard_rules_at_risk: [pending_order_oco, broker_stop_distance, d1_history_availability]
target_modules: [Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NoTradeFilter]
card_body_incomplete: false
card_body_missing: ""
status: draft
g0_approval_reasoning: "R1 informational named-author lineage; R2 deterministic ADX-gated prior-day OCO breakout with fixed SL/TP and conservative cadence; R3 H1/D1 DWX history exists for the listed FX symbols; R4 deterministic and ML-free with one position per registered magic."
expected_pf: 1.2
expected_dd_pct: 18.0
---

# QM5_11435 Carter ADX<35 Prior-Day Range Stop Entry (H1)

## Source

- Thomas Carter, *20 Multi-Timeframe Trading Systems*, Strategy 11.
- Canonical OWNER-approved farm artifact:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11435_carter-t-adx35-priorday-range-h1.md`.
- The named-author source supplies the mechanical hypothesis. Its Tier-C
  provenance is not treated as a verified track record or as a performance
  claim for any DWX symbol.

## Hypothesis

When ADX(14) is below 35, price is not already in a strong directional trend.
The previous D1 high and low then define structural breakout boundaries. A
same-day OCO bracket offset beyond those boundaries tests whether the next
range expansion persists while limiting risk with fixed stops and targets.

## Rules

The approved baseline uses only native H1/D1 prices, the standard ADX measure,
registered pending orders, and deterministic fixed-risk execution. It does not
learn or adapt from realized PnL.

## 4. Entry Rules

- Evaluate on a new H1 bar using closed-bar values.
- Require ADX(14) on the prior closed H1 bar to be below 35.
- Read the previous completed D1 high and low.
- Place a buy stop 15 pips above the previous D1 high and a sell stop 15 pips
  below the previous D1 low.
- Treat the two stop orders as an OCO bracket: the first fill cancels the
  opposite pending order.
- Do not open another position for the same registered magic and symbol.

## 5. Exit Rules

- Long target: 60 pips above entry; short target: 60 pips below entry.
- Long stop: 30 pips below entry; short stop: 30 pips above entry.
- The configured stop is capped at 40 pips.
- No discretionary or learned exit is authorized.

## 6. Filters (No-Trade Module)

- Block a fresh bracket if the current spread exceeds 20 pips.
- Block fresh entries if bid or ask data are unavailable.
- Preserve management of an existing position or pending bracket while the
  fresh-entry spread filter is blocking.
- Framework kill-switch, news, and Friday-close controls remain active.

## 7. Trade Management Rules

- Cancel the opposite pending order immediately after one bracket leg fills.
- At or after 18:00 broker time, cancel every still-unfilled bracket order for
  this registered magic and symbol.
- Initial stop and target remain authoritative after entry.

## Risk

- Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Symbol slots are fixed by `framework/registry/magic_numbers.csv`:
  EURUSD 0, GBPUSD 1, USDJPY 2, AUDUSD 3, and USDCAD 4.
- No grid, martingale, pyramiding, adaptive sizing, banned indicator, or ML
  component is authorized.

## Parameters to Test

- `strategy_adx_threshold`: 25, 30, 35, 40.
- `strategy_offset_pips`: 10, 15, 20.
- `strategy_tp_pips`: 40, 60, 80.
- `strategy_sl_pips`: 20, 30, 40, subject to the 40-pip cap.

## Framework Alignment

| Card rule | V5 implementation |
|---|---|
| Spread/data block | `Strategy_NoTradeFilter` |
| ADX plus previous-day OCO entries | `Strategy_EntrySignal` |
| OCO and same-day pending-order cancellation | `Strategy_ManageOpenPosition` |
| Fixed SL/TP only | `Strategy_ExitSignal` returns false |

## Validation Expectations

- Q02 must initialize with the registered slot for each host symbol and produce
  a valid MT5 report before any strategy verdict is considered.
- Missing H1/D1 history, an unregistered magic, or an incomplete report is an
  infrastructure failure, not evidence for or against the hypothesis.
- Later gates judge trade density, profitability, robustness, and costs; G0
  approval and compile success do not authorize live use.
