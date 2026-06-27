---
ea_id: QM5_12616
slug: tsmom-9m-commodity-xtiusd
type: strategy
source_id: MOP-TSMOM-2012
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. Time Series Momentum. Journal of Financial Economics, 2012. URL https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum"
sources:
  - "[[sources/MOP-TSMOM-2012]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/commodity-trend-premium]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [intermediate-trend, confirmation-filter, atr-hard-stop, monthly-rebalance, symmetric-long-short]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Monthly WTI 9-month time-series-momentum package with 3-month confirmation; estimate 5-10 entries/year when both trend horizons clear the neutral bands."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS published JFE/AQR source; R2 PASS deterministic monthly 9-month return-sign entry with 3-month confirmation and fixed exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.08
expected_dd_pct: 18.0
---

# WTI 9-Month Time-Series Momentum

## Source

- Source: [[sources/MOP-TSMOM-2012]]
- Primary citation: Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H.,
  "Time Series Momentum", Journal of Financial Economics, 2012, URL
  https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum.

## Concept

Time-series-momentum research documents that an asset's own past return can
forecast its next-period directional tendency across futures markets, including
commodities. This card ports that structural premise to the DWX-tradable WTI
CFD using a shorter intermediate energy trend than the existing 12-month WTI
card.

This card is deliberately different from:

- `QM5_12603_wti-tsmom12m`: this card uses a 9-month trend horizon plus a
  3-month same-sign confirmation filter; 12603 uses a pure 12-month monthly
  return-sign signal.
- `QM5_12621_comm-reversal-4wk-xtiusd` and `QM5_12594_yang-wti-reversal`: this
  follows intermediate trend rather than fading WTI overreaction extremes.
- WTI calendar/event sleeves: no weekday, month-of-year, WPSR, hurricane,
  refinery, OPEC, or expiry-window trigger.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Expected trade frequency: approximately 5-10 trades/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 D1 OHLC and broker calendar only; no futures
  curve, inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or
  ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Entry is allowed only on the first D1 bar of a new broker-calendar month.
- Compute the prior closed D1 close, the close
  `strategy_momentum_lookback_d1` completed bars earlier, and the close
  `strategy_confirm_lookback_d1` completed bars earlier.
- Compute log returns for both horizons.
- Long package: BUY XTIUSD.DWX when the 9-month return is greater than
  `strategy_min_abs_return_pct / 100` and the 3-month confirmation return is
  greater than `strategy_confirm_min_abs_return_pct / 100`.
- Short package: SELL XTIUSD.DWX when the 9-month return is less than the
  negative entry threshold and the 3-month confirmation return is less than the
  negative confirmation threshold.
- No entry if an open XTIUSD.DWX position already exists for this EA magic.
- No entry if XTIUSD.DWX spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit any open package on the next monthly rebalance bar before considering a
  fresh package for that month.
- Exit any stale package after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XTIUSD.DWX on D1.
- Skip entries when D1 history is shorter than the momentum and confirmation
  lookbacks plus warmup bars.
- Skip entries when ATR is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_momentum_lookback_d1
  default: 189
  sweep_range: [168, 189, 210]
- name: strategy_confirm_lookback_d1
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_min_abs_return_pct
  default: 1.5
  sweep_range: [0.5, 1.5, 3.0]
- name: strategy_confirm_min_abs_return_pct
  default: 0.5
  sweep_range: [0.0, 0.5, 1.0]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 31
  sweep_range: [21, 31, 45]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No source performance number is imported into QM. The source is used only for
structural lineage around time-series momentum across futures and commodity
markets. The Q02+ pipeline tests the mechanical WTI port on Darwinex
XTIUSD.DWX bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 18
- expected_trade_frequency: approximately 5-10 trades/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: published Journal of Financial Economics/AQR paper
  page with single-source lineage.
- [x] R2 mechanical: fixed monthly rebalance, 9-month return-sign direction,
  3-month same-sign confirmation, ATR hard stop, and deterministic time exits.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: shorter confirmed intermediate WTI trend, not pure
  12-month trend, not WTI reversal, not WTI calendar/event logic, not XNG, and
  not RSI commodity pullback.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX guard, parameter guard, spread cap, and monthly
  rebalance gate.
- trade_entry: monthly 9-month D1 return-sign package confirmed by 3-month
  same-sign return.
- trade_management: monthly package flattening and max-hold stale-position exit.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural WTI 9-month TSMOM build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
