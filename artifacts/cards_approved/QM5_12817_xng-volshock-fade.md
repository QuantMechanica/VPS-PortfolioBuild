---
ea_id: QM5_12817
slug: xng-volshock-fade
type: strategy
strategy_id: EIA-XNG-VOLSHOCK-2026_S01
source_id: EIA-XNG-VOLSHOCK-2026
source_citation: "U.S. Energy Information Administration, Natural Gas Explained: Factors affecting natural gas prices; EIA Natural Gas Weekly Update and Weekly Natural Gas Storage Report."
source_citations:
  - type: official_reference
    citation: "U.S. Energy Information Administration. Natural Gas Explained: Factors affecting natural gas prices."
    location: "https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php"
    quality_tier: A
    role: primary
sources:
  - "[[sources/EIA-XNG-VOLSHOCK-2026]]"
concepts:
  - "[[concepts/natural-gas-volatility]]"
  - "[[concepts/commodity-mean-reversion]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [n-period-min-reversion, atr-hard-stop, time-stop, signal-reversal-exit, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [XNGUSD.DWX]
timeframes: [D1]
single_symbol_only: true
period: D1
expected_trade_frequency: "D1 natural-gas volatility-shock fade; estimate 6-14 entries/year when 3-D1 return shock and SMA/ATR stretch thresholds align."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
expected_pf: 1.08
expected_dd_pct: 24.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
g0_approval_reasoning: "R1 PASS official EIA natural-gas price-factor source; R2 PASS deterministic D1 return-shock and ATR/SMA stretch fade with fixed exits/stops; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/runtime external data."
---

# Natural Gas Volatility-Shock Fade

## Source

- Source packet: `strategy-seeds/sources/EIA-XNG-VOLSHOCK-2026/source.md`.
- Primary source: U.S. Energy Information Administration, Natural Gas
  Explained, "Factors affecting natural gas prices", URL
  https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php.

## Concept

EIA attributes natural-gas price moves to supply/demand, weather, storage,
imports/exports, and expectations. This card expresses that structural
volatility as a low-frequency XNG-only mean-reversion sleeve: after a large
multi-day natural-gas move, fade the move only when price is stretched away
from a D1 SMA by ATR.

This is deliberately not `QM5_12567_cum-rsi2-commodity`: it uses no RSI and is
not a multi-commodity oscillator pullback. It is also not an XNG storage-report
timing rule, month-opening breakout, weekend gap rule, 52-week anchor momentum,
seasonal window, or XTI/XNG basket.

## Market Universe And Timeframe

- Target symbol: `XNGUSD.DWX`.
- Host chart: `XNGUSD.DWX` D1.
- Magic slot: 0.
- Expected trade frequency: about 6-14 entries per year.

## Entry Rules

- Evaluate only once per closed D1 bar.
- Compute the multi-day shock return:
  `100 * ln(close[1] / close[1 + strategy_shock_lookback_d1])`.
- Compute D1 SMA and ATR on the last closed bar.
- Long entry: shock return is at or below
  `-strategy_min_abs_return_pct`, close is below SMA, and the distance from
  SMA is at least `strategy_min_stretch_atr` ATR but not more than
  `strategy_max_stretch_atr` ATR.
- Short entry: shock return is at or above
  `strategy_min_abs_return_pct`, close is above SMA, and the distance from SMA
  is at least `strategy_min_stretch_atr` ATR but not more than
  `strategy_max_stretch_atr` ATR.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Exit a long when the last closed D1 close is back above the SMA.
- Exit a short when the last closed D1 close is back below the SMA.
- Exit after `strategy_max_hold_days` calendar days.
- Framework exits still apply for Friday close, kill-switch, news mode, and SL.

## Stop And Risk

- Backtest risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Stop loss: ATR(`strategy_atr_period`) times `strategy_atr_sl_mult`.
- Optional take profit: ATR(`strategy_atr_period`) times
  `strategy_atr_tp_mult`; set to 0 to disable.
- One open position per `(magic, XNGUSD.DWX)`.
- No grid, martingale, pyramid, partial close, external runtime data, or ML.

## Parameters To Test

- name: strategy_shock_lookback_d1
  default: 3
  sweep_range: [2, 3, 5]
- name: strategy_min_abs_return_pct
  default: 12.0
  sweep_range: [9.0, 12.0, 15.0]
- name: strategy_sma_period
  default: 20
  sweep_range: [15, 20, 30]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_stretch_atr
  default: 1.40
  sweep_range: [1.10, 1.40, 1.80]
- name: strategy_max_stretch_atr
  default: 5.00
  sweep_range: [4.00, 5.00, 6.50]
- name: strategy_atr_sl_mult
  default: 3.25
  sweep_range: [2.50, 3.25, 4.00]
- name: strategy_atr_tp_mult
  default: 2.00
  sweep_range: [0.0, 2.0, 3.0]
- name: strategy_max_hold_days
  default: 8
  sweep_range: [5, 8, 12]

## Strategy Allowability Check

- [x] R1 reputable source: single official EIA source packet.
- [x] R2 mechanical: fixed D1 return shock, SMA/ATR stretch, ATR stop, spread
  cap, SMA reversion exit, and time exit.
- [x] R3 testable: `XNGUSD.DWX` exists in the Darwinex symbol matrix.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, runtime
  external feed, or multiple positions per magic.
- [x] Portfolio intent: standalone energy exposure distinct from the current
  XAU/SP500/NDX/XNG book and distinct from existing XNG RSI/storage/seasonal
  variants.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-06-30 | initial EIA natural-gas volatility-shock fade build | Q02 | ENQUEUED |
