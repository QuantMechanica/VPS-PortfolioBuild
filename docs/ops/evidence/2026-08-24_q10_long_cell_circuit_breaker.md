# Q10 long-cell circuit breaker — detection + documented hold, never a verdict

- Router task: `cae3df77-89cd-44cb-8a8d-641e1c8068a1` (ops_issue, claude, priority 70)
- Executed: 2026-08-24, from canonical checkout `C:/QM/repo` on `agents/board-advisor`
- Source: `docs/ops/evidence/2026-08-24_throughput_forensics.md` (branch
  `rb-throughput-forensics`), §2 and recommendation 2: "Add a long-cell circuit
  breaker. Flag a Q10 cell for operator review when wall time exceeds
  `max(3 x parent rolling median, configured cell timeout)` and prevent
  unbounded retry occupancy. `13f41983` demonstrates why failure-exhaustion time
  must be reported separately from successful-cell time."

## The failure mode being guarded

Case `13f41983-74c6-4058-8a41-c787633a1391` (Q10_NEWS, QM5_1328 EURJPY, 8-cell
standard matrix) held terminal T6 from 05:25:49Z with **0 receipts**: five cells
retry-exhausted (mean 51.0 min/cell, range 30.7–263.5), three still pending.
Each cell burned its bounded transient-retry budget
(`q09_news_runner.DEFAULT_CELL_RETRY_BUDGET=2` → three attempts →
`cell_failure_3.json` with reasons `INCOMPLETE_RUNS`, `METATESTER_HUNG`,
`MODEL4_MARKER_REQUIRED`, `TIMEOUT` — all inside
`Q09_TRANSIENT_REASON_CLASSES`). The parent consumed a terminal for hours,
never completed, and was never flagged. At the 13:31Z snapshot the row was still
`status='active'`, `verdict=NULL`.

## Scope

**Detection + hold + visibility only.** This change never writes a pipeline
verdict/status on the work item, never alters a gate criterion or the
verdict taxonomy, and never kills an in-flight tester process. It marks a
breaching parent for operator review and stops *new* retry claims. The parent's
real disposition (release, failure classification, OWNER decision) stays with
the operator/pipeline.

## What changed

