# Q13 numeric-baseline starvation: root cause, fix, and live acceptance

- Router task: `21a446fd-a58b-4614-b214-41bd465bd3e3`
- Program: `DL089_QM5_11421_EURUSD_DWX_2019_2025`
- EA under census: `QM5_41162_ohlc-daily-squeeze-reversal-d1-opt`
- Scope: dispatcher ordering only; no strategy, set-file, verdict, historical ledger, capacity, or pipeline mutation
- Branch: `agents/board-advisor`
- Fix commit: `efce2da5eb` (`fix(dl089): rank true numeric lane head`)
- Verdict: **PASS — the true numeric baseline head now outranks post-census annual work, and all six remaining baseline years were claimed and completed `MEASURED` in strict order through ordinary workers.**

## Root cause

The prior numeric-priority change marked every declared numeric baseline row with `priority_track=true` and `opt_census_frontier_priority=true`. `pending_claim_order_sql()` therefore treated every pending year as if it were the current serial head. The generic timestamp tie-break could place the older-updated 2021 row ahead of 2020.

That bad ordering also fed `_load_next_cell_prestage_snapshot()`. The prestage snapshot could select 2021 even while `_next_cell_prestage_dl089_snapshot()` correctly described it as `candidate_is_frontier=false`. Claim-time lane validation then rejected the prepared row as not being the arm frontier, but the lane was recorded as already attempted for that claim pass. The worker continued to unrelated annual work instead of reaching the true 2020 head.

Concrete pre-fix evidence is in `D:\QM\strategy_farm\logs\terminal_worker_T2.log`: line 228 observed 2021 (`8ccbb4d5...`) as the candidate at `12:14:38Z`; lines 233, 238, and 241 repeatedly attempted it; line 243 records `claimed_different_item` at `12:26:24Z`. The same pattern recurred at lines 270-283 through `12:55:17Z`.

## Fix

`_opt_census_post_census_rank()` in `tools/strategy_farm/farmctl.py` now grants rank 0 to a numeric-priority row only when no earlier pending or active `OPT_CENSUS` row exists for the same `program_id` and `arm`. Later numeric years retain rank 1 until their predecessor finishes. This makes the SQL ordering used by both normal claim selection and next-cell prestage reflect the actual serial lane head.

The regression `test_numeric_baseline_true_head_precedes_later_year_and_cross_program_annual` deliberately gives 2020 the newest timestamp and 2021 the oldest timestamp, then proves:

1. 2020 is rank 0 and is ordered first.
2. 2020 outranks unrelated annual work.
3. 2021 remains rank 1 until 2020 leaves pending/active state.

## Focused verification

Run from `C:\QM\repo` after the fix:

```text
python -m pytest tools/strategy_farm/tests/test_opt_census_dispatch.py -q
.......................                                                  [100%]
23 passed in 2.24s

python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/tests/test_opt_census_dispatch.py
exit 0
```

Only idle worker processes were reloaded so they would import the corrected dispatcher. T1 was confirmed idle before worker PID 5020 was replaced by PID 25728 (generation `d80079f655104d069ce19276ddb7a3f9`); T6 was confirmed idle before worker PID 26260 was replaced by PID 19364 (generation `3b7a3ddb52e5480b881d768e017fa695`). No active tester was stopped, no terminal was started manually, and neither AutoTrading nor T_Live was enabled. Subsequent worker lifecycle restarts were performed by the existing supervisor.

## Live acceptance

The live state database was observed read-only at `D:\QM\strategy_farm\state\farm_state.sqlite`. The ordinary terminal workers produced the following strict sequence. Every claim log includes `dl089_lane_preflight_status=checked`, program `DL089_QM5_11421_EURUSD_DWX_2019_2025`, and arm `baseline`.

| Year | Work item | Claimed UTC / terminal | Completed UTC | Result | Summary SHA-256 |
|---:|---|---|---|---|---|
| 2020 | `7d8baa1d-db8f-567b-b73a-ae74b99e9e22` | `13:19:51` / T6 | `13:25:40` | `done/MEASURED` | `61ce091074a4182bf6e40d3716791a705ca485ab168564d6b77ce65620d8117c` |
| 2021 | `8ccbb4d5-6716-5636-bf87-169296e4198a` | `13:25:47` / T2 | `13:30:52` | `done/MEASURED` | `6e2fa0f965b5695dd3d0c9ff65456fd0b3b85033173bf52e8e87051571b9a5c0` |
| 2022 | `66455cef-e457-5328-bcf0-46f96c78ed2a` | `13:31:35` / T10 | `13:37:56` | `done/MEASURED` | `397062b39add4f129faa9047886b9a9f53cf1a7bcc475a38748bc70f6b1e492f` |
| 2023 | `671ced8b-2f8b-590d-9b12-974c76865981` | `13:38:50` / T4 | `13:45:00` | `done/MEASURED` | `d223ba1c5064b627bcc9864f401666d5812d867347b37e698fbcf19417f90f77` |
| 2024 | `836f1551-809d-59a2-bc3b-1ef04c678950` | `13:45:48` / T5 | `13:51:20` | `done/MEASURED` | `67a6f29eeb1cfc5ad13f40abcd959a0e3e56d32b31dfa1f241e6789b70fb9c1f` |
| 2025 | `880dcac2-a3c0-55af-9fb2-f819387abfa6` | `13:54:57` / T6 | `14:00:56` | `done/MEASURED` | `6128534edcba718f8ca509089ed1ae455593fd2c0c6f3272bf08dad4bba43e1c` |

Claim/result log anchors:

- T6: `terminal_worker_T6.log` lines 21625/21628 (2020) and 21661/21664 (2025)
- T2: `terminal_worker_T2.log` lines 322/326 (2021)
- T10: `terminal_worker_T10.log` lines 24747/24750 (2022)
- T4: `terminal_worker_T4.log` lines 23332/23335 (2023)
- T5: `terminal_worker_T5.log` lines 22079/22082 (2024)

All six work items bind the same expected and recorded EX5 hash, `32ac75db71c957ea78fd65f34a3468f9241f91bc4a8ca05c1526b3b1fdcc1ccc`, and recorded MQ5 hash, `57298f812d62c24b41fea5333b7de0785004339610a48fd4934454de821c283b`. Each final `evidence_path` exists beneath `D:\QM\reports\work_items\<id>\QM5_41162\...\summary.json`, and the table records the SHA-256 of that summary.

No direct queue claim, verdict update, historical ledger edit, or synthetic evidence write was used for acceptance. The only live state transitions above were the workers' normal claim and measurement transitions.

## Review boundary

This artifact and fix remain in REVIEW on `agents/board-advisor`. No merge, cherry-pick, main-worktree mutation, pipeline advancement, or self-approval was performed.
