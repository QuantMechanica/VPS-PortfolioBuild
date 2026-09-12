# DEC E4 execution — task 49a8c88b (2026-09-12, real UTC)

Task: "DEC E4: apply the OOS-2026 window repair (`repair-oos-window --apply`) once the
calendar backfill covers 2026-01..04; Codex verifies `tester.ini` window before successor
runs." Chained behind E1 (calendar repair); execution record is task `1721f3a1`. Routed
to claude 2026-09-12T08:33:10Z under the same 2026-09-05 OWNER blanket authorization as
`90431302`.

## Precondition check: NOT met, no action taken

Read the active production calendar directly (`D:/QM/data/news_calendar/news_calendar_2015_2025.csv`,
48,718 rows, `datetime` spans 2015-01-01 to 2026-09-12). Confirmed the exact gap named in
`docs/ops/OWNER_VORLAGE_2026-09-05_news_calendar_defect.md` is still present, unchanged:
**zero rows between 2025-04-07 and 2026-07-20** (89 distinct 2025 dates ending
2025-04-07; 48 distinct 2026 dates starting 2026-07-20). The OOS-2026 campaign window
(2026-01-01 to 2026-04-06) falls entirely inside this gap — 0 calendar rows in-window.

This is the same finding recorded 2026-09-05 ("das Kampagnenfenster 2026-01-01..04-06
liegt im Kalenderloch") and 2026-09-07 (E1-D full-scope seal `NOT_READY_FAIL_CLOSED`,
`docs/ops/evidence/2026-09-07_news_calendar_e1d_full_scope_seal.md`: AUD/CAD/EUR/JPY
anchor coverage still failing, no repin has happened). Nothing has changed for this
specific window since then — the B-prime activation (`OWNER-DEC-CALENDAR-CRITERIA-B-PRIME-20260907`)
that unblocked `90431302`'s Q10_NEWS hold releases is a **narrower USD-only, all-timeframe
gate criterion**, not a calendar data backfill; it does not add rows to the CSV and does
not satisfy this task's literal precondition ("once the calendar backfill covers
2026-01..04").

**No `repair-oos-window --apply` attempted.** Running it now would apply the OOS window
fix without real news-event data for the target window — exactly the outcome the 2026-09-05
Vorlage explicitly flagged as unacceptable ("Nachfolgerläufe würden ohne News-Events
messen"). Task `49a8c88b` correctly stays `IN_PROGRESS`, blocked on the calendar backfill,
not on anything within this task's own authority. No `update-task` call made.
