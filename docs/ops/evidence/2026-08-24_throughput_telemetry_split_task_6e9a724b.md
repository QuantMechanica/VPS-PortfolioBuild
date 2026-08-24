# Throughput telemetry split — task 6e9a724b — 2026-08-24

## Task
Router task `6e9a724b-f1d5-41e2-834a-32b123f8a796` (ops_issue, assigned claude):
split raw verdict-row throughput into execution verdicts vs `disposition_only`
administrative rows, per forensics recommendation 6 (OWNER-DEC-STRANDED-182: a
182-row admin disposition batch read as a 183-verdict throughput spike).

## Finding on pickup
On claiming this IN_PROGRESS task, the canonical checkout (`C:\QM\repo`,
branch `agents/board-advisor`) already contained a **complete, working, but
uncommitted** implementation:
- `tools/strategy_farm/throughput_telemetry.py` (new, untracked) — the four
  metrics module (execution-vs-raw by phase, active terminal-minutes by
  phase, claim-to-complete latency percentiles, Q10 cell throughput).
- `tools/strategy_farm/tests/test_throughput_telemetry.py` (new, untracked).
- `tools/strategy_farm/tests/test_news_gate_service.py` (modified,
  uncommitted) — added disposition-exclusion regression test.
- `health.py`, `news_gate_service.py`, `optimization_fork_driver.py`,
  `render_cockpit.py` already had committed call sites wired to the (missing)
  module — i.e. the committed tree depended on an untracked file.

This uncommitted state was actively tripping `repo_dirty_build_guard`
(`farmctl health`: `codex_zero_activity`=FAIL, 0 codex build activity in 3h
with 46 pending `build_ea` tasks; `codex_bridge_heartbeat`=WARN naming these
exact files as the blocker).

## Verification
- `pytest tools/strategy_farm/tests/test_throughput_telemetry.py
  tools/strategy_farm/tests/test_news_gate_service.py` — 17 passed.
- `pytest tools/strategy_farm/tests/test_optimization_fork_driver.py
  tools/strategy_farm/tests/test_health_vacuousness.py` — 46 passed
  (no regression in adjacent consumers of `EXECUTION_VERDICT_EXCLUSION_SQL`).
- Acceptance criteria (task payload):
  1. `news_gate_service_rate` and related checks use the execution
     definition — confirmed: `news_gate_service.py` and
     `optimization_fork_driver.py` import `EXECUTION_VERDICT_EXCLUSION_SQL`
     from `throughput_telemetry`; live `farmctl health` output already shows
     `news_gate_service_rate.conclusive_verdicts_per_day` computed on that
     basis.
  2. Cockpit shows the new metrics — confirmed:
     `render_cockpit.py:3273-3276` renders `execution_verdict_throughput`,
     `active_terminal_minutes_by_phase`, `claim_to_complete_latency`,
     `q10_cell_throughput` rows.
  3. Test for `disposition_only` exclusion — confirmed:
     `test_execution_count_excludes_disposition_only_row` and
     `test_conclusive_verdicts_exclude_disposition_only_rows`.

## Action taken
Committed the three deliverable files with explicit pathspecs (commit
`9ffceb064`, branch `agents/board-advisor`): `throughput_telemetry.py`,
`tests/test_throughput_telemetry.py`, `tests/test_news_gate_service.py`.

Left untouched (out of this task's scope, unrelated work by another task):
- Two modified `.set` files under `framework/EAs/QM5_10848_tv-mtf-ambush/`.
- `tools/strategy_farm/githooks/pre-commit` (untracked) — tracked source for
  the EX5 commit governance guard
  (`docs/ops/EX5_COMMIT_GOVERNANCE_GUARD_2026-08-24.md`), explicitly "NOT
  installed live by default" per its own header comment. Belongs to a
  different work item; not committed here.

## Read-only / no verdict-logic confirmation
`throughput_telemetry.py` docstring and every function are measurement-only:
plain `SELECT`s on a caller-supplied connection, no writes to `work_items`
status/verdict, no queue-order mutation, no dispatch. Matches the task's
`constraints` field.

## Residual risk / next step
`repo_dirty_build_guard` may still be blocked after this commit by the
unrelated `.set` files and `githooks/` dir above — those belong to other
in-flight work and were left for their owning tasks to commit or clean up.
