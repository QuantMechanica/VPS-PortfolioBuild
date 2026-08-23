# MT5 `report.htm` retention: decision-ready finding

- Task ID: `b24d7875-1417-4e75-8452-76e8e9df51ea` (ops_issue, QM-TODO-20260823-506)
- Trigger: OWNER question 2026-08-23 — "are backtests deleted automatically after a while?"
- Author: Claude, orchestration cycle 2026-08-23T12:0x Z
- Verdict: **no automated deletion policy exists for `report.htm`; the answer to the OWNER's question is "no, but old evidence is missing anyway" — a decision is needed, not a bug fix**

## What actually deletes things today (source-verified, not just measured)

Read all three automated purge paths directly; none touch `report.htm`:

- `tools/strategy_farm/reports_log_purge.ps1` (task `QM_StrategyFarm_ReportsLogPurge_12h`) —
  deletes only `*.log` under `D:\QM\reports\work_items\**`, default `RetentionHours=6` plus an
  optional `MaxTreeGB` oldest-first trim. Script header states explicitly: "KEEPS: every .htm
  (reports), .json (metrics), .set (configs), .ini." Verified: 0 DB `evidence_path` rows point at
  `.log`.
- `tools/strategy_farm/prune_workitem_logs.py` (task `QM_WorkItemLogPruner_Daily_0310`) — same
  scope, `.log` only, header states "Keeps: summary.json, report.htm, tester.ini, *.set, *.json,
  *.csv, *.md, *.py."
- `tools/strategy_farm/tester_cache_purge.ps1` — MT5 tester cache directories only, never touches
  `D:/QM/reports`.

So the three scheduled jobs are working exactly as designed and are not the cause of missing
`report.htm` evidence.

## What actually happened (per prior measurement, reused from task payload, not re-derived here)

No `report.htm` survives for any work item older than 2026-07-07 — 20,057 directories / 69 GB
sampled by work-item id: May 0/300, June 0/300, July 87/300, August 240/300. This lines up with
two known one-time manual disk reclaims during D: capacity crises (2026-06-10, 405 GB freed;
2026-07-22, 153.7 GB freed) that removed whole work-item report trees by hand, not through either
documented retention job. Net effect: 17,397 of 110,077 runs (15.8%) still have a native MT5
report; last 30 days ~95%, everything before 2026-06-01 is 0%. Current volume is ~2.5 GB/week
(51,638 `report.htm`/`.html` = 16.78 GB over ~6.7 weeks) — at that rate, keeping every report
forever costs roughly 130 GB/year, small next to the D: crises that were hundreds of GB from
`.log` alone.

## The actual problem

There is no written retention DECISION for `report.htm`. The artifacts that survive do so by
accident (never manually reclaimed) and vanish by accident (caught in an ad-hoc disk-crisis
sweep). Any surface that implies "the archive has the native report" for a pre-2026-06 run is
promising something the system does not actually control. That is a documentation/evidence-trail
integrity gap, not a live incident — nothing is actively bleeding disk right now (both `.log`
purges are working; report growth is ~2.5 GB/week).

## Options (unchanged from task payload, restated for the decision record)

- (a) keep every `report.htm` indefinitely — ~130 GB/year at the current rate.
- (b) keep `report.htm` forever only for runs that reached a PASS or belong to a book candidate;
  age out ordinary FAIL runs.
- (c) compress `report.htm` on ageing (HTML compresses ~10:1) and keep everything.
- (d) status quo: accept the loss, and say so explicitly on every surface that could imply
  otherwise (archive detail pages, cockpit).

## Recommendation

(b) + (c): compress-on-age for the kept set, and only guarantee indefinite retention for
merit-bearing runs (PASS / book-candidate). Merit-bearing evidence is a small minority of the
110,077 runs and is exactly the population a later audit or live-book construction will actually
need to re-open. Ordinary FAIL-run reports are reproducible from the same setfile + seed if ever
needed and do not carry the same evidential weight.

This is a retention-scope decision, not an infra repair — it changes what evidence exists in
perpetuity, which is closer to Autofangregel/OWNER territory than a GRÜN autonomous action under
the standing authorization (`02 Org/Stehende Vollmacht Factory CEO 2026-08-20.md`). No retention
job has been written or changed as part of this task; this document is the decision record for
OWNER to rule on, queued via `docs/ops/OPEN_ITEMS_STATUS.md`.

## Immediate low-risk fix regardless of which option OWNER picks

Any archive/cockpit surface that displays or links a `report.htm` for a pre-2026-06 (or any
already-missing) work item should degrade gracefully (show "no native report retained" instead of
a dead link or blank iframe) rather than implying the evidence still exists. This is a UI/surface
correctness fix, independent of the retention policy decision, and can proceed under GRÜN once
picked up as its own ticket.

## Evidence

- Source read: `tools/strategy_farm/reports_log_purge.ps1`, `tools/strategy_farm/prune_workitem_logs.py`,
  `tools/strategy_farm/tester_cache_purge.ps1` (all three confirmed to exclude `report.htm`/`.htm`).
- Measurement basis: task payload `b24d7875-1417-4e75-8452-76e8e9df51ea`, `measured_2026_08_23`
  block (directory sampling by work-item id, disk-crisis dates, current volume rate).
