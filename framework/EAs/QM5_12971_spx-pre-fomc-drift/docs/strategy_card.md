---
ea_id: QM5_12971
slug: spx-pre-fomc-drift
type: strategy
source_id: CEO-ANOMALY-SLATE-2026-07-03
source_citation: "Lucca, D. & Moench, E. (2015). The Pre-FOMC Announcement Drift. Journal of Finance 70(1) - Federal Reserve Bank of New York staff research: SPX earns ~49bp on average in the 24h before scheduled FOMC announcements, ~80% of the equity premium 1994-2011; follow-ups confirm persistence with regime variation."
sources:
  - "[[sources/CEO-ANOMALY-SLATE-2026-07-03]]"
concepts:
  - "[[concepts/pre-fomc-drift]]"
  - "[[concepts/news-calendar-as-signal]]"
indicators: []
strategy_type_flags: [event-anomaly, calendar-event, low-frequency, long-only, deterministic, news-calendar-signal]
target_symbols: [SP500.DWX]
single_symbol_only: true
period: M30
expected_trade_frequency: "8 scheduled FOMC meetings/year, one 24h hold each; 8 trades/year."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Journal of Finance publication by NY Fed economists; among the most-cited event anomalies in existence. Fixed scheduled events (FOMC calendar), fully deterministic."
r2_mechanical: PASS
r2_reasoning: "Signal source: the LOCAL news-calendar files (D:\\QM\\data\\news_calendar) already used by every EA as a blocker - here inverted into an entry signal: detect the scheduled FOMC (Fed Interest Rate Decision, high-impact USD) timestamp; BUY SP500 24h before it; exit at the announcement bar (BEFORE the release - the anomaly is the drift INTO the event, so the news gate stays satisfied: position closed prior to the blackout window). Deterministic, calendar-data-driven; fail-closed if calendar stale (existing framework primitive)."
r3_data_available: PASS
r3_reasoning: "SP500.DWX M30 covered; news calendar seed maintained at D:\\QM\\data\\news_calendar with staleness guard (max 336h) - the same feed every live EA depends on."
r4_ml_forbidden: PASS
r4_reasoning: "No indicators/ML/grid; event-calendar rule; one position per magic."
pipeline_phase: Q07_FAIL
last_updated: 2026-07-10
research_amendment_status: PIPELINE_STOP_Q07
research_amendment_version: _v2
research_amendment_card: "strategy-seeds/cards/QM5_12971_spx-pre-fomc-drift.md"
expected_pf: 1.40
expected_dd_pct: 10.0
g0_approval_reasoning: "R1 Lucca/Moench JoF; R2 local FOMC calendar 24h entry to pre-blackout exit; R3 SP500.DWX plus 2018-2024 calendar archive; R4 deterministic no ML."
---

# SPX Pre-FOMC Announcement Drift (news calendar as entry signal)

## Edge / Thesis

Lucca & Moench (JoF 2015, NY Fed): the equity premium concentrates in the 24 hours
BEFORE scheduled FOMC announcements. The event times are known in advance and sit in
the SAME news-calendar files our framework already maintains for news-blocking - this
card inverts that infrastructure into a signal source. Position is always closed before
the announcement itself: compliance-clean, gap-safe, and precisely the documented window.

## Mechanics (deterministic)

1. Event detection: scheduled high-impact USD "Fed Interest Rate Decision" entries from
   the local news calendar (fail-closed on stale calendar per framework rule).
2. Entry: BUY SP500.DWX on the M30 bar 24h before the scheduled announcement timestamp.
3. Exit: close on the last M30 bar ending >= 30 min BEFORE the announcement (inside the
   existing pre-news blackout boundary - never holds through the release).
4. One position per magic; RISK_FIXED backtest; the standard news ENTRY gate remains
   active for unrelated events.

## Parameters

- pre_event_entry_hours = 24; pre_event_exit_min = 30 (anomaly-defined)

## G0 Build Coverage

- Source citation: 2015 Journal of Finance Lucca-Moench pre-FOMC drift; local news-calendar signal implementation is the build substrate.
- Entry: Buy SP500.DWX on the M30 bar 24 hours before the scheduled high-impact USD Federal Funds/FOMC event in the local archive.
- Exit: Close on the last M30 bar ending at least 30 minutes before the scheduled announcement, respecting the news blackout.
- Stop: No fixed price stop in the published event-window anomaly; the pre-event hard exit plus V5 risk/kill controls bound exposure.
- Target symbols: SP500.DWX.
- Period: M30.
- Expected trade frequency: about 8 trades/year/symbol.

## Risks / Kill Criteria

Historical-calendar completeness is the make-or-break (backtests need archived FOMC
timestamps 2018-2024). Drift documented to weaken in some post-2015 windows - 8/yr means
Q04 judges on the pooled low-freq path (DL-076). Kill on pooled net PF < 1.0. No window
tuning - the 24h shape is the published anomaly.

## `_v2` Event-Flat Amendment — 2026-07-10

The existing G0 approval remains the `_v1` base lineage. A deduplicated `_v2` research
amendment now freezes the exact `.DWX` realization tested on `T_Export`: buy
`SP500.DWX` H1 at broker 21:00 on D-1, close at broker 20:00 on regular FOMC decision
date D, and retain a fixed 2.0 x prior-D1 ATR(14) emergency stop.

The exploratory same-binary chronology was 25 DEV trades at PF 1.1048, 15 validation
trades at PF 5.64, and 16 untouched-OOS trades at PF 2.03. It used Model 1 and fixed
USD 250 risk, so it is not V5 pipeline evidence. Full rules, counter-evidence, hashes,
and gate requirements are in:

- `strategy-seeds/cards/QM5_12971_spx-pre-fomc-drift.md`
- `docs/research/PRE_FOMC_EVENT_FLAT_DWX_2026-07-10.md`

## Independent FTMO pipeline result — 2026-07-11

The approved `_v2` amendment compiled with 0 errors and 0 warnings and reproduced
deterministically on T4 Model 4: 56 trades, PF 1.50, net +9,485.06, and 6.05% equity
drawdown over 2018-07-02 through 2025-12-31. Re-costing the seven complete years
2019-2025 to the current FTMO snapshot produced PF 1.730277 and at least seven trades
in every year.

Q04, Q05, and Q06 passed. Q07 failed because the five harsh-seed PFs
`1.38/1.47/1.71/1.90/1.48` have 32.75% variance against a 20% hard limit. Q08 and all
later phases were stopped. This amendment has no FTMO book or live-deployment permission.
