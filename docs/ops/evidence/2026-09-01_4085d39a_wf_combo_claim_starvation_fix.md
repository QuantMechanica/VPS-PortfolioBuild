# DL-089 WF combo claim-starvation repair

Date: 2026-09-01

Router task: `4085d39a-64ed-424b-939b-678c7e5a7bce`

Branch: `agents/board-advisor`

Status: REVIEW

## Incident and root cause

The completed EUR program
`DL089_QM5_11421_EURUSD_DWX_2019_2025` entered
`WF_COMBO_MEASURING` and created four valid pending rows at 02:46:05Z, but none
was claimed for more than one hour. Their cell keys use the derived-run format
`program:wfN:combo:YEAR`.

Read-only inspection showed that `dl089_scheduling.lane_id()` does not split
`cell_key`; it consumes explicit `program_id` and `arm`. The four derived rows
had `program_id` but no `arm`, `year`, `priority_track`, or
`opt_census_frontier_priority`, so they fell into the legacy lane and ordinary
OPT_CENSUS tier. `opt_census.boost()` intentionally reads only the 1,085 sealed
annual ledger cells. Consequently, continuously refilled annual frontier rows
ranked ahead of the selection-critical WF rows. The new idle-program tie-break
did not create the malformed identity, but it made the starvation persistent.

## Repair

- `opt_census_select` now fail-closed parses only the exact
  `program:wfN:combo:YEAR` suffix when creating WF combo rows and verifies it
  against the declared `wf_step` and `test_year`.
- Each combo receives the explicit lane `wfN_combo`, derived `year`, bounded
  queue-priority markers, and a distinct queue-only authority string.
- An idempotent selector backfill repairs already-created pending combo rows.
  It updates only the four driver-bound pending IDs and does not rewrite their
  verdicts, evidence, setfiles, or annual ledger cells.
- Canonical pending ordering gives marked `WF_COMBO` rows a dedicated
  post-census subrank before annual frontier refills. All annual rows receive
  the same default subrank, preserving their prior relative ordering and every
  K/L/G, symbol, duplicate-pair, history, and resource gate.

## Live application

The normal selector `advance()` path was applied to the affected sealed ledger
and returned:

```text
state=WF_COMBO_MEASURING waiting=true pending=4 priority_backfilled=4
```

All four payloads then resolved to distinct lanes
`wf1_combo`..`wf4_combo`, years 2022..2025, with both queue markers true. The
canonical read-only ordering placed the remaining WF rows at the queue head.
No terminal was started or interrupted, and no AutoTrading/T_Live setting was
touched.

Live terminal evidence at the time of this artifact:

| WF step | year | work item | observed state | terminal/evidence |
|---:|---:|---|---|---|
| 1 | 2022 | `e972dfeb-a7f2-58a2-8c4c-482a0bb65ec1` | `done / MEASURED` | T10; `D:/QM/reports/work_items/e972dfeb-a7f2-58a2-8c4c-482a0bb65ec1/QM5_41162/20260901_035941/summary.json` |
| 2 | 2023 | `6a10e1ff-59f0-5611-a4cc-1f03b8f958b1` | `done / MEASURED` | T10; `D:/QM/reports/work_items/6a10e1ff-59f0-5611-a4cc-1f03b8f958b1/QM5_41162/20260901_040657/summary.json` |
| 3 | 2024 | `727948af-b4f4-5a15-86c0-48e91ee7ef8b` | `done / MEASURED` | T10; `D:/QM/reports/work_items/727948af-b4f4-5a15-86c0-48e91ee7ef8b/QM5_41162/20260901_041914/summary.json` |
| 4 | 2025 | `a4938d29-4f82-587a-870a-0e3edd54003e` | `active / running` | T10; child PID 14736 started 04:27:06Z |

## Focused verification

- `python -m pytest tools/strategy_farm/tests/test_opt_census_select.py tools/strategy_farm/tests/test_opt_census_dispatch.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q`
  — `125 passed`.
- With the documented code-default test value
  `DL089_CELL_SLOTS=6`, the matrix-service plus dispatch suites reported
  `32 passed`. Without scoping that variable, one existing fixture observed the
  machine's live `DL089_CELL_SLOTS=8` and expected six flagged rows; this was a
  configuration-sensitive fixture result, not a code regression.
- `python -m compileall -q` passed for the modified modules.
- `git diff --check` passed for the explicit change set.

The regression fixtures prove that four-token combo keys map to the expected
four lanes, malformed step/year identities fail closed, legacy pending combo
rows are repaired idempotently, WF critical-path rows precede annual refills,
and the relative order of annual frontier rows is unchanged.
