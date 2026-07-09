---
ea_id: QM5_13097
slug: xti-ethanol-reblend
type: strategy
strategy_id: EIA-ETHANOL-REBLEND-XTI-2026
source_id: EIA-ETHANOL-REBLEND-XTI-2026
source_citation: "U.S. Energy Information Administration. Ethanol blending provides another proxy for gasoline demand; U.S. fuel ethanol production continues to grow in 2017; What's in your gasoline? Understanding U.S. motor gasoline formulations; Weekly Petroleum Status Report. URLs https://www.eia.gov/todayinenergy/detail.php?id=13271, https://www.eia.gov/todayinenergy/detail.php?id=32152, https://www.eia.gov/todayinenergy/detail.php?id=67464, https://www.eia.gov/petroleum/supply/weekly/"
source_citations:
  - type: official_agency_article
    citation: "U.S. Energy Information Administration. Ethanol blending provides another proxy for gasoline demand."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=13271"
    quality_tier: A
    role: primary
  - type: official_agency_article
    citation: "U.S. Energy Information Administration. U.S. fuel ethanol production continues to grow in 2017."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=32152"
    quality_tier: A
    role: supporting
  - type: official_agency_article
    citation: "U.S. Energy Information Administration. What's in your gasoline? Understanding U.S. motor gasoline formulations."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=67464"
    quality_tier: A
    role: supporting
  - type: official_agency_data_page
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: "https://www.eia.gov/petroleum/supply/weekly/"
    quality_tier: A
    role: cadence_reference
sources:
  - "[[sources/EIA-ETHANOL-REBLEND-XTI-2026]]"
concepts:
  - "[[concepts/ethanol-blending-gasoline-demand-proxy]]"
  - "[[concepts/spring-gasoline-reblend]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [official-source-lineage, structural-demand, ethanol-blending, spring-reblend, pullback-reclaim, trend-filter-ma, atr-hard-stop, atr-profit-target, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13097_XTI_ETHANOL_REBLEND_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XTI spring ethanol/gasoline reblend pullback-reclaim; estimate 2-7 trades/year after date-window, pullback, SMA reclaim, close-location, spread, and one-position filters."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.10
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS official EIA ethanol/gasoline source packet; R2 PASS deterministic XTIUSD.DWX D1 spring reblend pullback-reclaim rule with SMA reclaim, ATR body/range, close-location, ATR stop/target, time/window/SMA exits, and one-position guard; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
---

# XTI Ethanol Reblend Pullback-Reclaim

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/approved/QM5_13097_xti-ethanol-reblend_card.md`.

## Hypothesis

EIA describes ethanol blending as a proxy for gasoline demand when most gasoline
is E10, notes April ethanol-plant maintenance in the weekly ethanol production
series, and documents the spring/summer gasoline formulation switch. This card
ports that structure to a low-frequency WTI sleeve: buy `XTIUSD.DWX` only after
a late-April to mid-June pullback below the D1 mean is reclaimed with a strong
closed D1 bar.

## Rules

The EA trades `XTIUSD.DWX` on D1 only. It evaluates April 20 through June 15 by
default, requires a prior pullback below SMA, signal-bar SMA reclaim, bullish
ATR-sized range/body, upper-range close, flat-to-rising SMA, and then enters
long with ATR stop/target. It exits on stop, target, time, date-window
invalidation, or close below SMA minus an ATR buffer.

## Risk

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy manifest,
portfolio gate, or AutoTrading setting is touched. This is not generic WPSR
aftershock/fade/pre-event, May-August gasoline-stock momentum, broad driving
season breakout, holiday gasoline fade, RBOB, XTI/XNG, XAU/XAG, XNG RSI, or ML.
