---
ea_id: QM5_13070
slug: xti-jodi-fade
type: strategy
strategy_id: JODI-OIL-UPDATE-FADE-2026
source_id: JODI-OIL-UPDATE-BRK-2026
source_citation: "JODI-Oil World Database and IEF Monthly Oil & Gas Data Review. URLs https://www.jodidata.org/oil/, https://www.jodidata.org/oil/support/update-calendar.aspx, https://www.ief.org/data/oil-gas-data-review, and https://www.iea.org/about/international-collaborations/joint-organisations-data-initiative"
source_citations:
  - type: official_global_energy_data
    citation: "Joint Organisations Data Initiative. JODI-Oil World Database."
    location: "https://www.jodidata.org/oil/"
    quality_tier: A
    role: primary
  - type: official_release_calendar
    citation: "Joint Organisations Data Initiative. JODI-Oil World Database Update Calendar."
    location: "https://www.jodidata.org/oil/support/update-calendar.aspx"
    quality_tier: A
    role: primary
  - type: official_energy_review
    citation: "International Energy Forum. Oil and Gas Data Review."
    location: "https://www.ief.org/data/oil-gas-data-review"
    quality_tier: A
    role: supporting
  - type: official_institutional_overview
    citation: "International Energy Agency. Joint Organisations Data Initiative overview."
    location: "https://www.iea.org/about/international-collaborations/joint-organisations-data-initiative"
    quality_tier: A
    role: supporting
strategy_type_flags: [official-release-window, structural-energy, global-oil-data, n-period-min-reversion, n-period-max-continuation, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13070_XTI_JODI_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly JODI oil update-window D1 failed-probe fade; estimate 2-6 entries/year after window, Donchian probe/reclaim, SMA mean, spread, and one-entry-per-month filters."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
status: APPROVED
g0_approval_reasoning: "Mission-directed commodity/energy sleeve; R1 PASS official JODI/IEF/IEA global oil data source packet; R2 PASS deterministic monthly date-window proxy, D1 failed Donchian probe/reclaim fade, SMA mean exit, ATR stop/target, spread cap, max-hold exit, and one-entry-per-month guard; R3 PASS XTIUSD.DWX exists in the DWX symbol matrix; R4 PASS no ML, grid, martingale, external runtime feed, or multi-position magic. Non-duplicate versus QM5_13069 because this fades failed JODI-window probes instead of following closing breakouts."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-08
expected_pf: 1.07
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [calendar-window, failed-probe-fade, sma-mean-exit, atr-risk, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
target_modules: [framework-init, trade-entry, trade-management, news-gate, friday-close, setfile-risk]
---

# XTI JODI Monthly Oil Data Failed-Probe Fade

See canonical card at `strategy-seeds/cards/xti-jodi-fade_card.md`.
