# RECYCLE build_ea already-gated closure — 2026-08-22

Task: router-assigned ops_issue `666fe5b3-82fe-481f-8b89-e88347749f6b`
("11 schon-durch RECYCLE-build_ea-Zeilen mit Evidenz schliessen").

## Method

`python tools/strategy_farm/drain_backlog.py` (dry-run classify) partitions every
non-terminal `agent_tasks` row with `state=RECYCLE, task_type=build_ea` into a defect
class. `RECYCLE_BUILD_ALREADY_GATED` (has_ex5 AND >=1 `done` work_items row for the
ea_id) is deliberately excluded from `APPLY_CLASSES` — it has no automated apply path
because closing it needs a cited evidence work_item, not a mechanical rule. Measured at
2026-08-22T08:39:41Z: 11 rows in this class (out of 89 total limbo RECYCLE agent_tasks
across all task_types; 12 of those are build_ea, of which 11 are already-gated and 1 is
`RECYCLE_BUILD_INCOMPLETE`).

For each of the 11, confirmed directly against `work_items` (farm_state.sqlite) that a
`status='done', verdict='PASS'` row exists for the task's `ea_id`, then cited the
highest-phase such PASS row (Q02 < Q03 < ... < Q10) as evidence and closed the
`agent_tasks` row to `PASSED` via
`agent_router.py update-task <task_id> --state PASSED --verdict "bereits durch: <wi_id> <phase> PASS <date>"`.

This closes the stale RECYCLE **build request** only — it is an administrative
statement that "this build task doesn't need re-doing, the currently built artifact
already has gate evidence." It does not touch, overwrite, or reinterpret any pipeline
verdict; `ea_metrics`/`work_items` rows are unmodified.

## Closed rows

| agent_task_id | ea_id | verdict written |
|---|---|---|
| 043c2a30-235b-45fe-8d68-6a4bf272010b | QM5_11896 | bereits durch: 5968caa4-7866-466d-b70c-c7e7718ef359 Q02 PASS 2026-08-08 |
| a2180685-9a61-45ef-a254-3d1bbe970d50 | QM5_13031 | bereits durch: 9002d443-1fed-485a-9507-22bca4027ba5 Q02 PASS 2026-08-03 |
| 69ad8ea9-aec8-40fd-aba1-ac436657ffad | QM5_9912 | bereits durch: 98d333b9-4914-4ef5-b59a-2bb9f492447e Q06 PASS 2026-08-04 |
| 1b1dd349-786e-48d1-8c3f-d7ed91614c54 | QM5_9973 | bereits durch: 251c95db-1813-4e31-9e76-cd60d3eef729 Q04 PASS 2026-08-02 |
| a53520bc-d92a-4aa2-b6fb-3e24d974cba8 | QM5_11294 | bereits durch: 1c3114c6-776a-4734-8766-786211de9966 Q08 PASS 2026-08-19 |
| 070ebd11-f252-4c4c-853a-a32d145c2148 | QM5_35001 | bereits durch: 6c66261d-185e-4816-ad04-87b8fc771b01 Q02 PASS 2026-08-17 |
| d761b379-3b40-4fd0-b91f-bbef202d5187 | QM5_35003 | bereits durch: 09642c7c-9970-4cae-b772-8f501a9eefb8 Q02 PASS 2026-08-17 |
| a7acf60d-9f28-4cfc-a080-061eb3aaedb9 | QM5_36007 | bereits durch: 20ab1967-4b4e-407a-bfa0-88c8f9aa6fb9 Q02 PASS 2026-08-21 |
| 43dce7e4-3d61-4362-ad12-a4504e3e5137 | QM5_37007 | bereits durch: 4cbae93e-49c3-4053-a410-3c899ba6585a Q02 PASS 2026-08-22 |
| 4b97cf9e-7a3c-452d-bc44-964a5a85555b | QM5_33008 | bereits durch: 9bb55fda-6e16-4831-8f03-c528c14dbbef Q03 PASS 2026-08-19 |
| e48c6a6c-1935-4945-9e47-e420f9fb15df | QM5_34004 | bereits durch: c059917e-54d6-4578-bd7a-b1fef59109b6 Q02 PASS 2026-08-17 |

All 11 `update-task` calls returned `"updated": true, "state": "PASSED"`. No row was
closed without a concrete `work_items` citation; none were skipped.

## Not in scope here

- `RECYCLE_BUILD_INCOMPLETE` (1), `RECYCLE_OTHER` (10), `RECYCLE_REVIEW` (67): different
  defect classes, left untouched.
- `farmctl.py health` (run 2026-08-22T08:44:55Z) reported `overall: FAIL` with 11 failing
  checks (e.g. `mt5_dispatch_idle`, `codex_zero_activity`, `q02_stranded_exhausted_pairs`,
  `phase_invalid_rate_7d`, `agent_task_state_stranded`, `agent_task_aging_slo`,
  `work_item_phase_age_slo`, `q09_sealed_plan_hold_age`, `pending_artifact_binding_drift`,
  `task_monitor_escalation` x2). None of these are this task's remit; not actioned here.