- `tools/strategy_farm/q10_long_cell_breaker.py` (new):
  - **Threshold** — `long_cell_threshold_seconds(median, configured_timeout)`
    returns `max(3 × parent rolling median, configured cell timeout)`. When the
    parent has no successful cell yet (no median — the `13f41983` shape), it
    collapses to the configured-timeout floor. Floor default = 120 min
    (`DEFAULT_CELL_TIMEOUT_SECONDS = 7200`), matching the documented Q07
    parent-timeout precedent cited in the forensics §2; override via
    `QM_Q10_CELL_TIMEOUT_SECONDS`.
  - **Cell classification** — `scan_cell_timing` reads a cell directory:
    `success` (`cell_receipt.json` present), `exhausted` (retry budget burned,
    `cell_failure_<MAX_FAILURE_OCCURRENCE=3>.json` present), or `inflight`. Wall
    time is measured on artifact **mtimes** on both ends (earliest
    `runs/*/*/<YYYYMMDD_HHMMSS>` dir → terminal artifact, or → now for inflight).
    mtime-on-both-ends deliberately avoids the local-vs-UTC skew the forensics'
    dir-name-string method carries, while measuring the same interval.
  - **Telemetry split** — `split_cell_telemetry` reports
    `success_cell_seconds`, `exhaustion_cell_seconds`, and
    `inflight_cell_seconds` as three **distinct** series with per-series
    medians. A 0-receipt parent's exhaustion time is never folded into or read
    as successful-cell latency (forensics recommendation 2's explicit ask).
  - **Documented hold** — `write_long_cell_hold` inserts a row into the existing
    `work_item_holds` table with `hold_code='Q10_LONG_CELL_BREAKER'`, `active=1`,
    `release_on_restart=0`. The ordinary claim selector filters out any row with
    an active hold (`farmctl.py:1499-1502`, `terminal_worker.py:1847-1850`), so
    the retry chain stops re-claiming the parent once it lands back in `pending`
    — instead of retrying forever. A *different* active hold is never overwritten
    (mirrors `q09_news_schema.hold_until_plan_bound`). Only `work_item_holds` is
    touched; no `work_items` column, no verdict, no status.
  - **Orchestration** — `run(...)` scans active/pending Q10 parents
    (`read_active_q10_parents`, read-only, fails open to `[]`), evaluates each,
    and in `--apply` mode writes holds for breaching parents. Dry-run by default.
  - **Rollback** — `QM_DISABLE_Q10_LONG_CELL_BREAKER=1` makes `breaker_enabled()`
    return False; `run()` then no-ops and writes no holds. Existing holds persist
    until an operator releases them. Same env-var kill-switch convention as
    `codex_fleet_pacer.QM_DISABLE_TESTER_DRAIN_CODEX_CAP` and
    `QM_DISABLE_LONGRUN_SCHEDULING_CAP`. Read fresh every run; no restart-time
    migration.
- `tools/strategy_farm/health.py`:
  - New invariant `chk_q10_long_cell_breaker_holds` (registered in `ALL_CHECKS`
    between `q09_sealed_plan_hold_age` and `q09_autoseal_hold_census`). Read-only:
    joins `work_item_holds` (hold_code `Q10_LONG_CELL_BREAKER`, active) to
    `work_items`. `OK` when none, `WARN` when present (operator review), `FAIL`
    when a hold has aged past the 6h shift window. Surfaces the flag in
    `farmctl.py health` / `state/health.json`. Writes **no** verdict field — it
    emits the standard `name/status/value/threshold/detail/action_hint` health row.
- `tools/strategy_farm/tests/test_q10_long_cell_breaker.py` (new): 29 tests.

## Acceptance criteria mapping

1. *Over-threshold cell → flag + health entry, no verdict.*
   `test_run_apply_flags_parent_writes_hold_no_verdict_stops_reclaim` asserts the
   parent's `status`/`verdict` stay untouched; `test_health_check_warns_when_hold_present`
   / `_fails_when_hold_aged` assert the health entry appears (and carries no
   `verdict` field).
2. *Retry chain ends in a documented hold instead of endless re-claiming.* The
   same integration test proves the parent is claimable before the run and, via
   the real claim-predicate hold filter (`_claimable_ids`), **not** claimable
   after the hold is written.
3. *Success-cell-time separated from exhaustion-time.*
   `test_telemetry_separates_success_from_exhaustion` and the integration test's
   telemetry assertions prove the two series are disjoint and separately reported.

## Test results

```text
> python -m pytest -q tools/strategy_farm/tests/test_q10_long_cell_breaker.py
29 passed in 2.10s

> python -m pytest -q \
    tools/strategy_farm/tests/test_factory_quiescence.py \
    tools/strategy_farm/tests/test_health_q09_sealed_plan_hold_age.py \
    tools/strategy_farm/tests/test_governed_work_item_hold.py \
    tools/strategy_farm/tests/test_q09_autoseal_hold_census.py
27 passed in 5.16s

> python -m pytest -q \
    tools/strategy_farm/tests/test_health_starvation.py \
    tools/strategy_farm/tests/test_health_mt5_capacity.py \
    tools/strategy_farm/tests/test_mnt035_health_contract.py \
    tools/strategy_farm/tests/test_health_q02_stranded.py
33 passed in 1.63s
```

Read-only `--json --no-state` dry-run against the live farm DB
(2026-08-24T17:03:35Z, no `--apply`, `holds_written=0`) confirmed the detector
reads the live schema and correctly flags a stale `Q10_NEWS` parent still in
`status='active'` whose inflight cells exceed the 7200s floor — exactly the
`13f41983` occupancy pathology. No write path was exercised.

## Deployment note (not yet wired to a scheduler)

The breaker is a standalone module with a CLI (`--apply` to write holds,
default dry-run). It is intentionally left un-scheduled for OWNER review before
any automated `--apply` cadence is registered. Until then it is safe to run
`--json --no-state` read-only ad hoc. The health invariant is live immediately
(it only reads holds, so it surfaces `OK` until the first hold is written).

## Files changed and rollback

- `tools/strategy_farm/q10_long_cell_breaker.py` (new)
- `tools/strategy_farm/health.py`
- `tools/strategy_farm/tests/test_q10_long_cell_breaker.py` (new)

Rollback: set `QM_DISABLE_Q10_LONG_CELL_BREAKER=1` in the environment (no
restart-time migration; the flag is read fresh each run), or `git revert` this
commit. No production database, registry, gate criterion, verdict, or live
terminal was mutated by this change.
