# T_Live EA-Log Warn-Line Classification — 2026-08-22

Router task `2ee15503-e384-4b80-bf4b-6d75e95765e3` (claude, IN_PROGRESS): the warn-line
counts surfaced by `live_book_pulse.py` (`ea_warning_counts`) are aggregate counters only
— nobody had bucketed the underlying lines by cause. This is a **READ-ONLY** classification
pass over the full history of every T_Live EA log, not just the tail slice the pulse
reads.

## Method

- Source: `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/QM5_*_ea-*.log` (25 files, one per live
  sleeve, JSON-lines, full file read — not tail-windowed).
- Every line parsed as JSON; grouped by `(event, first-available-of {reason, retcode,
  declaration, mode} from payload)`.
- Per class: count, % of warn total, distinct EA ids, first/last timestamp, one example
  line, and a relevance tag assigned by reading representative samples and (for the
  dominant and ambiguous classes) tracing the specific ticket/EA across the full log.
- Full breakdown: `2026-08-22_tlive_ea_warn_classification.csv` (same directory).

## Headline numbers

- 81,624 total JSON lines across 25 EA logs; 2 unparseable (negligible, truncated
  trailing writes).
- Level split: 9,282 `INFO`, **72,340 `WARN`**. No `ERROR`/`CRITICAL` lines exist in any
  T_Live EA log.
- 24 distinct `(event, reason)` classes. **One class pair accounts for 72,196 of the
  72,340 warn lines (99.8%)** — everything else is long-tail, 1–45 occurrences each.

## Finding 1 — FLAG: single-incident retry storm, EA 10706 (GBPUSD H1), 2026-07-29

`BROKER_OTHER retcode=10016` (36,098 lines) and `TM_MODIFY reason=MON_SWEEP_BE_LOCK`
(36,098 lines) are two halves of the same event pair, logged once each per attempt. All
72,196 lines trace to **one ticket** (3169417771) on **one EA** (10706), confined to a
single ~4.5h window: 2026-07-29T12:59:58Z → 17:30:18Z. No recurrence before or since (verified
across the full file, not just that window).

What happened: the EA's breakeven-lock sweep tried to move SL/TP on ticket 3169417771 and
the broker rejected every attempt with retcode 10016 ("Invalid stops"), evidently because
the requested SL/TP no longer matched the live price by the time each retry landed. The EA
retried on effectively every tick for 4.5 hours with no backoff and no give-up condition,
producing ~36k duplicate log lines.

- **Historical, not ongoing** — resolved itself (or the position closed) by 17:30 that day
  and has not recurred in the three weeks since.
- **Still a real gap**: nothing in the retry path currently limits attempt frequency or
  gives up after N rejections. Any future position where the broker persistently rejects a
  modify (stale price, spread widening, requote storm) can reproduce this same log flood.
  Recommend a follow-up ops ticket for the TM_MODIFY / MON_SWEEP_BE_LOCK retry path
  (rate-limit or exponential backoff + a hard cap before dropping to a lower-frequency
  retry or alerting) — not urgent, no open position risk was created (a rejected SL/TP
  modify does not open/close a position), but it is the reason "warn count" looks alarming.

## Finding 2 — WORTH_A_LOOK: `EXECUTION_CONTRACT` self-declaration (45 lines, 7 EAs)

Payload carries `"declaration":"DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED"` — the EA is
self-flagging that it runs under a legacy book policy pending requalification. This is a
policy marker, not an error. Cross-reference against the DXZ book requal backlog before
closing; if those 7 EAs (10911, 10919, 10939, 11132, 11421, 12567, 12989) are already
covered by an open requal item, this is fully accounted for.

## Finding 3 — TRACKED: `NEWS_CALENDAR_COVERAGE_GAP` (36 lines, 7 EAs)

Same 7 EAs as Finding 2. This matches the already-active news-backfill initiative
(`project_qm_live_book_news_backfill_2026-08-05` in memory — 17/24 mode=3 unvalidiert).
No new action from this pass; already being worked.

## Finding 4 — everything else (≈45 lines total): IGNORABLE

`TM_OPEN` broker rejections, `BROKER_OTHER` misc retcodes (10027/10036/10029/10013),
`EQUITY_STREAM_STATE_STALE_IGNORED`, `TM_CLOSE`/`TM_REMOVE_PENDING`/`ENTRY_REJECTED` with
strategy-native reasons, and one `FRIDAY_CLOSE_FAILED` line all traced back to expected
live-trading friction or benign-by-design housekeeping. The Friday-close case was traced
ticket-by-ticket: the close succeeded (`TM_CLOSE ok=true retcode=10009`) and the WARN is a
harmless duplicate-close artifact on the same already-closed ticket — no weekend-exposure
hard-rule violation.

## Bottom line

The "11191 warn lines" figure that motivated this task undercounts (a tail-window
artifact of `live_book_pulse.py`'s bounded read); the true full-history count is 72,340,
but 99.8% of that is one resolved, three-week-old retry-storm incident on a single EA/
ticket. Net new actionable items: (1) a low-priority retry-backoff fix for TM_MODIFY/
MON_SWEEP_BE_LOCK, (2) confirm the 7 `EXECUTION_CONTRACT`-flagged EAs are inside the DXZ
legacy-book requal backlog. Nothing here indicates an active operational or risk issue on
T_Live today.

Evidence: `2026-08-22_tlive_ea_warn_classification.csv` (this directory).
