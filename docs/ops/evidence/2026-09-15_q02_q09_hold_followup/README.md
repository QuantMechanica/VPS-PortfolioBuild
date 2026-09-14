# Task 42ff3c7a follow-up: item (3) QM5_12582 root cause, item (4) QM5_10148 backup scan

Read-only follow-up on the 2026-09-13 diagnosis
(`docs/ops/evidence/2026-09-13_cascade_gaps_health/README.md`). No DB writes, no
git operations beyond this evidence commit, no requeue applied.

## (3) QM5_12582 / XNGUSD.DWX — ONINIT_FAILED root cause

Decisive log line (evidence: `D:/QM/reports/work_items/ae468d0f-2d3c-4595-9d49-6b5b00a25f75/QM5_12582/20260907_121520/summary.json`,
`runs[0].tester_log_decisive_lines`):

```
CS  2  14:15:47.277  Tester  tester stopped because OnInit returns non-zero code 1
```

The raw per-tick tester log (`20260907.log`) that would show which
`QM_FrameworkInit` branch returned `false` has since been purged from
`D:/QM/reports/.../raw/run_01/` (only `report.htm` + `tester.ini` remain); the
decisive-line extract above is the only surviving structured evidence.
`execution_identity` in the same summary confirms the run itself was clean:
ex5/mq5/setfile all `source_matches_deployed: true` / `stable_during_run: true`
against their pinned SHAs, and `news_calendar.status: "OK"` (age 8h, max 336h) —
so this was not a binary-drift or stale-calendar INIT failure.

**The actual defect was already found and fixed by a different session before
this diagnosis, but the fix was never compiled in:**

- Commit `65e1641235` (2026-09-11, "fix(QM5_12582): repair stale Q02 framework
  wiring") rewrote `QM5_12582_chan-ng-spring.mq5` (root cause classified as
  `STALE_FRAMEWORK_BINARY_WITH_Q01_CONFORMANCE_DEFECTS` — wrong-symbol source
  literal, Q08 MAE hook ordering, uninitialized `QM_EntryRequest`, news-gate
  placement) and carries a full governed authority artifact:
  `docs/ops/evidence/2026-09-11_qm5_12582_stale_framework_rebuild_authority.json`,
  referencing triage task `d9c3f4a8-dbae-4955-ac36-ef0d166f14e0`.
- That triage task is still `TODO` (unclaimed) in `agent_tasks` as of this
  check. No `compile` work_item for `QM5_12582` was ever created — the
  deployed `.ex5` is unchanged since 2026-06-26
  (`c6d66c602ce572cea369b92353aba0c6a814476733dbf536e9c3db1673786974`), while
  the repaired `.mq5` on disk now hashes to
  `1e0128d5b6745cbbe5d18a99dbd659061f8145907a632509481bbe48898e308a`.
- Attempted `python -X utf8 tools/strategy_farm/farmctl.py enqueue-compile
  QM5_12582_chan-ng-spring --source-repair-authority
  docs/ops/evidence/2026-09-11_qm5_12582_stale_framework_rebuild_authority.json`
  (positional form, so apply-mode by the tool's own semantics): **refused**,
  `ok: false`, reasons `SOURCE_REPAIR_AUTHORITY_INVALID`,
  `EX5_ALREADY_PRESENT`, `WORK_ITEMS_EXIST`, `BUILD_TASK_EXISTS`. Nothing was
  enqueued or written. The exact authority-schema mismatch was not
  root-caused further here (out of this task's scope); the actionable fact is
  that the governed compile path currently self-refuses for this EA and needs
  either the stale `d9c3f4a8` triage task worked or a fresh authority
  artifact regenerated against the current validator.

**Disposition: do NOT canary-requeue QM5_12582/XNGUSD Q02 yet.** Requeuing now
would rerun the *stale, pre-repair* `.ex5` and reproduce the identical
`ONINIT_FAILED` — exactly the blind-requeue the health-check hint and
`INPUTSVALID-PIN` memory warn against. The precondition is the compile, not
the requeue; no requeue command was executed.

QM5_10505/XAUUSD and QM5_20143/EURUSD are unchanged from the 09-13 diagnosis
(repair-first / preflight-first, not canary-eligible); no new evidence found
for either in this pass.

## (4) QM5_10148 / EURNZD.DWX — Q07 `bad1b2f7` aggregate.json restore

Target: `D:/QM/reports/work_items/bad1b2f7-5f19-40e7-90a5-880551e84d27/QM5_10148/Q07/EURNZD_DWX/aggregate.json`
(dir present, empty — confirmed again this pass).

Backup scan performed (read-only):
- `find 'D:/QM' -iname "*backup*" -type d` (top 3 levels) — every hit is either
  a whole-`farm_state.sqlite` snapshot directory
  (`D:/QM/strategy_farm/state/backups`, `D:/QM/strategy_farm/backups`,
  `D:/QM/reports/state/backups`) or an unrelated one-off (news-calendar,
  T_Live preset, console-design, rebaseline, task-XML backups). None mirrors
  `D:/QM/reports/work_items/**`.
- `find 'D:/QM/reports' -ipath "*bad1b2f7*"` — **zero hits** anywhere under
  `D:/QM/reports`, including its own `state/backups`, `rebaseline/*_backups_*`,
  and `maintenance/task_xml_backups` subtrees.
- `D:/QM/backups` (top-level) — empty directory.

**Finding: no backup of this work-item's evidence exists anywhere on this
VPS.** Per-work-item report directories under `D:/QM/reports/work_items/` are
not covered by any backup mechanism found — only `farm_state.sqlite` itself is
snapshotted. The `q09_sealed_plan_hold_disposition_proposal_dryrun.json`
`restore_possible: "unknown_pending_backup_scan"` is now resolved:
**restore is not possible.**

This removes `RESTORE_EVIDENCE_THEN_SEAL` as an option for QM5_10148. The two
remaining dispositions from the 09-13 proposal both require an OWNER decision
id (ROT, ea/symbol candidate disposition) and neither was applied here:
- `RETIRE` (mirrors the QM5_11476 pattern already proposed), or
- an OWNER-scoped append-only Q07→Q08→Q09→Q10_NEWS rebuild superseding the
  held row (a fresh Q07 gets a new work_item id; the existing Q08 hard-bind
  via `promoted_from_work_item=bad1b2f7` would need to be re-pointed, which is
  itself a verdict-lineage edit — ROT).

No apply action taken. Both QM5_11476 and QM5_10148 now need the same class of
OWNER retire/rebuild decision; queued as an Entscheidungsschlange item.
