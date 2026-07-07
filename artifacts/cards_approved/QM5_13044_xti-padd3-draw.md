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

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/approved/QM5_13044_xti-padd3-draw_card.md`.

## Hypothesis

EIA publishes weekly Gulf Coast PADD 3 crude-oil stock levels excluding the SPR
inside the official petroleum data family and WPSR tables. This card tests a
price-only `XTIUSD.DWX` D1 proxy for Gulf Coast crude-stock draw pressure:
inside April-October, a Wednesday/Thursday WPSR-window bullish reclaim after a
short pullback may continue for several D1 bars.

The EA imports no EIA data, CSV, web page, forecast, or external calendar at
runtime. It uses MT5 OHLC, spread, broker calendar, ATR, SMA, standard V5 news
and Friday-close handling, and one `RISK_FIXED=1000` D1 backtest setfile.

## Non-Duplicate Boundary

This is not broad two-event WPSR inventory momentum, not Cushing delivery-hub
tightness, not product-specific gasoline/distillate/residual/propane/product
supplied, not days-of-supply, PSM, DPR, production, import/export, refinery,
SPR, COT, rig-count, OPEC, IEA/STEO, expiry/roll, XTI/XNG, oil-metal,
XAU/XAG, XNG RSI, or index logic.

## 4. Entry Rules

Evaluate once per new D1 bar, using only the prior completed D1 bar as the
signal bar. The bar must be Wednesday or Thursday in broker time, inside the
April-October Gulf Coast draw-pressure window, bullish, ATR-sized, upper-range,
above a rising SMA, and reclaim the prior short local high after a pullback.
Skip if a position is already open, the monthly signal cap is consumed, spread
is too wide, or any guardrail input is invalid.

## 5. Exit Rules

Exit on ATR stop, ATR target, max-hold timeout, close below SMA, leaving the
April-October season, non-long position mismatch, framework Friday close, or
kill switch. No pyramiding, grid, martingale, ML, or external data calls.

## 6. Filters (No-Trade Module)

Trade only `XTIUSD.DWX` D1 in magic slot 0. Block outside the April-October
season, outside the Wednesday/Thursday WPSR proxy window, when spread exceeds
`strategy_max_spread_points`, or when V5 news, Friday-close, kill-switch, or
input guardrails block trading.

## 7. Trade Management Rules

Position sizing is delegated to the V5 fixed-risk module using
`RISK_FIXED=1000`. Stops are normalized through framework stop rules.
Management is limited to ATR stop, ATR target, time stop, SMA invalidation, and
season invalidation.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The build does not touch T_Live, AutoTrading, deploy
manifests, live setfiles, or portfolio gates.

## Pipeline

G0 approved for Q02 on 2026-07-07 by mission-directed commodity/energy sleeve
criteria. Build evidence is `artifacts/qm5_13044_build_result.json`; Q02
enqueue evidence is `artifacts/qm5_13044_q02_enqueue_20260707.json` with pending
work item `97930e93-bb99-4540-8c4f-bca418f9e46f`.
