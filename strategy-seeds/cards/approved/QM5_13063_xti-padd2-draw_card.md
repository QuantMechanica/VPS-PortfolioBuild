---
ea_id: QM5_13063
slug: xti-padd2-draw
type: strategy
strategy_id: EIA-XTI-PADD2-DRAW-2026
source_id: EIA-XTI-PADD2-DRAW-2026
source_citation: "U.S. Energy Information Administration Midwest (PADD 2) weekly crude-oil stocks excluding SPR and Weekly Petroleum Status Report."
source_citations:
  - type: official_energy_data
    citation: "U.S. Energy Information Administration. Weekly Midwest (PADD 2) Ending Stocks excluding SPR of Crude Oil."
    location: https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP21
    quality_tier: A
    role: primary
  - type: official_energy_report
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: https://www.eia.gov/petroleum/supply/weekly/
    quality_tier: A
    role: supporting
strategy_type_flags: [official-release-window, structural-energy, post-release-lag, pullback-continuation, fast-slow-ma-trend-filter, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13063_XTI_PADD2_DRAW_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "April-October Midwest PADD 2 crude-stock draw pressure window, Thursday/Friday post-WPSR lag, and one signal per month; estimate 3-6 entries/year before Q02."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
status: APPROVED
g0_approval_reasoning: "Mission-directed commodity/energy sleeve; R1 official EIA energy-data source family, R2 deterministic closed-bar mechanics, R3 XTIUSD.DWX D1 data available, R4 no ML or banned indicators."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-08
expected_pf: 1.04
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [calendar-window, closed-bar-reaction, sma-trend-filter, atr-risk, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
target_modules: [framework-init, trade-entry, trade-management, news-gate, friday-close, setfile-risk]
---

# XTI Midwest PADD 2 Stockdraw Momentum

## Hypothesis

EIA publishes weekly Midwest PADD 2 crude-oil stock levels excluding the SPR
inside the official petroleum data family and WPSR release cadence. This card
tests a price-only `XTIUSD.DWX` D1 proxy for Midwest storage/refinery draw
pressure: during April-October, a Thursday/Friday post-WPSR bullish reclaim
after a short pullback and within a fast-over-slow D1 uptrend may continue for
several D1 bars.

The EA imports no EIA data, CSV, web page, forecast, or external calendar at
runtime. It uses MT5 OHLC, spread, broker calendar, ATR, SMA, standard V5 news
and Friday-close handling, and one `RISK_FIXED=1000` D1 backtest setfile.

## Non-Duplicate Boundary

This is not QM5_13044 PADD 3 immediate Wednesday/Thursday Gulf Coast
stockdraw momentum. It uses Midwest PADD 2 source lineage, a Thursday/Friday
post-WPSR lag window, a fast-over-slow `SMA(55) > SMA(120)` trend requirement,
and shorter hold/target defaults. It is also not broad two-event WPSR inventory
momentum, not Cushing delivery-hub tightness, not product-specific gasoline,
distillate, residual, propane, or product-supplied logic, not days-of-supply,
PSM, DPR, production, import/export, refinery, SPR, COT, rig-count, OPEC,
IEA/STEO, expiry/roll, XTI/XNG, oil-metal, XAU/XAG, XNG RSI, or index logic.

## 4. Entry Rules

Evaluate once per new D1 bar, using only the prior completed D1 bar as the
signal bar. The signal bar must be Thursday or Friday in broker time, inside
the April-October Midwest draw-pressure window, bullish, ATR-sized,
upper-range, above `SMA(55)`, with `SMA(55) > SMA(120)`, a rising fast SMA,
and a reclaim of the prior short local high after a pullback. Skip if a
position is already open, the monthly signal cap is consumed, spread is too
wide, or any guardrail input is invalid.

## 5. Exit Rules

Exit on ATR stop, ATR target, max-hold timeout, close below the fast SMA,
leaving the April-October season, non-long position mismatch, framework Friday
close, or kill switch. No pyramiding, grid, martingale, ML, or external data
calls.

## 6. Filters (No-Trade Module)

Trade only `XTIUSD.DWX` D1 in magic slot 0. Block outside the April-October
season, outside the Thursday/Friday post-WPSR proxy window, when spread exceeds
`strategy_max_spread_points`, or when V5 news, Friday-close, kill-switch, or
input guardrails block trading.

## 7. Trade Management Rules

Position sizing is delegated to the V5 fixed-risk module using
`RISK_FIXED=1000`. Stops are normalized through framework stop rules.
Management is limited to ATR stop, ATR target, time stop, fast-SMA
invalidation, and season invalidation.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The build does not touch T_Live, AutoTrading, deploy
manifests, live setfiles, or portfolio gates.

## Pipeline

G0 approved for Q02 on 2026-07-08 by mission-directed commodity/energy sleeve
criteria. Build evidence is expected at `artifacts/qm5_13063_build_result.json`
after compilation and Q02 enqueue.
