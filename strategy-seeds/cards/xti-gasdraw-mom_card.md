---
ea_id: QM5_13039
slug: xti-gasdraw-mom
type: strategy
strategy_id: EIA-GASDRAW-XTI-MOM-2026_S01
source_id: EIA-GASDRAW-XTI-MOM-2026
source_citation: "U.S. Energy Information Administration weekly gasoline stocks and Weekly Petroleum Status Report pages."
strategy_type_flags: [official-release-window, gasoline-inventory-pressure, structural-demand, trend-filter-ma, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13039_XTI_GASDRAW_MOM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Driving-season WPSR proxy reaction setup; estimate 4-10 entries/year before Q02."
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
---

# XTI Gasoline Draw Pressure Momentum

## Hypothesis

Weekly gasoline stocks are part of the official EIA Weekly Petroleum Status
Report source family. During the May-August U.S. driving-season demand window,
a gasoline-stock draw pressure shock can transmit into WTI when the D1 oil bar
reacts strongly after a short pullback. The test is structural and price-only at
runtime: it uses the official gasoline-stock series as source lineage, then
mechanizes the `XTIUSD.DWX` D1 release-window reaction without ingesting EIA
files, web pages, APIs, or external calendars.

This is intentionally different from `QM5_13035_xti-prod-sup-brk`, which trades
a product-supplied demand-proxy Donchian breakout with symmetric seasonal
long/short logic. It is also not a crude-inventory WPSR aftershock/fade/pre-WPSR
rule, not PSM, not DPR, not field production, not import/export, not Cushing,
not refinery utilization, not SPR, not roll/expiry, not month-only WTI, not an
XAU/XAG basket, and not RSI commodity logic.

## Rules

- Universe: `XTIUSD.DWX` only, D1 only, magic slot 0.
- On each new D1 bar, inspect the previous completed D1 bar.
- The inspected bar must be Wednesday or Thursday in broker time, proxying the
  normal WPSR release window.
- The inspected bar must fall in the May-August driving-season pressure window.
- The prior pullback window must show a decline of at least `0.35 * ATR(20)`.
- The signal bar must close bullish, have range at least `0.65 * ATR(20)`, body
  at least `0.20 * ATR(20)`, and close in the upper 35% of its range.
- The signal close must be above `SMA(50)`, and `SMA(50)` must be rising versus
  five completed D1 bars earlier.
- Enter long at market with ATR hard stop and ATR target. No shorts.
- Exit on ATR stop, ATR target, five-calendar-day max hold, close back below
  `SMA(50)`, or seasonal invalidation.

## Risk

Q02 and later backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The build
does not touch any live setfile, `T_Live` manifest, portfolio gate, or
AutoTrading setting. The EA is single-symbol, low-frequency, non-ML, non-grid,
non-martingale, and uses no banned indicators.

## Source Citation

- U.S. Energy Information Administration weekly total gasoline stocks:
  https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WGTSTUS1
- U.S. Energy Information Administration Weekly Petroleum Status Report:
  https://www.eia.gov/petroleum/supply/weekly/
- U.S. Energy Information Administration petroleum data portal:
  https://www.eia.gov/petroleum/data.php
