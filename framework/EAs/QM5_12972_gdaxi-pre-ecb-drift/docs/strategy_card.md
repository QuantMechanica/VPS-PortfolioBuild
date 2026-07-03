---
ea_id: QM5_12972
slug: gdaxi-pre-ecb-drift
type: strategy
source_id: CEO-ANOMALY-SLATE-2026-07-03
source_citation: "QuantPedia, 'Uncovering the Pre-ECB Drift and Its Trading Strategy Applications' (https://quantpedia.com/uncovering-the-pre-ecb-drift-and-its-trading-strategy-applications/) - European indices (DAX, STOXX) drift upward on the day BEFORE scheduled ECB press conferences; sibling anomaly of Lucca & Moench (2015, JoF) pre-FOMC drift; Valentin (2022, Lancaster FoFI) documents the ECB announcement-window return structure."
sources:
  - "[[sources/CEO-ANOMALY-SLATE-2026-07-03]]"
concepts:
  - "[[concepts/pre-ecb-drift]]"
  - "[[concepts/news-calendar-as-signal]]"
indicators: []
strategy_type_flags: [event-anomaly, calendar-event, low-frequency, long-only, deterministic, news-calendar-signal]
target_symbols: [GDAXI.DWX]
single_symbol_only: true
period: M30
expected_trade_frequency: "8 scheduled ECB meetings/year, one ~24h hold each; 8 trades/year."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Documented sibling of the JoF-published pre-FOMC drift, specifically on European indices incl. DAX (QuantPedia primary; Lancaster working paper). Scheduled events, deterministic timestamps."
r2_mechanical: PASS
r2_reasoning: "Identical machinery to QM5_12971: local news-calendar entries (ECB Interest Rate Decision, high-impact EUR) as SIGNAL; BUY GDAXI 24h before the scheduled decision, exit >=30min before the announcement (inside blackout boundary - never holds through). Fail-closed on stale calendar."
r3_data_available: PASS
r3_reasoning: "GDAXI.DWX M30 covered; cheap index commission; same calendar feed as the news blocker."
r4_ml_forbidden: PASS
r4_reasoning: "No indicators/ML/grid; event-calendar rule; one position per magic."
pipeline_phase: G0
last_updated: 2026-07-03
expected_pf: 1.35
expected_dd_pct: 10.0
g0_approval_reasoning: "R1 QuantPedia/Valentin pre-ECB lineage; R2 local ECB calendar 24h entry to pre-blackout exit; R3 GDAXI.DWX and archive; R4 deterministic no ML."
---

# GDAXI Pre-ECB Announcement Drift (news calendar as entry signal)

## Edge / Thesis

European indices drift upward in the ~24h before scheduled ECB press conferences -
the documented European sibling of the pre-FOMC drift. Same structural cause
(uncertainty-premium compression into scheduled events), same deterministic shape:
event timestamps are known in advance and live in our existing news-calendar files.

## Mechanics (deterministic)

1. Event: scheduled high-impact EUR "ECB Interest Rate Decision" from the local calendar.
2. Entry: BUY GDAXI.DWX 24h before the scheduled timestamp (M30 closed bar).
3. Exit: last M30 bar ending >= 30 min before the announcement. Never holds through.
4. One position per magic; RISK_FIXED backtest; standard news gate stays active otherwise.

## Parameters

- pre_event_entry_hours = 24; pre_event_exit_min = 30 (anomaly-defined, not tunable)

## G0 Build Coverage

- Source citation: 2022 QuantPedia URL https://quantpedia.com/uncovering-the-pre-ecb-drift-and-its-trading-strategy-applications/ plus ECB announcement-window literature; local news-calendar signal implementation is the build substrate.
- Entry: Buy GDAXI.DWX on the M30 bar 24 hours before the scheduled high-impact EUR Main Refinancing Rate/ECB event in the local archive.
- Exit: Close on the last M30 bar ending at least 30 minutes before the scheduled announcement, respecting the news blackout.
- Stop: No fixed price stop in the event-window anomaly; the pre-event hard exit plus V5 risk/kill controls bound exposure.
- Target symbols: GDAXI.DWX.
- Period: M30.
- Expected trade frequency: about 8 trades/year/symbol.
## Risks / Kill Criteria
Calendar-archive completeness 2018-2024 is the hard dependency (shared with 12971 -
verify once). 8/yr -> DL-076 pooled Q04 path judges. Kill on pooled net PF < 1.0;
no window tuning.


