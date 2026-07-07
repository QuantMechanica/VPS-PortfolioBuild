---
ea_id: QM5_13043
slug: xti-resfuel-mom
type: strategy
strategy_id: EIA-XTI-RESFUEL-MOM-2026
source_id: EIA-XTI-RESFUEL-MOM-2026
source_citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report; Stocks of Residual Fuel Oil; Residual fuel oil glossary and bunker-demand context."
source_citations:
  - type: official_energy_report
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: https://www.eia.gov/petroleum/supply/weekly/
    quality_tier: A
    role: primary
  - type: official_energy_data
    citation: "U.S. Energy Information Administration. Stocks of Residual Fuel Oil."
    location: https://www.eia.gov/dnav/pet/pet_stoc_wstk_a_eppr_sae_mbbl_w.htm
    quality_tier: A
    role: supporting
  - type: official_energy_glossary
    citation: "U.S. Energy Information Administration. Residual fuel oil glossary."
    location: https://www.eia.gov/tools/glossary/index.php?id=residual+fuel+oil
    quality_tier: A
    role: supporting
  - type: official_energy_context
    citation: "U.S. Energy Information Administration. U.S. residual fuel oil demand rose in late 2021."
    location: https://www.eia.gov/todayinenergy/detail.php?id=51298
    quality_tier: A
    role: supporting
strategy_type_flags: [official-release-window, structural-demand, residual-fuel-pressure, bunker-demand, winter-seasonality, pullback-continuation, atr-hard-stop, atr-profit-target, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13043_XTI_RESFUEL_MOM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Winter EIA residual-fuel pressure window after a WPSR proxy reaction; estimate 3-7 entries/year before Q02."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.05
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [calendar-window, closed-bar-reaction, sma-trend-filter, atr-risk, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
target_modules: [framework-init, trade-entry, trade-management, news-gate, friday-close, setfile-risk]
---

# XTI Residual Fuel Pressure Momentum

## Hypothesis

EIA publishes weekly residual fuel oil stock data through the WPSR, and its
residual fuel oil material identifies No. 6/bunker fuel use in vessel
bunkering, industrial processes, electric power, and space heating. EIA also
documents late-year residual fuel demand shocks tied mainly to bunker fuel.
During the November-February winter bunker/industrial/heating demand window, a
strong `XTIUSD.DWX` D1 reaction on the Wednesday/Thursday WPSR proxy window
after a short pullback may continue as the market prices residual-fuel pressure
into the crude complex.

This card uses EIA only as structural lineage. The EA imports no residual fuel
stock or demand data at runtime; it trades deterministic price-only
confirmation on Darwinex `XTIUSD.DWX` D1 bars.

## Non-Duplicate Boundary

This is not `QM5_13042_xti-distdraw-mom`: that sleeve is October-March
distillate/heating-oil stock pressure with a different EIA product family and
different trend defaults. This card is November-February residual fuel
oil/bunker/industrial pressure. It is not `QM5_13039_xti-gasdraw-mom`, which is
May-August gasoline stock pressure. It is not crude inventory momentum,
product-supplied breakout, days-of-supply, refinery, Cushing, DPR, SPR,
import/export, COT, rig-count, OPEC, IEA/STEO, expiry/roll, XAU/XAG, XNG RSI,
or index logic.

## Rules

The strategy is a deterministic long-only D1 reaction model. It checks the
previous completed WPSR proxy bar during the November-February residual-fuel
pressure window, requires a short pullback, bullish range/body/close-location
confirmation, rising `SMA(55)` trend confirmation, and then enters with
ATR-defined stop and target. It uses no external runtime feed and no non-price
indicator beyond the framework ATR/SMA helpers.

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
2. Signal bar and current broker date must be inside the November-February
   residual-fuel pressure window.
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
  November-February season, non-long position mismatch, framework Friday close,
  or kill switch.
- One position per magic/symbol. No pyramiding, grid, martingale, ML, or
  external data calls.

## 6. Filters (No-Trade Module)

- Do not trade any symbol other than `XTIUSD.DWX` or any timeframe other than
  D1.
- Do not trade outside magic slot 0.
- Do not trade outside the November-February residual-fuel pressure window.
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
| `strategy_season_start_month` | 11 | 11 | First residual-fuel winter pressure month |
| `strategy_season_end_month` | 2 | 2 | Last residual-fuel winter pressure month, wrapping year-end |
| `strategy_report_start_dow` | 3 | 3 | Wednesday WPSR proxy start |
| `strategy_report_end_dow` | 4 | 4 | Thursday WPSR proxy end for holiday drift |
| `strategy_pullback_lookback` | 5 | 3-7 | Completed D1 bars used for pre-signal pullback |
| `strategy_min_pullback_atr` | 0.25 | 0.15-0.50 | Minimum pre-signal pullback in ATR units |
| `strategy_sma_period` | 55 | 40-80 | D1 trend filter period |
| `strategy_sma_slope_shift` | 8 | 4-12 | Bars used for SMA slope confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period |
| `strategy_min_range_atr` | 0.55 | 0.40-0.85 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.16 | 0.10-0.30 | Minimum bullish body in ATR units |
| `strategy_min_close_location` | 0.64 | 0.55-0.78 | Minimum close location inside signal bar |
| `strategy_atr_sl_mult` | 2.80 | 2.0-3.6 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.60 | 2.0-4.0 | ATR target distance |
| `strategy_max_hold_days` | 7 | 4-11 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The build does not touch T_Live, AutoTrading, deploy
manifests, or portfolio gates.

## R1-R4 Verdict

- R1 PASS: official EIA WPSR, residual fuel oil stocks, residual fuel oil use,
  and bunker-demand context provide the source family.
- R2 PASS: deterministic D1 entry, exit, stop, spread, season, and trend rules.
- R3 PASS: `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 PASS: no ML, no grid, no martingale, one position per magic/symbol, no
  external runtime feed.

## Pipeline

G0 approved for Q02 on 2026-07-07 by mission-directed commodity/energy sleeve
criteria. Q02 must validate or reject the mechanical Darwinex realization.
Build evidence is `artifacts/qm5_13043_build_result.json`; Q02 enqueue evidence
is `artifacts/qm5_13043_q02_enqueue_20260707.json`.
