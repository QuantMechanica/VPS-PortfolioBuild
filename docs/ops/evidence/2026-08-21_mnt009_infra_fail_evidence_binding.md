# MNT-009 — atomic evidence binding for new INFRA_FAIL rows

**Date:** 2026-08-21
**Router task:** 95f7c689-0976-4306-9da0-805c7b3e1d9d (priority 76, ops_issue)
**Authority:** Claude (orchestrator) 2026-08-21, four-batch live-state
verification of the 2026-07-28 maintenance ledger.
**Recorder:** Claude (agents/board-advisor)

## Instructed work

MNT-009's earlier iteration already drove terminal rows with `verdict IS
NULL` from 832 to 0 (a DB trigger, `trg_work_items_terminal_requires_verdict_*`).
The remaining measured gap: 70 of the 167 most recent INFRA_FAIL-verdict
`work_items` rows (created after 2026-08-14) had `evidence_path IS NULL`.
Instructed to make runner completion atomic going forward: every terminal
write either binds a canonical `evidence_path` or is explicitly stamped
`EVIDENCE_UNAVAILABLE` with a reason, enforced by a test — legacy backfill of
the 70 rows explicitly out of scope ("low value").

## What was found

No shared "finalize work item" chokepoint exists — terminal writes are nine
independent inline `UPDATE`/`INSERT` statements across `farmctl.py` and
`terminal_worker.py`. Six left `evidence_path` untouched (NULL) on an
`INFRA_FAIL` write; two more had a real gap despite superficially binding
`evidence_path` (a `None`-valued bound parameter, or `COALESCE(?,
evidence_path)` where both sides could be NULL).

## Fix

**New sentinel convention** — `farmctl._evidence_unavailable_sentinel(reason)`
returns `EVIDENCE_UNAVAILABLE:<reason>`. Used wherever a terminal INFRA_FAIL
write has no report to point at (the runner was refused/killed/exhausted
before producing one); a real path is promoted instead wherever one exists
(e.g. a captured MT5 log for a history-lock-storm cap exhaustion, or the raw
run log for a `summary_missing` exhaustion — evidence of what happened even
without a parseable summary).

**Nine call sites fixed**, all now bind either a real path or the sentinel:

| File | Site | Evidence |
|---|---|---|
| `farmctl.py` | `record_work_item_spawn_refusal` | sentinel: `spawn_refusal:<reason>` |
| `farmctl.py` | active-timeout reap | sentinel: `active_timeout:<reap_reason>` (no report exists by definition — the run was killed for lack of progress/exceeding budget; promoting an unverified in-progress path would violate "evidence over claims") |
| `farmctl.py` | fast-failure (worker/terminal died) retries exhausted | sentinel: `<fast_failure>_retries_exhausted` |
| `farmctl.py` | timeout retries exhausted | sentinel: `timeout_retries_exhausted` |
| `terminal_worker.py` | cold-cache retries exhausted | already bound `str(summary_path)` — verified non-None, untouched |
| `terminal_worker.py` | history-lock-storm cap exhausted | promotes captured `transient_infra_evidence_path` (storm log) when present, else sentinel |
| `terminal_worker.py` | `summary_missing` retries exhausted (INFRA_FAIL or INVALID) | promotes `payload["log_path"]` (raw run log) when present, else sentinel |
| `terminal_worker.py` | preflight failure | already writes `preflight_failure.json` unconditionally before the UPDATE — safe, untouched |
| `terminal_worker.py` | log-bomb kill | `COALESCE(?, evidence_path, ?)` — new evidence, else existing column value, else sentinel (closes the case where both were NULL) |

**Two new DB triggers** (mirroring the proven `trg_work_items_terminal_requires_verdict_*`
pattern from the earlier MNT-009 iteration), added to `farmctl.py`'s
`init_db()` schema and mirrored in `reconcile_terminal_work_items.py`'s
independent schema init (`CREATE TRIGGER IF NOT EXISTS`, so re-applying is
idempotent against the live `farm_state.sqlite`):

```sql
CREATE TRIGGER trg_work_items_infra_fail_requires_evidence_update
BEFORE UPDATE OF status, verdict ON work_items
WHEN NEW.status IN ('done', 'failed') AND NEW.verdict = 'INFRA_FAIL'
     AND (NEW.evidence_path IS NULL OR trim(NEW.evidence_path) = '')
