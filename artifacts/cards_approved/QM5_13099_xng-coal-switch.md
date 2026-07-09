---
ea_id: QM5_13099
slug: xng-coal-switch
type: strategy
strategy_id: EIA-XNG-COAL-SWITCH-2026
source_id: EIA-XNG-COAL-SWITCH-2026
source_citation: "U.S. Energy Information Administration natural-gas fuel-switching and electric-power demand packet. URLs https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php, https://www.eia.gov/todayinenergy/detail.php?id=8450, https://www.eia.gov/todayinenergy/detail.php?id=67725"
source_citations:
  - type: official_agency_explainer
    citation: "U.S. Energy Information Administration. Factors affecting natural gas prices."
    location: "https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php"
    quality_tier: A
    role: primary
  - type: official_agency_article
    citation: "U.S. Energy Information Administration. Electricity generation from coal and natural gas both increased with summer heat."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=8450"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-XNG-COAL-SWITCH-2026]]"
strategy_type_flags: [n-period-min-reversion, calendar-seasonality, trend-filter-ma, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_13099_XNG_COAL_SWITCH_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "At most two accepted entries/year; estimated 0-2 before Q02 validation."
expected_trades_per_year_per_symbol: 2
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "Mission-directed G0 approval: official EIA source, deterministic D1 annual-rank shoulder-season reclaim, XNGUSD.DWX available, and no ML/grid/martingale/external runtime feed."
---

# XNG Coal-Switching Demand-Floor Reclaim

Canonical approved card copy. Full card:
`strategy-seeds/cards/approved/QM5_13099_xng-coal-switch_card.md`.

## Hypothesis

EIA documents that favorable natural-gas prices can increase gas demand and
make gas-fired generation more competitive with coal. The EA tests whether a
bottom-quartile annual XNG price rank finds a demand floor in price-sensitive
spring and early-autumn shoulder windows after a bullish D1 SMA reclaim.

## Rules

Trade `XNGUSD.DWX` D1 long-only. Require the completed bar to be inside the
spring or early-autumn window, rank in the bottom quartile of 252 closes, cross
above SMA(10) from below, print an ATR-sized bullish range, and close in the
upper portion. Permit one accepted entry per season. Exit on ATR stop/target,
rank normalization, SMA failure, max hold, or Friday close.

## Risk

Q02 uses `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live file, AutoTrading
state, deploy manifest, T_Live manifest, portfolio admission, or portfolio gate
is touched. This is not RSI2, six-month symmetric reversal, summer-power,
summer-squeeze, seasonal-short, winter-turn, storage/event, carry, or basket
logic.

