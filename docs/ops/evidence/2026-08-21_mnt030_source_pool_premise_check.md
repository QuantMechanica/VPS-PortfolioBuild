# MNT-030: premise check — source-ingestion plumbing is not broken

Date: 2026-08-21. Author: Claude (orchestrator, headless cycle). Branch: agents/board-advisor.

## Ticket as routed

"Restore the mailbox/source intake lane end to end so the pending-source pool refills.
Give the source pool and the card backlog SEPARATE health SLOs — today one hides the
other." Premised on `source_pool_drained` reading 0 pending sources.

## What was actually checked

- **Scheduled intake task** (`QM_StrategyFarm_MailboxSourceIntake_Daily`, twice daily —
  06:07 and ~18:00 local) is running cleanly. `D:\QM\reports\sourcing_intake\run_log.txt`
  shows successful runs through 2026-08-21T04:07Z, watermark advancing (714->717),
  runtime 4.6s, 0 unresolved errors.
- **Extraction and dispatch work.** Leads land in `leads.csv` (179 rows) and get judged
  by a headless Codex analyst against the source doctrine; `farmctl add-source` is the
  write path (`farmctl.py:21334`, `def add_source`) and is reachable and functioning.
- **Why the pool read 0**: every mailbox-forwarded lead in the current batch was
  REJECTED (`NO_TRADING_STRATEGY`, `NO_MECHANICAL_RULES`, `NO_STRUCTURAL_EDGE`) or
  DEFERRED (`SOURCE_POLICY` — mostly Reddit links, which the doctrine can't fetch/verify).
  Zero qualifying sources is a **content-supply outcome of the doctrine working as
  designed**, not a broken pipe.
- **The pool has already refilled** — independently, via the content-side ticket
  QM-TODO-20260821-230 (owned by Antigravity/agy). 12 pending sources landed at
  2026-08-21T09:35:16Z–09:35:50Z (books, papers, MQL5 articles, blogs — Radge, Hoffstein,
  Baltas/Kosowski, Lempérière/CFM, etc.), confirmed live in the `sources` table.
- **The two SLOs already exist as separate health rows.** `source_pool_drained`
  (`health.py:1594`, `def chk_source_pool`) and `unbuilt_cards_count`
  (`health.py:1708`, `def chk_unbuilt_cards_count`) are independent checks in the CHECKS
  registry (`health.py:3555`/`3557`) — neither is derived from or masks the other today.
  There is no combined metric to un-conflate.

## Disposition: close as no-defect, not implemented

Per this ticket's own constraint ("if the premise turns out to be wrong, say so and stop
— do not invent work to fill the ticket"): the plumbing MNT-030 asked to restore was never
broken. Implementing a rebuild would be pure churn. The only real gap — mailbox-lane
qualification yield is near zero — is a content/doctrine question already owned by agy's
ticket, not an engineering plumbing task.

No code changed for this ticket.

## Verification

```
python -c "import sqlite3; c=sqlite3.connect(r'D:/QM/strategy_farm/state/farm_state.sqlite');
print(c.execute(\"SELECT status, COUNT(*) FROM sources GROUP BY status\").fetchall())"
# -> [('blocked', 6), ('done', 96), ('pending', 12)]   (2026-08-21, post agy content batch)
```

`D:\QM\reports\sourcing_intake\run_log.txt`, `leads.csv`,
`D:\QM\reports\sourcing_intake\summary_20260821T040707Z.md`.