BEGIN SELECT RAISE(ABORT, 'terminal INFRA_FAIL work_item requires evidence_path or EVIDENCE_UNAVAILABLE sentinel'); END;
-- + matching BEFORE INSERT trigger
```

**Deliberately scoped to `verdict = 'INFRA_FAIL'` only**, not "any non-null
terminal verdict" as a naive reading of the ticket might suggest. An
exhaustive sweep (`grep` across every `status='done'`/`status='failed'`
write in `tools/strategy_farm`) found several legitimate sentinel verdicts
(`WAITING_INPUT`, `PENDING_RUNNER`, `HARNESS_OK`/`HARNESS_FAIL`) that never
carried an `evidence_path` and were never claimed to. A trigger scoped to
"any verdict" would have broken those call sites too — auditing each is a
separate, unscoped effort. The measured gap (70/167) was specifically about
`INFRA_FAIL`, so the trigger is scoped to match the actual evidence, not
the broadest plausible reading of the ticket.

## Verification

**New test:** `tools/strategy_farm/tests/test_mnt009_infra_fail_evidence_binding.py`
— 6 cases: INFRA_FAIL without evidence_path rejected; with empty-string
evidence_path rejected; with a real path succeeds; with the sentinel
succeeds; non-INFRA terminal verdicts (WAITING_INPUT, PENDING_RUNNER,
INVALID, PASS) are unaffected (confirms the narrow scope); sentinel format
check.

**Failed-before / passes-after**, verified via a fully isolated copy of
`tools/strategy_farm` with `farmctl.py` swapped for the `git show HEAD:...`
(pre-fix) version — no live file was ever reverted in place, since T1–T10
workers and scheduled tasks read `C:\QM\repo` live:

```text
PRE-FIX: UPDATE SUCCEEDED (no evidence_path enforcement) -- confirms trigger absent pre-fix
```

Post-fix: the same UPDATE (`status='failed', verdict='INFRA_FAIL'`, no
`evidence_path`) raises `sqlite3.IntegrityError`.

**Full regression sweep:** every test file in `tools/strategy_farm/tests/`
that references `INFRA_FAIL` and writes `work_items` was run (~34 files,
~480 tests), plus the complete suite (3869 tests): **3859 passed, 10 failed,
1 skipped**. All 10 failures are pre-existing, unrelated hash/binding-drift
assertions against live compiled artifacts (`test_registry_rekey_12784.py`,
`test_execution_contract_lint.py` ×4, `test_dxz_10939_repair_packet.py`,
`test_dxz_12567_xau_repair_packet.py`, `test_prepare_ftmo_book3_q02.py`,
`test_codex_session_supervisor.py`, `test_event_deduplication.py`) — none
reference `work_items`, `evidence_path`, or `INFRA_FAIL`; they compare a
hardcoded expected hash against a live file's current hash and drift with
any real change to that file (registry/compile-manifest/EA-binary state),
independent of this change.

## Existing test fixtures updated (raw SQL, not production code)

These files directly `INSERT`/`UPDATE` `work_items` rows with
`verdict='INFRA_FAIL'` as fixture setup (not exercising the fixed
production call sites) and needed a non-NULL `evidence_path` to satisfy the
new trigger. Each got either a literal sentinel value at the specific
INSERT/row, or (where a shared helper is reused across many tests) an
automatic default so the sentinel is only added for `INFRA_FAIL` rows,
leaving every other call site behaviorally unchanged:

- `tools/strategy_farm/tests/test_mnt009_010_reconciliation.py` — extended
  the existing `legacy_null` drop-trigger-then-reinstall pattern
  (`_insert_work_item`) with a parallel `legacy_evidence_missing` path for
  the new trigger, since two tests intentionally seed a pre-guard historical
  defect to exercise the reconciler.
- `tools/strategy_farm/tests/test_pipeline_view_work_items.py` — `_work_item()`
  auto-fills the sentinel when `verdict == "INFRA_FAIL"` and none given.
- `tools/strategy_farm/tests/test_set_priority_track.py` — same auto-fill
  pattern in `_insert_row()`.
- `tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py`,
  `tools/strategy_farm/tests/test_verdict_taxonomy_ws2.py` — literal
  `evidence_path` column + sentinel added to a direct multi-column INSERT.
- `tools/strategy_farm/tests/test_q09_live_news_diagnostic.py` — three
  UPDATEs given the sentinel; one test's assertion
  (`test_generation_rerun_accepts_authenticated_spawn_refusal_without_summary`)
  was updated from `assertIsNone(predecessor["evidence_path"])` to assert
  the exact new sentinel string, since it exercises the real (now-fixed)
  `record_work_item_spawn_refusal` production path and was pinned to the
  old (broken) NULL behavior.
- `tools/strategy_farm/tests/test_farmctl_cascade.py` — two multi-row
  literal INSERTs given an `evidence_path` column + sentinel for their
  INFRA_FAIL row.
- `tools/strategy_farm/tests/test_priority_track_new_q02.py`,
  `tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py` (4 sites) —
  literal sentinel added to INSERT column lists/parameter tuples.

## What was not done

- No backfill of the 70 pre-existing legacy INFRA_FAIL rows without evidence
  (explicitly out of scope per the ticket).
- No factory start/stop, no terminal64, no reboot; no live DB row mutated
  outside test fixtures.
- No recompile in the active inventory.
- The trigger takes effect on the live `farm_state.sqlite` the next time
  `farmctl.init_db()` runs (idempotent `CREATE TRIGGER IF NOT EXISTS`) — all
  nine production call sites that could trip it were fixed in the same
  commit, so no live write path is left broken by the guard.
