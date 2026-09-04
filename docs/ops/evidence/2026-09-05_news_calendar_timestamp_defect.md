# News-calendar timestamp defect — evidence (2026-09-05)

Status: **P0 evidence-integrity finding, verified and quantified.** Repair of the calendar
files and any re-adjudication of news-dependent verdicts are OWNER decisions (ROT).
Containment actions taken under the standing authorization are listed in §7.

Author: Claude (CEO loop, standing OWNER order 2026-09-02). Session
`https://claude.ai/code/session_018TXU36R3wPUNEzGHtsFZpM`.

## 1. Finding

Both production news-calendar files store US 08:30-ET releases roughly 17 hours too early
(previous day, 19:30 or 20:30 UTC) for most of 2015–2025. ADP (08:15 ET), ISM (10:00 ET),
FOMC statements and Fed rate decisions are stored correctly. Rows from 2026-07 onward, which
come from the append-only refresh task, are correct.

| file | role (QM_NewsFilter.mqh:856-857) | rows | instants identical to the other file |
|---|---|---|---|
| `D:\QM\data\news_calendar\news_calendar_2015_2025.csv` | primary (`datetime`) | 48 627 | 46 331 |
| `D:\QM\data\news_calendar\forex_factory_calendar_clean.csv` | secondary (`DateTime_UTC`) | 48 636 | — |

Example (NFP, Friday 2023-02-03 13:30 UTC): both files store `2023-02-02 20:30`. The native
MT5 calendar export stores `1675431000` = 2023-02-03 13:30:00 UTC. The M5 tick-volume footprint
(EURUSD 2629 vs same-slot median 1219; GBPUSD 2685 vs 912) sits on the native instant, not on the
stored one (see the edge-lab scout findings, `docs/research/EDGE_DISCOVERY_PROGRAM_V1_2026-09-04.md` §8).

## 2. Quantification

Script: `tools/strategy_farm/research/quantify_news_calendar_defect.py` (read-only). Outputs in
`docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect/` (`summary.json`,
`native_join_deltas.csv`, `stored_tod_histogram.csv`). Reference: the native export
`D:\QM\mt5\T_Export\MQL5\Files\T_EXPORT_USD_HIGH_2018_2025_NATIVE.csv` (4 189 rows; its column
`broker_time` is TRUE UTC despite its name — the exporter writes `values[i].time` raw).

Join FF-clean ↔ native, USD, 2018–2025, exact event-name map, nearest instant within ±36 h
(2 440 matched rows):

| class | shifted −16/−17 h | exact | within 1 h | other |
|---|---|---|---|---|
| US 08:30-ET releases (20 event names) | **1 176 (78 %)** | 276 | 56 | 2 |
| other USD high-impact | 12 | 683 | 119 | 116 |

Per event: NFP 88/88 shifted, Retail Sales 87/87, Unemployment Rate 88/88, CPI m/m 86/87,
PPI m/m 73/87, Average Hourly Earnings 70/88, Unemployment Claims 301/379, Philly Fed 72/87.
Per year the share is stable (2018: 169/208 … 2024: 160/206; 2025: 47/56).

Stored time-of-day histogram (FF-clean, USD, 08:30-ET class): 2015–2024 each year ≈ 200 rows at
19:30/20:30 UTC versus ≈ 50 at 12:30/13:30; 2023–2024 additionally 26–29 rows at 11:30 (a
separate 1 h EU-vs-US DST seam error); **2026: 31/31 at 12:30 (correct)**.

Coverage hole (both files): **2025-05 through 2026-06 contain zero rows.** 2025-04 is partial.

The primary file's own derived columns contradict its timestamps: 123/126 NFP rows carry
`is_first_friday=0` and `day_of_week=3` (Thursday).

