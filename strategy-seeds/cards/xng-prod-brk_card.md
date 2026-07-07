---
ea_id: QM5_13037
slug: xng-prod-brk
type: strategy
strategy_id: EIA-XNG-DRYPROD-BRK-2026
source_id: EIA-XNG-DRYPROD-BRK-2026
source_citation: "U.S. Energy Information Administration. Natural Gas Monthly; Natural Gas Data; Natural Gas Dry Production table."
source_citations:
  - type: official_energy_report
    citation: "U.S. Energy Information Administration. Natural Gas Monthly."
    location: https://www.eia.gov/naturalgas/monthly/
    quality_tier: A
    role: primary
  - type: official_energy_data
    citation: "U.S. Energy Information Administration. Natural Gas Data."
    location: https://www.eia.gov/naturalgas/data.php
    quality_tier: A
    role: supporting
  - type: official_energy_data
    citation: "U.S. Energy Information Administration. Natural Gas Dry Production table."
    location: https://www.eia.gov/dnav/ng/ng_prod_sum_a_epg0_fpd_mmcf_a.htm
    quality_tier: A
    role: supporting
strategy_type_flags: [official-release-window, structural-supply, channel-breakout, trend-filter-ma, atr-hard-stop, atr-profit-target, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13037_XNG_DRYPROD_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly EIA dry-production release-window compression breakout; estimate 4-9 entries/year before Q02."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.07
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
---

# XNG Dry-Production Release-Window Breakout

## Source Thesis

EIA publishes official monthly natural gas market data including dry natural gas
production. Dry production is a structural supply variable for U.S. natural gas,
separate from weekly storage, weather, LNG export demand, and broad seasonal
calendar effects. This card tests whether `XNGUSD.DWX` D1 compression breaks
near the late-month dry-production release window persist for several bars.

The implementation uses the EIA source only for structural lineage and release
window definition. Runtime signals use only broker D1 OHLC, ATR, SMA, spread,
and the QuantMechanica framework.

## Non-Duplicate Scope

This is not `QM5_12567_cum-rsi2-commodity`: it uses no RSI, oscillator,
pullback, or short-horizon mean-reversion logic. It is also not the existing
XNG storage aftershock/fade/inside-day/pre-event family, not hurricane/freeze
weather risk, not LNG export demand, not broad XNG winter/summer/shoulder
seasonality, not month-opening range, not weekend gap, not XNG COT, not
rig-count, and not an XTI/XNG or gas/metal basket. The source family is monthly
dry production and the signal is a late-month D1 supply-window compression
breakout.

## Mechanical Rules

- Host chart: `XNGUSD.DWX`, `D1`, magic slot 0 only.
- Evaluate only on a new D1 bar.
- The prior completed D1 bar must fall between day-of-month 25 and 31,
  representing the EIA dry-production update window.
- Skip if this EA already has an open position or if it already entered during
  the same calendar month.
- Require the preceding compression range over `strategy_compression_lookback`
  bars, excluding the signal bar, to be less than
  `strategy_max_compression_atr * ATR * sqrt(N)`.
- Long setup: signal close is above its open, above the prior Donchian channel
  high, above the slow SMA, and the SMA is rising.
- Short setup: signal close is below its open, below the prior Donchian channel
  low, below the slow SMA, and the SMA is falling.
- Require signal range and body filters so tiny late-month bars are ignored.
- Enter market in the breakout direction with ATR stop and ATR profit target.
- Exit on stop, target, slow-SMA failure, opposite exit-channel failure,
  maximum-hold timeout, framework Friday close, or kill switch.

## Default Parameters

| Parameter | Default |
|---|---:|
| `strategy_event_day_min` | 25 |
| `strategy_event_day_max` | 31 |
| `strategy_compression_lookback` | 12 |
| `strategy_entry_channel` | 34 |
| `strategy_exit_channel` | 13 |
| `strategy_trend_period` | 80 |
| `strategy_sma_slope_shift` | 5 |
| `strategy_atr_period` | 20 |
| `strategy_max_compression_atr` | 1.05 |
| `strategy_min_signal_range_atr` | 0.80 |
| `strategy_min_body_ratio` | 0.30 |
| `strategy_atr_sl_mult` | 3.25 |
| `strategy_atr_tp_mult` | 4.00 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 2500 |

## R-Rules

- R1 reputable source: PASS. EIA is the official U.S. government energy data
  publisher; the Natural Gas Monthly and dry-production table are official
  source pages.
- R2 mechanical: PASS. Fixed release-window day gate, Donchian/SMA/ATR filters,
  position limiter, ATR stop/target, and time exit are deterministic.
- R3 data available: PASS. `XNGUSD.DWX` is available for MT5 backtest.
- R4 no ML/banned logic: PASS. No ML, grid, martingale, external runtime feed,
  discretionary input, or banned indicator family.

## Risk and Pipeline

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one
`XNGUSD.DWX` setfile. This card does not change T_Live, AutoTrading, deploy
manifests, or portfolio gates.

## Revision History

| Version | Date | Reason | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-07-07 | Initial EIA dry-production structural XNG breakout card | G0 | APPROVED |
