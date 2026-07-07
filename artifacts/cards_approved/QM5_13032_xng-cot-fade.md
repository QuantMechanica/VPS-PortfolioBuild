---
ea_id: QM5_13032
slug: xng-cot-fade
type: strategy
strategy_id: CFTC-COT-XNG-FRI-FADE-2026
source_id: CFTC-COT-RELEASE-2026
source_citation: "U.S. Commodity Futures Trading Commission, Commitments of Traders main page and release schedule. URLs https://www.cftc.gov/MarketReports/CommitmentsofTraders/index.htm and https://www.cftc.gov/MarketReports/CommitmentsofTraders/ReleaseSchedule/index.htm"
strategy_type_flags: [official-release-window, positioning-proxy, mean-reversion, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
period: D1
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.07
expected_dd_pct: 22.0
ml_required: false
---

# XNG COT Friday Positioning Fade

Approved mirror of `strategy-seeds/cards/xng-cot-fade_card.md`.

This single-symbol `XNGUSD.DWX` D1 EA uses the official CFTC Commitments of
Traders release cadence as structural lineage and fades unusually large prior
Friday COT-window proxy bars on the first D1 bar of the next broker week. It
uses no CFTC runtime feed, no COT CSV, no futures curve, no API, no ML, no
grid, no martingale, and no portfolio/live deploy action.

Non-duplicate boundary: not `QM5_12567_cum-rsi2-commodity` because it uses no
RSI/oscillator or multi-commodity pullback rule; not `QM5_13030_xng-cot-mom`
because this fades stretched Friday displacement and does not require Donchian
trend continuation; not XNG rig-count, storage, seasonality, weather, weekend,
or basket logic.
