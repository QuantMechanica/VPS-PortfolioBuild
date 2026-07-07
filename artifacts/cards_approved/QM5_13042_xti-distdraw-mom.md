---
ea_id: QM5_13042
slug: xti-distdraw-mom
type: strategy
strategy_id: EIA-XTI-DISTDRAW-MOM-2026
source_id: EIA-XTI-DISTDRAW-MOM-2026
source_citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report; Stocks of Distillate Fuel Oil; Heating Oil explained."
source_citations:
  - type: official_energy_report
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: https://www.eia.gov/petroleum/supply/weekly/
    quality_tier: A
    role: primary
  - type: official_energy_data
    citation: "U.S. Energy Information Administration. Stocks of Distillate Fuel Oil."
    location: https://www.eia.gov/dnav/pet/pet_stoc_wstk_a_epd0_sae_mbbl_w.htm
    quality_tier: A
    role: supporting
  - type: official_energy_explainer
    citation: "U.S. Energy Information Administration. Heating oil explained."
    location: https://www.eia.gov/energyexplained/heating-oil/
    quality_tier: A
    role: supporting
strategy_type_flags: [official-release-window, structural-demand, distillate-stock-pressure, winter-seasonality, pullback-continuation, atr-hard-stop, atr-profit-target, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13042_XTI_DISTDRAW_MOM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Winter EIA distillate-stock pressure window after a WPSR proxy reaction; estimate 4-9 entries/year before Q02."
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
modules_used: [calendar-window, closed-bar-reaction, sma-trend-filter, atr-risk, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
target_modules: [framework-init, trade-entry, trade-management, news-gate, friday-close, setfile-risk]
---

# XTI Distillate Draw Pressure Momentum

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/approved/QM5_13042_xti-distdraw-mom_card.md`.

## Hypothesis

EIA publishes weekly distillate fuel oil stock data in the WPSR, and its
heating-oil material frames distillates as a winter-demand-sensitive petroleum
product. During the October-March heating season, a strong `XTIUSD.DWX` D1
reaction on the Wednesday/Thursday WPSR proxy window after a short pullback may
continue as the market prices tight distillate supply pressure into crude.

This card uses EIA only as structural lineage. The EA imports no distillate
stock data at runtime; it trades deterministic price-only confirmation on
Darwinex `XTIUSD.DWX` D1 bars.

## Non-Duplicate Boundary

This is not `QM5_13039` gasoline-stock summer pressure, not broad winter
distillate breakout/pullback, not crude inventory momentum, not product-supplied
breakout, not Cushing/DPR/SPR/import/export/refinery/OPEC/IEA/expiry logic, not
XAU/XAG, not XNG RSI, and not index beta. Backtests use `RISK_FIXED=1000`, no
external runtime data, no ML, no grid, no martingale, and no live/deploy
manifest changes.

## Rules

The strategy is a deterministic long-only D1 reaction model. It checks the
previous completed WPSR proxy bar during the October-March heating season,
requires a short pullback, bullish range/body/close-location confirmation,
rising `SMA(60)` trend confirmation, and then enters with ATR-defined stop and
target. It uses no external runtime feed and no non-price indicator beyond the
framework ATR/SMA helpers.

## Market and Timeframe

- Host symbol: `XTIUSD.DWX`.
- Timeframe: D1 only.
- Magic slot: 0.
- Direction: long only.
- Runtime data: native MT5 OHLC, spread, ATR/SMA helpers, broker calendar.

## 4. Entry Rules

Evaluate once per new D1 bar, using only the prior completed D1 bar as the
signal bar.

1. Signal bar day-of-week must be Wednesday or Thursday in broker time.
2. Signal bar and current broker date must be inside the October-March
   heating-season window.
3. Signal bar must close bullish with range and body above ATR thresholds.
4. Signal close location must be in the upper portion of the bar.
5. Signal close must be above a rising D1 SMA trend filter.
6. The preceding pullback over the configured lookback must be at least the
   configured ATR fraction.
7. Skip if an open position already exists, this signal day has already been
   consumed, spread is too wide, or any guardrail input is invalid.

## 5. Exit Rules

- ATR hard stop and ATR profit target are set at entry.
- Exit on max-hold timeout, close below the SMA trend filter, leaving the
  October-March season, non-long position mismatch, framework Friday close, or
  kill switch.
- One position per magic/symbol. No pyramiding, grid, martingale, ML, or
  external data calls.

## 6. Filters (No-Trade Module)

- Do not trade any symbol other than `XTIUSD.DWX` or any timeframe other than
  D1.
- Do not trade outside magic slot 0.
- Do not trade outside the October-March heating-season window.
- Do not trade outside the Wednesday/Thursday WPSR proxy window.
- Do not trade when the spread exceeds `strategy_max_spread_points`.
- Do not trade when V5 news, Friday-close, kill-switch, or input guardrails
  block trading.

## 7. Trade Management Rules

Position sizing is delegated to the V5 framework fixed-risk module using
`RISK_FIXED=1000`. Stops are normalized through framework stop rules. Management
is limited to ATR stop, ATR target, time stop, SMA invalidation, and season
invalidation.

## Parameters

| param | default | range | meaning |
|---|---:|---|---|
| `strategy_season_start_month` | 10 | 10 | First heating-season month |
| `strategy_season_end_month` | 3 | 3 | Last heating-season month, wrapping year-end |
| `strategy_report_start_dow` | 3 | 3 | Wednesday WPSR proxy start |
| `strategy_report_end_dow` | 4 | 4 | Thursday WPSR proxy end for holiday drift |
| `strategy_pullback_lookback` | 4 | 2-6 | Completed D1 bars used for pre-signal pullback |
| `strategy_min_pullback_atr` | 0.30 | 0.20-0.60 | Minimum pre-signal pullback in ATR units |
| `strategy_sma_period` | 60 | 40-90 | D1 trend filter period |
| `strategy_sma_slope_shift` | 5 | 3-10 | Bars used for SMA slope confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period |
| `strategy_min_range_atr` | 0.60 | 0.45-0.90 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.18 | 0.12-0.35 | Minimum bullish body in ATR units |
| `strategy_min_close_location` | 0.66 | 0.55-0.80 | Minimum close location inside signal bar |
| `strategy_atr_sl_mult` | 2.75 | 2.0-3.5 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.50 | 2.0-4.0 | ATR target distance |
| `strategy_max_hold_days` | 6 | 3-10 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The build does not touch T_Live, AutoTrading, deploy
manifests, or portfolio gates.

## Pipeline

G0 approved for Q02 on 2026-07-07 by mission-directed commodity/energy sleeve
criteria. Q02 must validate or reject the mechanical Darwinex realization.
Build evidence is `artifacts/qm5_13042_build_result.json`; Q02 enqueue evidence
is `artifacts/qm5_13042_q02_enqueue_20260707.json` with pending work item
`f1d9d859-f479-4922-b8f8-f66ccb7f6e2a`.
