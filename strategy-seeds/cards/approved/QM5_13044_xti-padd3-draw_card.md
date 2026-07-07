---
ea_id: QM5_13044
slug: xti-padd3-draw
type: strategy
strategy_id: EIA-XTI-PADD3-DRAW-2026
source_id: EIA-XTI-PADD3-DRAW-2026
source_citation: "U.S. Energy Information Administration Gulf Coast (PADD 3) weekly crude-oil stocks excluding SPR and Weekly Petroleum Status Report."
source_citations:
  - type: official_energy_data
    citation: "U.S. Energy Information Administration. Weekly Gulf Coast (PADD 3) Ending Stocks excluding SPR of Crude Oil."
    location: https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP31
    quality_tier: A
    role: primary
  - type: official_energy_data_table
    citation: "U.S. Energy Information Administration. Gulf Coast (PADD 3) Stocks of Crude Oil and Petroleum Products."
    location: https://www.eia.gov/dnav/pet/pet_stoc_wstk_dcu_r30_w.htm
    quality_tier: A
    role: supporting
  - type: official_energy_report
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: https://www.eia.gov/petroleum/supply/weekly/
    quality_tier: A
    role: supporting
strategy_type_flags: [official-release-window, structural-energy, pullback-continuation, trend-filter-ma, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13044_XTI_PADD3_DRAW_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "April-October Gulf Coast PADD 3 crude-stock draw pressure window with one signal per month; estimate 3-7 entries/year before Q02."
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

# XTI Gulf Coast PADD 3 Stockdraw Momentum

## Hypothesis

EIA publishes weekly Gulf Coast PADD 3 crude-oil stock levels excluding the SPR
inside the official petroleum data family and WPSR tables. PADD 3 is a refinery,
pipeline, storage, and export-heavy physical crude region, so repeated regional
stock draws can create a different WTI pressure sleeve than national crude
inventory reactions or Cushing delivery-hub tightness.

This card uses EIA only as structural lineage. The EA imports no EIA data,
stock series, CSV, web page, analyst forecast, or external calendar at runtime.
It trades deterministic price-only confirmation on Darwinex `XTIUSD.DWX` D1
bars inside an April-October Gulf Coast draw-pressure window.

## Non-Duplicate Boundary

This is not `QM5_12988_xti-eia-inventory-momentum`, which requires two same-way
WPSR proxy reactions and a broad crude-inventory breakout. It is not Cushing
delivery-hub tightness (`QM5_12828`/`QM5_12829`), not product-specific gasoline,
distillate, residual fuel, propane, product-supplied, or days-of-supply logic,
and not PSM, DPR, field production, import/export, refinery utilization, SPR,
COT, rig-count, OPEC, IEA/STEO, expiry/roll, XTI/XNG, oil-metal, XAU/XAG, XNG
RSI, or index beta.

The edge is narrower: a long-only, monthly-capped Gulf Coast crude-stock draw
pressure proxy that requires a short pullback, a bullish Wednesday/Thursday
WPSR-window reclaim bar, a local high reclaim, and a rising D1 SMA.

## Rules

The strategy is a deterministic long-only D1 reaction model. On each new D1 bar
it inspects the previous completed bar. The signal bar must be Wednesday or
Thursday, inside the April-October PADD 3 draw-pressure season, and the EA may
consume at most one signal per broker-calendar month.

Entry requires:

- a short pullback over the configured lookback;
- a bullish signal bar with ATR-normalized range/body;
- a close in the upper portion of the signal bar;
- a close above a rising `SMA(70)`;
- a close reclaiming the prior short local high;
- spread below the configured cap and no open position for this EA magic.

The EA enters `XTIUSD.DWX` long at market with ATR-defined hard stop and target.
It exits on ATR stop, ATR target, max-hold timeout, close below the SMA trend
filter, leaving the April-October window, framework Friday close, or kill
switch.

## Market and Timeframe

- Host symbol: `XTIUSD.DWX`.
- Timeframe: D1 only.
- Magic slot: 0.
- Direction: long only.
- Runtime data: native MT5 OHLC, spread, ATR/SMA helpers, broker calendar.

## Parameters

| param | default | range | meaning |
|---|---:|---|---|
| `strategy_season_start_month` | 4 | 4 | First Gulf Coast draw-pressure month |
| `strategy_season_end_month` | 10 | 10 | Last Gulf Coast draw-pressure month |
| `strategy_report_start_dow` | 3 | 3 | Wednesday WPSR proxy start |
| `strategy_report_end_dow` | 4 | 4 | Thursday WPSR holiday-drift proxy |
| `strategy_pullback_lookback` | 6 | 4-8 | Completed D1 bars used for pre-signal pullback |
| `strategy_reclaim_lookback` | 3 | 2-5 | Prior local high window reclaimed by signal close |
| `strategy_min_pullback_atr` | 0.35 | 0.20-0.60 | Minimum pre-signal pullback in ATR units |
| `strategy_sma_period` | 70 | 50-90 | D1 trend filter period |
| `strategy_sma_slope_shift` | 8 | 4-12 | Bars used for SMA slope confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period |
| `strategy_min_range_atr` | 0.65 | 0.45-0.90 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.20 | 0.12-0.35 | Minimum bullish body in ATR units |
| `strategy_min_close_location` | 0.68 | 0.58-0.80 | Minimum close location inside signal bar |
| `strategy_atr_sl_mult` | 2.85 | 2.0-3.6 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.70 | 2.0-4.0 | ATR target distance |
| `strategy_max_hold_days` | 8 | 5-12 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The build does not touch T_Live, AutoTrading, deploy
manifests, portfolio gates, or live setfiles.

## R1-R4 Verdict

- R1 PASS: official EIA PADD 3 crude-stock data and WPSR tables.
- R2 PASS: deterministic D1 calendar, pullback, reclaim, SMA, ATR, spread,
  stop, target, and time-exit rules.
- R3 PASS: `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 PASS: no ML, no grid, no martingale, one position per magic/symbol, and
  no external runtime feed.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap,
  April-October season, and one-signal-per-month gate.
- trade_entry: WPSR proxy bar pullback-reclaim momentum with SMA trend filter.
- trade_management: SMA invalidation, season invalidation, max-hold exit.
- trade_close: ATR stop/target plus deterministic strategy exits and framework
  Friday close.

## Pipeline

G0 approved for Q02 on 2026-07-07 by mission-directed commodity/energy sleeve
criteria. Q02 must validate or reject the mechanical Darwinex realization.
