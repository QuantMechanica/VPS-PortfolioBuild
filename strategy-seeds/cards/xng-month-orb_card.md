---
ea_id: QM5_12812
slug: xng-month-orb
type: strategy
source_id: EIA-XNG-MONTH-ORB-2026
strategy_id: EIA-XNG-MONTH-ORB-2026
source_citations:
  - type: government_energy_research
    citation: "U.S. Energy Information Administration, Natural gas consumption, production respond to seasonal changes, Today in Energy, September 24, 2015."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=22892"
    quality_tier: A
    role: primary
  - type: book
    citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990."
    location: "Opening-range breakout concept"
    quality_tier: A
    role: supplement
  - type: exchange
    citation: "CME Group. Henry Hub Natural Gas Futures contract specifications."
    location: "https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.contractSpecs.html"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-XNG-MONTH-ORB-2026]]"
concepts:
  - "[[concepts/natural-gas-seasonality]]"
  - "[[concepts/monthly-opening-range-breakout]]"
  - "[[concepts/henry-hub-monthly-contract-cycle]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [calendar-seasonality, opening-range-breakout, volatility-expansion, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Monthly natural-gas opening-range breakout; estimate 6-12 trades/year after range, SMA, close-location, one-trade-per-month, and spread filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
g0_approval_reasoning: "R1 PASS official EIA natural-gas seasonality source plus Crabel opening-range and CME Henry Hub contract context; R2 PASS deterministic monthly first-five-D1-bar breakout rules; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
expected_pf: 1.12
expected_dd_pct: 20.0
---

# XNG Monthly Opening Range Breakout

## Source

- Primary source: U.S. Energy Information Administration, "Natural gas
  consumption, production respond to seasonal changes", Today in Energy,
  September 24, 2015, https://www.eia.gov/todayinenergy/detail.php?id=22892.
- Supplement: Crabel, Toby. *Day Trading with Short-Term Price Patterns and
  Opening Range Breakout*. Traders Press, 1990.
- Supplement: CME Group, "Henry Hub Natural Gas Futures contract
  specifications", https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.contractSpecs.html.

## Hypothesis

Natural gas has recurring seasonal demand regimes and a listed monthly contract
cycle. This card does not forecast weather, storage, or futures curves. It asks
whether the first five completed D1 bars of each broker-calendar month form a
useful structural reference for `XNGUSD.DWX` volatility expansion.

The mechanical expression is symmetric: after the monthly opening range is
formed, buy a close above the range in an uptrend or sell a close below the
range in a downtrend. Exit on failed breakout, SMA failure, month change, max
hold, ATR stop, or ATR target.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, or short-horizon pullback
  logic.
- `QM5_12575_eia-xng-season`, `QM5_12702` through `QM5_12706`, and other XNG
  seasonal sleeves: not a fixed winter/summer/shoulder directional calendar map.
- `QM5_12584`, `QM5_12744`, and `QM5_12761`: no storage-report event timing.
- `QM5_12588_eia-xng-sum-sqz`: not Bollinger squeeze logic.
- `QM5_12804_xng-tsmom12m-atr` and `QM5_12807_xng-52w-anchor`: not long-horizon
  time-series momentum or 52-week anchor momentum.
- `QM5_12733_xti-xng-xmom` and `QM5_12578_eia-oilgas-ratio`: not an XTI/XNG
  basket or relative-value spread.

## Markets And Timeframe

- Target symbol: `XNGUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: about 6-12 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, broker calendar, broker spread, ATR, and
  SMA only. No EIA feed, weather feed, storage feed, power-load feed, futures
  curve, volume, open interest, CSV, API, analyst forecast, or ML model.

## Rules

Entry rules:

- Evaluate only on a new D1 bar.
- Host chart must be `XNGUSD.DWX` on D1 and magic slot 0.
- For the month containing the prior closed D1 bar, identify the first
  `strategy_opening_days` completed D1 bars.
- Define `opening_high` and `opening_low` from those first bars.
- Do not trade until at least one later D1 bar has closed after the opening
  window.
- Require the opening range to be between
  `strategy_min_open_range_atr * ATR(strategy_atr_period)` and
  `strategy_max_open_range_atr * ATR(strategy_atr_period)`.
- Long entry: prior close is above `opening_high +
  strategy_entry_buffer_atr * ATR`, above SMA(`strategy_trend_period`), and
  closes in the top `strategy_min_close_location` fraction of its D1 range.
- Short entry: prior close is below `opening_low -
  strategy_entry_buffer_atr * ATR`, below SMA(`strategy_trend_period`), and
  closes in the bottom range fraction.
- Allow at most one entry package per calendar month.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if `XNGUSD.DWX` spread exceeds `strategy_max_spread_points`.

Exit rules:

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: ATR(`strategy_atr_period`) * `strategy_atr_tp_mult`.
- Exit long if the prior close falls back below the monthly `opening_high` or
  below SMA(`strategy_trend_period`).
- Exit short if the prior close rises back above the monthly `opening_low` or
  above SMA(`strategy_trend_period`).
- Exit any remaining position when the prior closed D1 bar belongs to a new
  calendar month relative to the position open time.
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Skip entries when ATR, SMA, opening range, close location, tick size, or
  prices are unavailable.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_opening_days
  default: 5
  sweep_range: [3, 5, 7]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_trend_period
  default: 80
  sweep_range: [50, 80, 120]
- name: strategy_min_open_range_atr
  default: 0.60
  sweep_range: [0.45, 0.60, 0.80]
- name: strategy_max_open_range_atr
  default: 5.00
  sweep_range: [4.00, 5.00, 6.50]
- name: strategy_entry_buffer_atr
  default: 0.10
  sweep_range: [0.05, 0.10, 0.15]
- name: strategy_min_close_location
  default: 0.56
  sweep_range: [0.55, 0.56, 0.62]
- name: strategy_atr_sl_mult
  default: 3.25
  sweep_range: [2.50, 3.25, 4.00]
- name: strategy_atr_tp_mult
  default: 5.00
  sweep_range: [4.00, 5.00, 6.50]
- name: strategy_max_hold_days
  default: 12
  sweep_range: [8, 12, 18]
- name: strategy_max_spread_points
  default: 1500
  sweep_range: [1000, 1500, 2200]

## Author Claims

The sources are used for structural lineage around natural-gas seasonality,
monthly Henry Hub contract structure, and opening-range breakouts. No source
performance number is imported into QM. Q02 and later phases must validate
whether the deterministic price-only realization has edge on Darwinex
`XNGUSD.DWX` bars.

## Risk

- expected_pf: 1.12.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 6-12 trades/year.
- risk_class: high for natural-gas volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA natural-gas seasonality source, Crabel
  opening-range source, and CME Henry Hub contract context.
- [x] R2 mechanical: fixed first-five-D1-bar monthly opening range, ATR/SMA
  confirmation, fixed ATR stop/target, time stop, and month-end exit.
- [x] R3 testable: `XNGUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: XNG monthly opening-range breakout is not existing XNG
  seasonal, storage, event, weekend, squeeze, 52-week, momentum/reversal, RSI,
  XTI/XNG basket, or metal/index logic.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: monthly opening-range breakout with ATR buffer, SMA trend
  confirmation, close-location confirmation, and one-entry-per-month guard.
- trade_management: failed-breakout exit, SMA failure exit, new-month exit, ATR
  target/stop, and max-hold stale-position exit.
- trade_close: hard ATR stop/target plus deterministic close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-06-30 | initial XNG month-opening range breakout build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-30 | APPROVED | this card |
