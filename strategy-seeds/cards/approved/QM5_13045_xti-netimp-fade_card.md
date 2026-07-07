---
ea_id: QM5_13045
slug: xti-netimp-fade
type: strategy
strategy_id: EIA-XTI-NETIMP-FADE-2026
source_id: EIA-XTI-NETIMP-FADE-2026
source_citation: "U.S. Energy Information Administration Weekly Petroleum Status Report and weekly U.S. net imports of crude oil and petroleum products."
source_citations:
  - type: official_energy_report
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: https://www.eia.gov/petroleum/supply/weekly/
    quality_tier: A
    role: primary
  - type: official_energy_data
    citation: "U.S. Energy Information Administration. Weekly U.S. Net Imports of Crude Oil and Petroleum Products."
    location: https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WTTNTUS2
    quality_tier: A
    role: primary_series
  - type: official_energy_explainer
    citation: "U.S. Energy Information Administration. Oil imports and exports."
    location: https://www.eia.gov/energyexplained/oil-and-petroleum-products/imports-and-exports.php
    quality_tier: A
    role: structural_context
strategy_type_flags: [official-release-window, structural-flow-balance, net-imports, shock-fade, sma-mean-reversion, atr-hard-stop, atr-profit-target, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13045_XTI_NETIMP_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Weekly WPSR net-import shock fade, capped to one signal per month; estimate 4-8 entries/year before Q02."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.06
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [official-release-window, closed-bar-overextension, sma-mean-reversion, atr-risk, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
target_modules: [framework-init, trade-entry, trade-management, news-gate, friday-close, setfile-risk]
---

# XTI Net-Import Shock Fade

## Hypothesis

EIA publishes weekly U.S. net imports of crude oil and petroleum products
inside the official petroleum data family and WPSR release cycle. Net imports
compress imports, exports, and product flow balance into one structural pressure
measure. Abrupt WPSR-window price reactions to this balance can overshoot on
`XTIUSD.DWX`, especially after a multi-day move has already stretched price far
from a medium D1 mean.

This card uses EIA only as structural lineage. The EA imports no EIA data, CSV,
web page, analyst forecast, news feed, or external calendar at runtime. It
trades deterministic price-only confirmation on Darwinex `XTIUSD.DWX` D1 bars.

## Non-Duplicate Boundary

This is not `QM5_13001_xti-export-flow-brk`, which is a month-end export-flow
Donchian breakout. It is not `QM5_13026_xti-import-flow-fade`, which is a
first-business-days import-only Donchian non-breakout fade. It is not
`QM5_12988` broad inventory momentum, not `QM5_13035` product-supplied demand
breakout, not Cushing/PADD/days-of-supply/refinery/SPR/DPR/production/gasoline
stock/distillate/residual/propane/COT/rig-count/OPEC/IEA/STEO/expiry/roll
logic, not XTI/XNG, not oil-metal, not XAU/XAG, not XNG RSI, and not index beta.

The edge is narrower: a Wednesday/Thursday WPSR net-import balance shock fade.
It requires an ATR-sized D1 shock bar, a multi-day same-direction extension,
and an SMA-distance stretch, then trades contrarian toward mean reversion. It is
capped to one signal per broker-calendar month.

## Market and Timeframe

- Host symbol: `XTIUSD.DWX`.
- Timeframe: D1 only.
- Magic slot: 0.
- Direction: symmetric long/short.
- Runtime data: native MT5 OHLC, spread, ATR/SMA helpers, broker calendar.

## Rules

Evaluate the previous completed Wednesday/Thursday D1 WPSR proxy bar. Enter a
contrarian position only when the bar is ATR-sized, extends a multi-day run, and
closes far enough from the SMA anchor. Exit via ATR stop, ATR target, SMA
mean-reversion, or max-hold timeout. Consume at most one signal per
broker-calendar month.

## 4. Entry Rules

Evaluate once per new D1 bar, using only the prior completed D1 bar as the
signal bar.

1. Signal bar day-of-week must be Wednesday or Thursday in broker time.
2. Signal bar must have ATR-sized range and body.
3. For a long fade, the signal bar must be bearish, close in the lower portion
   of its range, finish below SMA by the configured ATR distance, and complete a
   same-direction multi-day downside run.
4. For a short fade, the signal bar must be bullish, close in the upper portion
   of its range, finish above SMA by the configured ATR distance, and complete a
   same-direction multi-day upside run.
5. Skip if an open position already exists, this broker-calendar month has
   already been consumed, spread is too wide, or any guardrail input is invalid.

## 5. Exit Rules

- ATR hard stop and ATR profit target are set at entry.
- Exit on max-hold timeout.
- Exit a long when the previous D1 close mean-reverts back to or above SMA.
- Exit a short when the previous D1 close mean-reverts back to or below SMA.
- Exit on non-long/non-short mismatch, framework Friday close, or kill switch.
- One position per magic/symbol. No pyramiding, grid, martingale, ML, or
  external data calls.

## 6. Filters (No-Trade Module)

- Do not trade any symbol other than `XTIUSD.DWX` or any timeframe other than
  D1.
- Do not trade outside magic slot 0.
- Do not trade outside the Wednesday/Thursday WPSR proxy window.
- Do not trade when the spread exceeds `strategy_max_spread_points`.
- Do not trade when V5 news, Friday-close, kill-switch, or input guardrails
  block trading.

## 7. Trade Management Rules

Position sizing is delegated to the V5 framework fixed-risk module using
`RISK_FIXED=1000`. Stops are normalized through framework stop rules.
Management is limited to ATR stop, ATR target, SMA mean-reversion exit, and
time stop.

## Parameters

| param | default | range | meaning |
|---|---:|---|---|
| `strategy_report_start_dow` | 3 | 3 | Wednesday WPSR proxy start |
| `strategy_report_end_dow` | 4 | 4 | Thursday WPSR holiday-drift proxy |
| `strategy_run_lookback` | 5 | 3-8 | Completed D1 bars for same-direction extension |
| `strategy_sma_period` | 50 | 35-80 | D1 mean-reversion anchor |
| `strategy_atr_period` | 20 | 14-30 | ATR period |
| `strategy_min_range_atr` | 0.90 | 0.65-1.20 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.25 | 0.15-0.45 | Minimum signal-bar body in ATR units |
| `strategy_min_sma_distance_atr` | 0.70 | 0.45-1.10 | Minimum signal close distance from SMA |
| `strategy_min_run_atr` | 0.80 | 0.50-1.30 | Minimum multi-day run in ATR units |
| `strategy_low_close_location` | 0.30 | 0.20-0.40 | Max close location for bearish long-fade setup |
| `strategy_high_close_location` | 0.70 | 0.60-0.80 | Min close location for bullish short-fade setup |
| `strategy_atr_sl_mult` | 2.60 | 2.0-3.4 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.10 | 1.5-3.0 | ATR target distance |
| `strategy_max_hold_days` | 5 | 3-8 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The build does not touch T_Live, AutoTrading, deploy
manifests, portfolio gates, or live setfiles.

## R1-R4 Verdict

- R1 PASS: official EIA WPSR and net-imports source lineage.
- R2 PASS: deterministic D1 calendar, overextension, SMA, ATR, spread, stop,
  target, and time-exit rules.
- R3 PASS: `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 PASS: no ML, no grid, no martingale, one position per magic/symbol, and
  no external runtime feed.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap,
  WPSR proxy day, and one-signal-per-month gate.
- trade_entry: WPSR net-import shock overextension fade.
- trade_management: SMA mean-reversion exit and max-hold exit.
- trade_close: ATR stop/target plus deterministic strategy exits and framework
  Friday close.

## Pipeline

G0 approved for Q02 on 2026-07-07 by mission-directed commodity/energy sleeve
criteria. Q02 must validate or reject the mechanical Darwinex realization.

## Evidence

- Build evidence: `artifacts/qm5_13045_build_result.json`.
- Q02 enqueue evidence: `artifacts/qm5_13045_q02_enqueue_20260707.json`.
- Q02 work item: `c69daf2c-6b5c-4377-8b70-5a8734232cae`.
