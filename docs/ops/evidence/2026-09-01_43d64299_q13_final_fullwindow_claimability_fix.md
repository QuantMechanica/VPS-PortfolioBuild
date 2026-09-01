# Q13 FINAL_FULLWINDOW governed-claimability fix and live acceptance

- Router task: `43d64299-4adf-478c-b004-e4c7339b81c8`
- Program: `DL089_QM5_11421_EURUSD_DWX_2019_2025`
- EA: `QM5_41162_ohlc-daily-squeeze-reversal-d1-opt`
- Branch: `agents/board-advisor`
- Producer/consumer fix: `8f4c711add` (`fix(dl089): govern final fullwindow lanes`)
- Ordering fix: `ec5ce5ce1f` (`fix(dl089): rank final fullwindow heads`)
- Verdict: **PASS — both final full-window cells were repaired by guarded CAS, claimed through ordinary governed workers, and completed `MEASURED`; catch-all stage governance and queue-order regressions are green.**

## Root cause

This was the third instance of the same stage/claimability class:

1. `opt_census_select._derived_run_fields()` synthesized lanes for WF combo and numeric stages but not `FINAL_FULLWINDOW`. The two newly emitted rows therefore carried sealed Q12 bindings but no `arm` or `year`, failing `terminal_worker._is_governed_dl089_census_payload()`.
2. `terminal_worker._dl089_declared_lane()` did not resolve final runs from `driver.final_fullwindow.runs`; even a repaired payload would otherwise fall back to the original annual matrix and fail derived-lane authentication.
3. `farmctl.pending_claim_order_sql()` recognized WF combo and numeric stages in the true-head rank but omitted final full-window and rerun forms. After the payload repair, both finals still sat behind other marked derived rows until the stage allowlist was extended.

## Fix-forward contract

`opt_census_select` now:

- derives `final:incumbent` for role `baseline` and `final:selected` for role `final`;
- assigns deterministic frontier ordinal `year=2019`, the sealed full-window start;
- marks both one-cell lanes with `priority_track=true` and `opt_census_frontier_priority=true`;
- supports `FINAL_FULLWINDOW_RERUN` through the same normalized contract;
- recovers authenticated annual lane fields for census infrastructure reruns;
- rejects every unsupported future stage before insert, rather than emitting an ungoverned row;
- exposes `repair_pending_final_fullwindow_governance()`, which can update only exact-identity rows satisfying `pending`, unclaimed, null-verdict, and byte-identical old-payload predicates.

`terminal_worker` now resolves final lanes from the sealed driver's `final_fullwindow.runs`. `farmctl` includes `FINAL_FULLWINDOW` and `FINAL_FULLWINDOW_RERUN` in the true-head rank introduced by `efce2da5eb`.

## Guarded live repair

The repair ran once inside `BEGIN IMMEDIATE` against `D:\QM\strategy_farm\state\farm_state.sqlite`. It loaded the sealed ledger read-only and used the function's payload compare-and-swap. Result:

```json
{
  "declared": 2,
  "repaired": 2,
  "already_valid": 0,
  "skipped": 0,
  "verdict_rows_touched": 0
}
```

| Role | Work item | Old payload SHA-256 | New payload SHA-256 | Derived lane |
|---|---|---|---|---|
| baseline | `7acee2b6-f8af-52a8-ba55-cdbe005d5d90` | `835c1f8eabd9be37e463915b15061c83746e1a1b910e3b20cf1e4e35cff87c3c` | `11ccd6371969e299cf211aeb4648c8473e56cacb5a47433c923494a59dc198d3` | `final:incumbent`, year 2019 |
| final | `c74a32e6-22ef-5f9e-a139-8fa6c7c7775f` | `ba7d13b8d19ba5b50ae7fee4626e8722671628884a686f458c0dae4e4916bb1e` | `ab3c96e8d6d0bdc00068fd990caf9cf0de717643d17e516ffe82336d4ebf8775` | `final:selected`, year 2019 |

Both rows remained pending, unclaimed, and null-verdict immediately after repair. No verdict, status, gate, evidence, setfile, or ledger field was changed by the repair.

## Regression verification

Run from `C:\QM\repo` after both commits:

```text
python -m pytest tools/strategy_farm/tests/test_opt_census_select.py tools/strategy_farm/tests/test_opt_census_dispatch.py -q
............................................                             [100%]
44 passed in 13.18s

python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/opt_census_select.py tools/strategy_farm/terminal_worker.py tools/strategy_farm/tests/test_opt_census_select.py tools/strategy_farm/tests/test_opt_census_dispatch.py
exit 0

git diff --check -- <the five scoped files>
PASS
```

The tests cover governed final payloads, final lane resolution/frontiers, guarded repair with a measured control row, every currently emitted base/rerun stage, fail-closed unknown stages, and final true-head precedence over annual refill work. The live updated SQL placed `c74a32e6` and `7acee2b6` at pending ordinals 0 and 1 with post-census rank 0; the next marked rows began at ordinal 2 with rank 1.

## Safe worker reload

Reloads were attempted only after confirming both no active row for the terminal and no `pwsh -File run_smoke.ps1` tester. Guards that observed an active row or tester refused before stopping anything. Successful worker-only reloads were staggered; no terminal process was started manually and no active tester was interrupted. The supervisor also performed its normal worker lifecycle restarts. Fresh post-fix generations T9/T10 produced the live claims below.

AutoTrading and T_Live remained untouched.

## Live acceptance

Both rows were claimed by ordinary workers with `dl089_lane_preflight_status=checked`, the exact program ID, and their derived arms:

| Role / arm | Work item | Claim UTC / terminal | Completed UTC | Result | Summary SHA-256 |
|---|---|---|---|---|---|
| final / `final:selected` | `c74a32e6-22ef-5f9e-a139-8fa6c7c7775f` | `14:35:34` / T10 | `14:50:35` | `done/MEASURED` | `382836ce18b77de636127fdd77a6fac3518c86ad9cf2d9bbcf759115ba824dd8` |
| baseline / `final:incumbent` | `7acee2b6-f8af-52a8-ba55-cdbe005d5d90` | `14:36:01` / T9 | `14:56:07` | `done/MEASURED` | `76fec02de42bca110d13a514821f0671f7c4a806f1a07b8d90af12bed32667fa` |

Log anchors:

- `D:\QM\strategy_farm\logs\terminal_worker_T10.log` lines 24789/24792: selected claim and `opt_census_measured` result.
- `D:\QM\strategy_farm\logs\terminal_worker_T9.log` lines 26576/26579: incumbent claim and `opt_census_measured` result.

Both rows bind expected/recorded EX5 SHA-256 `32ac75db71c957ea78fd65f34a3468f9241f91bc4a8ca05c1526b3b1fdcc1ccc`, MQ5 SHA-256 `57298f812d62c24b41fea5333b7de0785004339610a48fd4934454de821c283b`, Q12 item `c4bc189b-372d-54c9-be45-046ac77b245b`, and declaration SHA-256 `40db534ec0c022eb8a5f98ccc5372abf5189511479b30ef176568d866a5fe7cb`.

The runtime ledger remained byte-stable throughout repair and measurement observation: modification time `2026-09-01T14:05:31.443687Z`, SHA-256 `c5b47198a8a626fd15c7652dbc397d4b3ab9f2beb32f6e161d17b1a7a076f9c8`. No manual verdict or ledger mutation was performed; the two `MEASURED` transitions and evidence paths were written only by the normal workers.

## Review boundary

The fixes and this evidence remain in REVIEW on `agents/board-advisor`. No self-approval, pipeline verdict, main-worktree mutation, merge, or cherry-pick was performed.
