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

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/approved/QM5_13045_xti-netimp-fade_card.md`.

## Hypothesis

EIA publishes weekly U.S. net imports of crude oil and petroleum products
inside the official petroleum data family and WPSR release cycle. Net imports
compress imports, exports, and product flow balance into one structural pressure
measure. Abrupt WPSR-window price reactions to this balance can overshoot on
`XTIUSD.DWX`, especially after a multi-day move has already stretched price far
from a medium D1 mean.

The EA imports no EIA data, CSV, web page, analyst forecast, news feed, or
external calendar at runtime. It trades deterministic price-only confirmation
on Darwinex `XTIUSD.DWX` D1 bars.

## Non-Duplicate Boundary

This is not `QM5_13001_xti-export-flow-brk`, not
`QM5_13026_xti-import-flow-fade`, not broad inventory momentum, not
product-supplied demand breakout, not Cushing/PADD/days-of-supply/refinery/SPR/
DPR/production/gasoline stock/distillate/residual/propane/COT/rig-count/OPEC/
IEA/STEO/expiry/roll logic, not XTI/XNG, not oil-metal, not XAU/XAG, not XNG
RSI, and not index beta.

## Rules

The strategy is a deterministic symmetric D1 mean-reversion model. It checks
the previous completed Wednesday/Thursday WPSR proxy bar, requires an ATR-sized
shock, a same-direction multi-day run, and an SMA-distance stretch, then enters
contrarian toward the SMA. It may consume at most one signal per
broker-calendar month.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The build does not touch T_Live, AutoTrading, deploy
manifests, portfolio gates, or live setfiles.

## Pipeline

G0 approved for Q02 on 2026-07-07 by mission-directed commodity/energy sleeve
criteria. Q02 must validate or reject the mechanical Darwinex realization.

## Evidence

- Build evidence: `artifacts/qm5_13045_build_result.json`.
- Q02 enqueue evidence: `artifacts/qm5_13045_q02_enqueue_20260707.json`.
- Q02 work item: `c69daf2c-6b5c-4377-8b70-5a8734232cae`.
