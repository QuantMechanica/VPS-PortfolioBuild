---
ea_id: QM5_12711
slug: commodity-tsmom-dual-6-12
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
strategy_type_flags: [intermediate-trend, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Monthly WTI dual-horizon time-series-momentum package; estimate 5-9 entries/year when six-month and twelve-month trends agree."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS published JFE/AQR time-series-momentum source; R2 PASS deterministic monthly WTI 6m/12m return agreement rule with ATR stop and time exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.08
expected_dd_pct: 18.0
---

# WTI Dual-Horizon Time-Series Momentum

## Source

- Source: [[sources/MOP-TSMOM-2012]]
- Primary citation: Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H.,
  "Time Series Momentum", Journal of Financial Economics, 2012, URL
  https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum.

## Concept

Time-series-momentum research documents that an asset's own past return can
forecast its next-period directional tendency across futures markets, including
commodities. This card ports that structural premise to the DWX-tradable WTI
CFD using a dual-confirmation rule: once per month, trade `XTIUSD.DWX` only
when the prior six-month and twelve-month D1 log returns agree in sign outside
the neutral band.

This is deliberately different from:

- `QM5_12603_wti-tsmom12m`: this card requires six-month confirmation, not a
  pure twelve-month return-sign package.
- `QM5_12616_tsmom-9m-commodity-xtiusd`: this card uses 6m/12m agreement, not
  a 9m primary signal with separate 3m confirmation.
- `QM5_12708_commodity-tsmom-6m`: this card rejects trades when the slower
  twelve-month trend disagrees with the six-month trend.
- WTI calendar/event sleeves: no weekday, month-of-year, WPSR, hurricane,
  refinery, OPEC, or expiry-window trigger.
- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, or short-horizon
  pullback logic.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 5-9 entries/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 D1 OHLC and broker calendar only; no futures
  curve, inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or
  ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Entry is allowed only on the first D1 bar of a new broker-calendar month.
- Compute the prior closed D1 close.
- Compute `fast_momentum = ln(close_recent / close_126_bars_ago)`.
- Compute `slow_momentum = ln(close_recent / close_252_bars_ago)`.
- Long package: BUY `XTIUSD.DWX` if both momentum values are greater than
  `strategy_min_abs_return_pct / 100`.
- Short package: SELL `XTIUSD.DWX` if both momentum values are less than
  `-strategy_min_abs_return_pct / 100`.
- No entry if the two horizons disagree, either horizon is inside the neutral
  band, or an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit any open package on the next monthly rebalance bar before considering a
  fresh package for that month.
- Exit any stale package after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Skip entries when D1 history is shorter than `strategy_slow_lookback_d1` plus
  warmup bars.
- Skip entries when ATR is unavailable.
- Framework news, kill-switch, magic, spread, and Friday-close guards remain
  active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_fast_lookback_d1
  default: 126
  sweep_range: [105, 126, 147]
- name: strategy_slow_lookback_d1
  default: 252
  sweep_range: [210, 252, 294]
- name: strategy_min_abs_return_pct
  default: 1.5
  sweep_range: [0.5, 1.0, 1.5, 3.0]
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
`XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 18
- expected_trade_frequency: approximately 5-9 entries/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: published Journal of Financial Economics/AQR paper
  page with single-source lineage.
- [x] R2 mechanical: fixed monthly rebalance, two fixed return lookbacks, ATR
  hard stop, and deterministic time exits.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: dual six-month and twelve-month trend agreement, not pure
  6m, pure 12m, 9m/3m confirmation, WTI reversal, WTI calendar/event logic,
  XNG, ratio basket, or RSI commodity pullback.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, parameter guard, spread cap, and monthly
  rebalance gate.
- trade_entry: monthly dual-horizon D1 return-sign long/short package.
- trade_management: monthly package flattening and max-hold stale-position
  exit.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-06-28 | initial structural WTI dual-horizon TSMOM build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
