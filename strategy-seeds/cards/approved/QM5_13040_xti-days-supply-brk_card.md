---
ea_id: QM5_13040
slug: xti-days-supply-brk
type: strategy
strategy_id: EIA-XTI-DAYS-SUPPLY-BRK-2026
source_id: EIA-XTI-DAYS-SUPPLY-BRK-2026
source_citation: "U.S. Energy Information Administration crude oil days-of-supply series and Weekly Petroleum Status Report pages."
strategy_type_flags: [donchian-breakout, trend-filter-ma, atr-hard-stop, time-stop, long-only]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13040_XTI_DAYS_SUPPLY_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly capped WPSR-window tight-cover breakout; estimate 3-8 entries/year before Q02."
expected_trades_per_year_per_symbol: 5
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

# XTI Days-of-Supply Tight-Cover Breakout

## Hypothesis

The EIA crude-oil days-of-supply series measures stock cover rather than
headline barrel inventory alone. This EA uses the official days-of-supply and
WPSR source family as structural lineage, then tests a price-only `XTIUSD.DWX`
D1 proxy for tight-cover breakout continuation.

## Rules

Trade `XTIUSD.DWX` D1 only. Inspect the prior completed Wednesday/Thursday bar,
allow at most one entry per broker-calendar month, require a bullish ATR-sized
upper-close bar, a break above the prior 55-D1 high, close in the upper part of
the 126-D1 close channel, short pullback reclaim, and close above a rising
`SMA(50)`. Enter long with ATR stop/target. Exit on ATR stop, ATR target,
12-day max hold, or close back below `SMA(50)`.

## Risk

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The EA is single-symbol,
low-frequency, non-ML, non-grid, non-martingale, and uses no runtime EIA/web/API
feed. It is not WPSR two-event momentum, one-bar aftershock/fade/pre-event,
field production, product-supplied demand, gasoline-stock pressure, SPR,
Cushing, refinery, hurricane, OPEC/IEA/STEO/DPR/PSM/COT, roll/expiry, XNG,
XAU/XAG, oil-metal, or commodity RSI logic.

## Source Citation

- EIA crude oil days of supply:
  https://www.eia.gov/dnav/pet/PET_SUM_SNDW_A_EPC0_VSD_DAYS_W.htm
- EIA Weekly Petroleum Status Report:
  https://www.eia.gov/petroleum/supply/weekly/
