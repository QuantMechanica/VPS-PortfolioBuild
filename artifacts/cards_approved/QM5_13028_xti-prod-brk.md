---
ea_id: QM5_13028
slug: xti-prod-brk
type: strategy
strategy_id: EIA-XTI-FIELDPROD-BRK-2026
source_id: EIA-XTI-FIELDPROD-BRK-2026
source_citation: "U.S. Energy Information Administration weekly U.S. field production of crude oil series and Weekly Petroleum Status Report pages. URLs https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCRFPUS2 and https://www.eia.gov/petroleum/supply/weekly/."
source_citations:
  - type: official_data_series
    citation: "U.S. Energy Information Administration. Weekly U.S. Field Production of Crude Oil."
    location: "https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCRFPUS2"
    quality_tier: A
    role: primary
  - type: official_weekly_report
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: "https://www.eia.gov/petroleum/supply/weekly/"
    quality_tier: A
    role: supplement
  - type: official_release_schedule
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report Schedule."
    location: "https://www.eia.gov/petroleum/supply/weekly/schedule.php"
    quality_tier: A
    role: supplement
strategy_type_flags: [official-release-window, narrow-range-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13028_XTI_PROD_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Weekly EIA field-production release-window compression breakout; roughly 4-9 entries/year after WPSR weekday, compression, trend, channel, range, and spread filters."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.08
expected_dd_pct: 19.0
risk_class: medium-high
ml_required: false
---

# XTI Field-Production Compression Breakout

Official EIA weekly field-production source card. Full canonical card lives at
`strategy-seeds/cards/approved/QM5_13028_xti-prod-brk_card.md`.

The EA trades `XTIUSD.DWX` D1 only. It requires a Wednesday/Thursday WPSR proxy
bar, pre-signal compression, SMA trend/slope confirmation, and Donchian
breakout. It uses ATR stop/target, channel/trend/time exits, `RISK_FIXED`
backtest setfiles, no external runtime data, no ML, no grid, and no martingale.

Q01 validation passed on 2026-07-07 (`validate_spec_doc`, `build_check`, and
strict compile all PASS with 0 warnings). Q02 baseline screening is pending as
work item `b967630d-4229-40dd-89ab-8d6263fbe992` on `XTIUSD.DWX`.
