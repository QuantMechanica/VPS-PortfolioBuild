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
markets: [XNGUSD.DWX]
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
modules_used: [calendar-window, donchian-channel, sma-trend-filter, atr-risk, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
target_modules: [framework-init, trade-management, news-gate, friday-close, setfile-risk]
---

# XNG Dry-Production Release-Window Breakout

## hypothesis

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

## rules

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

## 4. entry rules

- Evaluate only once per new D1 bar.
- The prior completed D1 bar must be inside the day-of-month 25-31 production
  window.
- Skip when this magic already has an open `XNGUSD.DWX` position or when this
  EA already entered during the same calendar month.
- Long entry requires compression, bullish signal close, close above the prior
  Donchian high, close above the slow SMA, and rising SMA slope.
- Short entry requires compression, bearish signal close, close below the prior
  Donchian low, close below the slow SMA, and falling SMA slope.
- Skip if the spread exceeds `strategy_max_spread_points`.

## 5. exit rules

- Hard stop: ATR(`strategy_atr_period`) times `strategy_atr_sl_mult`.
- Profit target: ATR(`strategy_atr_period`) times `strategy_atr_tp_mult`.
- Close a long when the prior D1 close falls below the slow SMA or below the
  exit-channel low.
- Close a short when the prior D1 close rises above the slow SMA or above the
  exit-channel high.
- Close after `strategy_max_hold_days` calendar days.
- Framework Friday close and kill switch remain active.

## 6. filters (no-trade module)

- Only `XNGUSD.DWX` D1 is valid.
- Only magic slot 0 is valid.
- Require valid ATR, SMA, channel, compression, and signal OHLC data.
- Reject invalid parameter ranges before entry logic runs.
- Use framework news compliance, kill-switch, magic, and Friday-close guards.

## 7. trade management rules

- Symmetric long/short breakout.
- One open position per magic/symbol.
- No pyramiding, grid, martingale, partial close, trailing stop, ML model, or
  external runtime feed.
- Backtest setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

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

## risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one
`XNGUSD.DWX` setfile. This card does not change T_Live, AutoTrading, deploy
manifests, or portfolio gates.

## Revision History

| Version | Date | Reason | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-07-07 | Initial EIA dry-production structural XNG breakout card | G0 | APPROVED |
