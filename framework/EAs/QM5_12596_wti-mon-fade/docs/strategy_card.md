---
ea_id: QM5_12596
slug: wti-mon-fade
type: strategy
source_id: QUAY-WTI-DOW-2019
source_citation: "Quayyum, H. A., et al. Seasonality in crude oil returns. Soft Computing 24, 7857-7873 (2020). DOI https://doi.org/10.1007/s00500-019-04329-0"
sources:
  - "[[sources/QUAY-WTI-DOW-2019]]"
concepts:
  - "[[concepts/crude-oil-day-of-week-seasonality]]"
  - "[[concepts/weekend-effect]]"
indicators:
  - "[[indicators/atr]]"
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly D1 WTI Monday-seasonality sleeve; estimate 45-52 trades/year after broker holidays and framework filters."
expected_trades_per_year_per_symbol: 48
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS peer-reviewed crude-oil seasonality source; R2 PASS deterministic Monday D1 short/next-bar flat rule with ATR stop; R3 PASS XTIUSD.DWX in DWX symbol matrix; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 16.0
---

# WTI Monday Seasonality Fade

## Source

- Source: [[sources/QUAY-WTI-DOW-2019]]
- Primary citation: Quayyum, H. A., et al., "Seasonality in crude oil returns", Soft Computing 24, 7857-7873 (2020), DOI https://doi.org/10.1007/s00500-019-04329-0.

## Concept

Peer-reviewed crude-oil seasonality research reports statistically significant
day-of-week effects in Brent and WTI returns, with Monday returns negative on
average in the studied futures samples. This card isolates the cleanest
single-calendar expression for the QM book: short XTIUSD.DWX only on the
Monday D1 session and flatten on the next D1 bar.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI or short-horizon oscillator pullback.
- `QM5_12563_donchian-turtle-trend-commodity`: not a breakout or trend-following channel.
- `QM5_12576_eia-wti-season`: not monthly petroleum demand seasonality.
- `QM5_12579`, `QM5_12590`, and `QM5_12592`: not WPSR continuation, fade, or pre-event positioning.
- `QM5_12591` and `QM5_12593`: not hurricane-season or refinery-maintenance logic.
- `QM5_12594_yang-wti-reversal`: not medium-term return-extreme reversal.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Expected trade frequency: about 48 trades/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no futures curve,
  inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be Monday.
- Entry direction is short only: SELL XTIUSD.DWX at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open XTIUSD.DWX position already exists for this EA magic.
- No entry if XTIUSD.DWX spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after Monday.
- Also close after `strategy_max_hold_days` calendar days as a stale-position guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XTIUSD.DWX on D1.
- Skip entries when ATR is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Short-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.25
  sweep_range: [1.5, 2.25, 3.0]
- name: strategy_max_hold_days
  default: 1
  sweep_range: [1, 2]
- name: strategy_entry_dow
  default: 1
  sweep_range: [1]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source is used for structural lineage around day-of-week seasonality in WTI
and Brent returns, including the reported negative Monday effect. No source
performance number is imported into QM; the Q02+ pipeline tests the rule on
Darwinex XTIUSD.DWX bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 16
- expected_trade_frequency: approximately 45-52 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed Soft Computing crude-oil seasonality paper.
- [x] R2 mechanical: fixed broker-calendar weekday, single D1 short entry, ATR stop, next-bar exit.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] Non-duplicate: no overlap with existing XNG, XAU/XAG basket, WTI monthly/event/refinery/hurricane/reversal, or RSI commodity sleeves.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX guard, parameter guard, spread cap.
- trade_entry: Monday broker-calendar short entry.
- trade_management: first non-Monday D1 bar and max-hold stale-position exits.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural WTI weekday seasonality build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
