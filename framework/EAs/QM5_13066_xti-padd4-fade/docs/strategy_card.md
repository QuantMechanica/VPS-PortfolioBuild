---
ea_id: QM5_13066
slug: xti-padd4-fade
type: strategy
strategy_id: EIA-XTI-PADD4-FADE-2026
source_id: EIA-XTI-PADD4-FADE-2026
source_citation: "U.S. Energy Information Administration Rocky Mountain (PADD 4) weekly crude-oil stocks excluding SPR and Weekly Petroleum Status Report."
source_citations:
  - type: official_energy_data
    citation: "U.S. Energy Information Administration. Weekly Rocky Mountain (PADD 4) Ending Stocks excluding SPR of Crude Oil."
    location: "https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP41"
    quality_tier: A
    role: primary
  - type: official_energy_report
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: "https://www.eia.gov/petroleum/supply/weekly/"
    quality_tier: A
    role: supporting
strategy_type_flags: [official-release-window, structural-energy, failed-breakout-fade, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13066_XTI_PADD4_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "January-April and September-December Rocky Mountain PADD 4 crude-stock pressure window, Thursday/Friday post-WPSR proxy, D1 failed-upside probe, and one signal per month; estimate 3-6 entries/year before Q02."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
status: APPROVED
g0_approval_reasoning: "Mission-directed commodity/energy sleeve; R1 official EIA Rocky Mountain PADD 4 crude-stock data and WPSR source family; R2 deterministic D1 calendar, failed-upside range probe, SMA downtrend filter, ATR stop/target, spread, and time-exit rules; R3 XTIUSD.DWX D1 data available; R4 no ML, grid, martingale, external runtime feed, or multi-position magic. Non-duplicate versus PADD2/PADD3/PADD5 long stockdraw/squeeze sleeves because this is short-only PADD4 failed-upside fade logic."
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
modules_used: [calendar-window, failed-range-probe, sma-trend-filter, atr-risk, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
target_modules: [framework-init, trade-entry, trade-management, news-gate, friday-close, setfile-risk]
---

# XTI Rocky Mountain PADD 4 Failed-Upside Fade

Build-time copy of `strategy-seeds/cards/approved/QM5_13066_xti-padd4-fade_card.md`.

The strategy is a short-only `XTIUSD.DWX` D1 failed-upside fade derived from
official EIA Rocky Mountain PADD 4 crude-stock data lineage and the WPSR release
family. It enters only in the January-April or September-December PADD 4
pressure windows, only after a Thursday/Friday post-WPSR proxy signal bar, and
only when the D1 failed-upside probe aligns with a falling SMA trend filter.

No external EIA data is read at runtime. The EA uses native MT5 OHLC, spread,
ATR, SMA, broker calendar, and V5 framework controls.