Mechanism: unknown. No producer script exists in the repo; `seed_assets/news_calendar/MANIFEST.md`
records the files as copied on 2026-04-21 from a MetaQuotes `Common\Files\ICT_Quant_Lab\` folder.
`.private/secret_strategy_lab/NEWS_CALENDAR_CORRECTION_2026-07-11.md` already recorded "displaced
NFP and CPI rows" and built a native-export replacement for the private lab; that finding was not
propagated to the factory calendar.

## 3. How the factory consumes the value (code trace, Opus agent, 2026-09-05)

- Every EA passes `TimeCurrent()` (broker time) to `QM_NewsAllowsTrade2` (`framework/templates/EA_Skeleton.mq5:183,222`).
- Tester branch `QM_NewsFilter.mqh:2022`: `utc_time = QM_BrokerToUTC(broker_time)` (`QM_DSTAware.mqh:122-139`,
  −2 h / −3 h by US DST rule). Stored CSV values are parsed verbatim as UTC (`QM_NewsParseDateTimeUTC`
  `:297-320`, header preference `DATETIME_UTC` > `DATETIME` `:646-655`). Comparison
  `event_utc ∈ [utc − after, utc + before]` (`:1106-1127`).
- Consequence in the tester: for the stored `2023-02-02 20:30` the ±30 min blackout falls on
  **Thursday 22:00–23:00 server time**; the true NFP print (Friday 15:30 server) trades unfiltered.
- Window: no separate minute inputs; `qm_news_temporal` maps PRE30 / PRE60 / PRE30_POST30 (default in
  `EA_Skeleton.mq5:56-59`) / PRE60_POST60 / SKIP_DAY (`:1206-1237`). Impact ≥ HIGH, symbol currencies
  only (`QM_NewsEventAffectsSymbol`). `COMPLIANCE_DXZ` adds no window.
- **Live branch is different** (`:1985-2009`): T_Live verdicts come from the native MT5 calendar
  (`CalendarValueHistory`, DL-080); the CSVs only gate OnInit staleness and an advisory coverage
  warning. **Live blocking behaviour is not affected.**
- Q09_NEWS / Q10_NEWS (`q09_news_runner.py:589-599`) set six keys per cell (seed, temporal mode,
  compliance mode, bundle id, expected sha, common-relative path); the EA-side blackout is the only
  consumer. Python reads the CSV only to canonicalise, hash and bound it. Everything derived from the
  bytes (bundle identity, run identity, set-file sha) changes when the file is repaired.
- `framework/scripts/p8_news_driver.py` (allowlisted `P8`) does a Python-side news-day classification
  with its own broker→UTC conversion and is affected the same way.

## 4. Blast radius (measured 2026-09-05 ~23:00Z, read-only DB)

- **Q09_NEWS / Q10_NEWS v4 (news-specific gate):** no PASS-class verdict exists yet (Q09_NEWS: 64
  REVIEW_REQUIRED, 18 PENDING_RUNNER, 1 INVALID_EVIDENCE, 1 CONFIG_LOCKED; Q10_NEWS: 90
  REVIEW_REQUIRED, 66 CONFIG_LOCKED, 39 SUPERSEDED, 2 RETIRE). Pending: 40 Q09_NEWS (all held:
  OOS-2026 campaign), 39 Q10_NEWS (28 held; **11 unheld → now held, §7**).
- **Standard gates (Q02–Q14):** set files mostly do not carry `qm_news_temporal` ("ABSENT" = EA
  input default = PRE30_POST30 per skeleton). Q09 v3: 253 PASS / 35 FAIL (13 PASS with explicit
  mode 3, 235 default). Q10 v3: 40 PASS (22 explicit PRE30_POST30, 3 mode 3, 15 default).
  Q14 KEEP_INCUMBENT: 9 rows (1 explicit PRE30_POST30, 8 default).
- **Material exposure depends on entry timing.** D1 bar-open entries (00:00 server) cannot fall in
  either the wrong Thursday-evening window or the true 13:30Z window, so the defect is practically
  inert for them. Intraday EAs are exposed. Of the 9 Q14 terminal rows, **8 are D1** (11421 EURUSD ×2,
  11422 USDCAD, 13054 XTIUSD, 1537 XAGUSD, 21505 XAGUSD, 20048 XTIUSD, 11910 NZDUSD) and **1 is H1
  with explicit PRE30_POST30 (QM5_10706 GBPUSD tv-mon-ls)**. The per-EA classification of every
  Q09/Q10/Q14 verdict pair (news mode default in the .mq5, entry-timing class, currencies) is
  commissioned as Codex task 72e5884d (report-only).
- **OOS-2026 confirmation campaign** (`oos_2026_confirmation_v1`, window 2026-01-01..04-06): the window
  lies inside the coverage hole; successor runs would measure with no news events at all. The window
  repair (commit 1ac9f653d8) is committed but `repair-oos-window --apply` is deferred.

## 5. Why existing checks missed it

`news_calendar_gate.py` validates bytes, headers, per-row field counts, timestamp FORMAT
(`_parse_event_time:296-305`, tz forced to UTC), sha equality across locations, manifest
self-consistency and file mtime staleness (`MAX_AGE_HOURS = 336`). `news_calendar_repin._assert_plausible`
guards row-count shrink and coverage-date regression. `QM_NewsTesterCalendarSelfTest`
(`QM_NewsFilter.mqh:533-576`) only asserts that at least one event currency matches the symbol.
Nothing checks hour-of-day plausibility, weekday, the file's own `is_first_friday`/`day_of_week`
columns, cross-file event-level agreement, or agreement with the native export or tick-volume
footprints. `NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md` asserts UTC as a spec (not implemented) and
already flagged 7.30 % EU-vs-US DST hour errors and 41.7 % impact disagreement between the files.

## 6. Options (for the OWNER Vorlage; all ROT)

- **A — Repair at source for USD:** rebuild the 2018–2025 USD rows from the anchor-tested native export
  (plus the BLS/Fed official timestamps the private lab already curated); non-USD currencies with the
  documented offset fan or declared as a gap. Backfill the 2025-05..2026-06 hole from the same source.
- **B — Conservative union:** block on the union of stored and native instants (over-blocks, never
  under-blocks; needs no per-row truth; slightly lowers trade counts).
- **C — Detectors regardless:** anchor assertions (NFP first-Friday 08:30 ET, CPI/PPI/retail 08:30 ET,
  FOMC 14:00 ET), internal-consistency check of the primary file's derived columns, cross-file
  event-level comparison, native-export comparison, coverage table. Commissioned as report-only
  Codex task 0f61815f; wiring into pass/fail is an OWNER decision.
- **Re-adjudication scope:** sized by Codex task 72e5884d; the decision which verdict classes to
  re-run (Q10_NEWS v4 pending queue at minimum; intraday Q09/Q10 v3 PASS verdicts; the H1 pair
  10706/GBPUSD) is the OWNER's.

## 7. Containment under the standing authorization (GRÜN, reversible)

- 11 previously unheld pending Q10_NEWS rows held with `NEWS_CALENDAR_TIMESTAMP_DEFECT`
  (49a059da, aa80274f, 1cff016c, 57d8bacd, aece4bcc, 2604a1f0, 86cccb8a, 06b9c0f8, 84c6e9e9, 7bbeef66,
  9639a773; release via `farmctl release-hold`). The 40 Q09_NEWS campaign rows stay under
  `OOS_WINDOW_MISMATCH`.
- `repair-oos-window --apply` deferred (task 1721f3a1 stays IN_PROGRESS).
- Codex tickets: 72e5884d (blast-radius sizing), 0f61815f (detectors, report-only), 683f82ca
  (unrelated: Q08 empty_strategy_params 11179).
- No calendar file, gate criterion, verdict row or T_Live artefact was touched.
