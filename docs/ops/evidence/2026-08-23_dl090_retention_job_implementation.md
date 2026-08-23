# DL-090 implementing job: `report_retention_purge.py` — implementation, test, and verification

- Task ID: `4e67a1a0-37bb-4995-9497-ebf05d35c172` (ops_issue, QM-TODO-20260823-508)
- Decision: `decisions/DL-090_backtest_report_retention_policy.md` (OWNER-ratified 2026-08-23)
- Script: `tools/strategy_farm/report_retention_purge.py`
- Tests: `tools/strategy_farm/tests/test_report_retention_purge.py`
- **Verdict: implementation complete, tested, and dry-run-verified against the live production
  DB. Not yet scheduled and no `--execute` run has ever been performed against real files —
  scheduling/first-execution is an explicit follow-up, not done in this task.**

## What existed already vs. what this task closed

`report_retention_purge.py` was found already written (untracked, uncommitted) in the canonical
checkout at cycle start — classification (`classify()`), quarantine-then-reap deletion
(`quarantine()`/`reap_quarantine()`), and compress-on-age (`compress_kept()`), all dry-run by
default, matching DL-090 §2 (the rule) and §4 (fail-closed requirements) closely. This task's
remaining work was: verify it actually works, add test coverage, find and fix any real bugs, and
produce a decision record for what remains before it can run live.

## Verification performed

1. **Read the full script against DL-090 §2/§4** line by line — rule and fail-closed requirements
   both appear correctly implemented (PASS-family keep, standing-rejection-per-cell keep,
   age-out for superseded/infra/invalid, 30-day min-age, quarantine-before-delete, forbidden-path
   guard for `T_Live`/`reports/state`/`decisions/`, per-class byte logging).
2. **Live read-only dry-run** (`--classify-only`) against the real
   `D:/QM/strategy_farm/state/farm_state.sqlite` — ran cleanly twice (before and after the bug fix
   below), confirming it does not crash or hang against production data volume, and that
   `skip_open_status` is correctly 0 for a factory with no open runs holding a stale artifact:

   | class | count | bytes |
   |---|---:|---:|
   | keep_pass_family | 2,422 | 10.87 GB |
   | keep_standing_rejection | 1,600 | 0.32 GB |
   | keep_unclassified_taxonomy | 116 | 0.14 GB |
   | age_out_infra_invalid | 1,110 | 0.11 GB |
   | age_out_superseded_strategy | 64 | 0.01 GB |
   | skip_open_status | 0 | 0 |

   (Row counts differ between the two runs because the live factory is continuously mutating
   `evidence_path`/report state; this is expected for a read-only snapshot of a live system, not
   an error.)
3. **New pytest suite**, 12/12 passing, entirely against synthetic SQLite + `tmp_path` fixtures —
   the real `D:/QM` paths are never touched by the tests. Coverage: PASS-family/standing-rejection/
   superseded/infra-invalid/unclassified/open-status bucketing, report-file-absence exclusion,
   `.html` variant, forbidden-prefix and outside-root evidence paths, quarantine min-age +
   dry-run-vs-execute, reap aged-only + dry-run + absent-root no-op, compress gzip + already-done
   skip + too-young skip, and the DB-unreachable fail-closed path (`main()` returns exit 2, logs
   `CLASSIFY_FAIL`, zero filesystem action).

## Bug found and fixed

`classify()`'s open-run guard checked only the clean view's derived `status`, but that view
restamps any row carrying a verdict to `done`/`failed` — so an actively `claimed` row that
happens to carry a stale verdict (e.g. an in-flight requeue with a leftover `INFRA_FAIL`) would
have slipped past `skip_open_status` and been classified for age-out. This is a direct violation
of DL-090 §4.6 ("a run still pending/active/claimed is never touched"). Fixed by also selecting
the clean view's `raw_status` and gating on `status in OPEN_STATUSES or raw_status in
OPEN_STATUSES` — strictly safer (only ever moves rows toward keep/skip, never toward age-out), no
change to keep/age-out policy semantics. Currently has zero effect on live classification
(`skip_open_status=0` today) but closes a real fail-closed gap for the moment it matters.

## Known, accepted latent fragility (not fixed — flagged for awareness)

Standing-rejection ordering (`group.sort(key=lambda r: str(r["updated_at"]))`) is a lexicographic
string sort. Correct for the production timestamp shape (uniform ISO-8601 UTC), but would
misorder mixed-offset or non-ISO timestamps if that ever changed upstream. Not touched — no
evidence this affects current data, and a defensive rewrite risks changing behavior without a
concrete failure to test against.

## What is explicitly NOT done in this task

- **No Windows Scheduled Task installed.** No `install_report_retention_purge_scheduled_task.ps1`
  exists yet, unlike the other purge jobs. Cadence and RunAs principal need a decision (daily,
  matching `QM_WorkItemLogPruner_Daily_0310`'s pattern, is the natural default).
- **No `--execute` run has ever been performed.** Every run so far, including the verification
  above, was `--classify-only` (read-only). The quarantine/reap/compress code paths are covered
  by the pytest suite against synthetic fixtures only, not exercised against real files.
- Recommendation for the follow-up: schedule the job daily in its default dry-run mode first (it
  writes a JSON classification summary and logs to `D:/QM/reports/state/report_retention_purge.log`
  without touching any file), observe 2-3 cycles of output for sanity, then flip to `--execute`
  once the counts look stable. This keeps the first live run reversible (quarantine, not
  immediate delete) and observable before committing to it.
