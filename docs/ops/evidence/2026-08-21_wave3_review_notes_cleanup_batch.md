# Wave-3 review-notes cleanup batch (5 items)

Date: 2026-08-21. Author: Claude (orchestrator, headless cycle). Branch: agents/board-advisor.
Router task: `db470d0a-ad5c-4f04-97d4-9e5055a97805`.

Five small, independently-committed items collected at the ultracode wave-3 review close.
Each below links its own commit; no scope creep beyond the described fix.

## MNT-016: Q08 INVALID rescue rows were unsatisfiable

`collect_q08_portfolio_rescue_for_ea` (render_dashboards.py) and
`q08_portfolio_rescue_snapshot` (render_cockpit.py) both filtered
`status='done' AND verdict IN (...,'INVALID')`, but `work_items_clean`'s
`status_sql` CASE maps every `INVALID%` verdict to clean `status='failed'`,
never `'done'` — so the INVALID arm could never match. Confirmed live: exactly
5 Q08 rows carry `verdict=INVALID` (all
`neighborhood_evidence_lineage_invalid:baseline_setfile_defect`), all
silently invisible to both surfaces.

Decision: surface them, tagged INVALID, separate from genuine FAIL_SOFT/
FAIL_HARD rescue candidates (an INVALID row has no valid standalone result to
portfolio-rescue against; it needs evidence repair, not a Q09 judgment) — both
call sites' own tier classifiers already special-cased `verdict=='INVALID'` as
a distinct tier, which only makes sense if the surface was meant to show
these rows.

Fix: query `status='failed'` for the INVALID arm, `status='done'` for the
real strategy-taxonomy verdicts. Cockpit's summary counters gained a matching
`invalid` bucket alongside soft/hard.

Commit `6013432bb`. Verification: `test_mnt016_q08_rescue_invalid_surface.py`
(2 new tests, confirmed failing pre-fix via git-stash bisection, passing
post-fix) plus the existing cockpit/dashboard suites (24 passed, no
regressions).

## MNT-032: threshold rationale documented

Appended a rationale section to
`2026-08-21_mnt032_resource_headroom_and_reclaim.md` tying
`DISK_STOP_GB`/`RAM_RESERVE_GB`/`COMMIT_RESERVE_GB`/per-worker-8GB in
`resource_headroom.py` to the pre-existing `terminal_worker.py` circuit
breakers they numerically mirror (`DISK_MIN_FREE_GB`, `RAM_MIN_FREE_GB`,
`COMMIT_MIN_FREE_GB`, `ORDINARY_COMMIT_RESERVATION_GB`) — confirmed by direct
`grep`, not asserted from memory. No code changed; doc-only. Commit `cd5d43385`.

## MNT-035: task_monitor_escalation echo was compounding without bound

Live evidence in `D:\QM\reports\state\task_monitor_health.json` showed entries
like `"FAIL:task_monitor_escalation:FAIL:task_monitor_escalation:FAIL:pump_task_lastresult:..."`
— hourly_monitor.ps1's sidecar re-emits every farm_health FAIL as a
`task_monitor_escalation` row; `_external_health_checks` folds that sidecar
back into the next farm_health run, so a still-failing (or even long-resolved
and orphaned) condition got wrapped one echo layer deeper every hourly cycle,
forever. The live sidecar showed `summary.fail=17` against `farmctl health`'s
own direct measurement of 4 distinct conditions.

Two-part fix: `health.py`'s `run_all()` now drops a `task_monitor_escalation`
row when its unwrapped condition name matches a check already produced
natively that run (so `summary.fail` counts each condition once and nothing
stale survives into the next `health.json` for hourly_monitor to re-wrap);
`hourly_monitor.ps1` additionally stops escalating checks sourced from
`task_monitor` in the first place (the actual root-cause fix — it's what was
driving the unbounded nesting even for orphaned conditions with no live
producer). Commit `305e84fcf`. Verification: 2 new tests in
`test_mnt035_health_contract.py`, confirmed failing pre-fix via git-stash
bisection; full health suite 121 passed.

## MNT-013: unbuilt-cards bucket split + shared enumeration

`chk_unbuilt_cards_count` (health.py) and `unbuilt_cards_disposition.py` each
hand-rolled the identical "R-gate-ready approved card, no .ex5, no
auto-build task" enumeration, synced only by a comment promising not to
drift. Factored into one shared `health.enumerate_unbuilt_cards`, consumed by
both, with a fixture-backed parity test.

`chk_unbuilt_cards_count`'s detail now folds in the latest disposition
snapshot's READY/NEEDS_SOURCE/DATA_BLOCKED counts when fresh and the totals
roughly agree (e.g. "365 ... buckets READY=324 NEEDS_SOURCE=33
DATA_BLOCKED=8" instead of a bare 365). Scheduled the previously-manual-only
snapshot writer: registered + enabled
`QM_StrategyFarm_UnbuiltCardsDisposition_Hourly` (read-only, SYSTEM, ~15s
measured against the live 365-card backlog), added to the ALWAYS_ON manifest
and `docs/ops/SCHEDULED_TASKS_INVENTORY.md`. Commit `ab8952b3e`. Verification:
7 tests in `test_unbuilt_cards_disposition.py` passed; manual live run against
`D:\QM\strategy_farm\state\farm_state.sqlite` confirmed the bucket detail
renders (`buckets READY=324 NEEDS_SOURCE=33 DATA_BLOCKED=8`).

## MNT-030: stale line refs fixed, filenames re-verified correct

`farmctl.py`/`health.py` line citations in
`2026-08-21_mnt030_source_pool_premise_check.md` had drifted from later edits
to those files. Corrected against current `grep` output
(`farmctl.py:21334 def add_source`, `health.py:1594 def chk_source_pool`,
`health.py:1708 def chk_unbuilt_cards_count`, CHECKS registry `3555`/`3557`).
The ticket also flagged a "wrong log filename" — every filename cited in the
doc (`run_log.txt`, `leads.csv`, `summary_20260821T040707Z.md`) was
independently re-verified against the live filesystem and scheduled-task
action and found correct; no filename change was made (inventing one to
"complete" the ticket would have been wrong per the constraint against
manufactured work). Commit `de9100dd0`.

## Verification summary

All five items ran their own focused test/verification pass (listed above);
no destructive or live-touching action was taken. `agents/board-advisor`
working tree confirmed clean of these paths post-commit via `git status`.
