# QM5 Placeholder EA ID Repair - 2026-07-09

Farm task: `813a5fe2-e18c-4aed-95ac-de9c6daf551f`

Scope: repair the unresolved `qm_ea_id=9999` default defect from the approved ops issue without mutating old review history.

## EA Code State

- `QM5_11174_weiss-7rev`: current branch state has `qm_ea_id=11174`.
- `QM5_10694_tv-ict-silver`: current branch state has `qm_ea_id=10694`.
- `QM5_10360_et-donch-decay`: current branch state has `qm_ea_id=10360`.
- No `.mq5` diff was needed in this commit because the branch already contained the corrected defaults; the stale farm review/queue state was the remaining blocker.

## Compile Evidence

- `QM5_11174`: `framework/scripts/compile_one.ps1 -Strict` PASS, 0 errors, 0 warnings. Log: `framework/build/compile/20260709_115731/QM5_11174_weiss-7rev.compile.log`.
- `QM5_10694`: `framework/scripts/compile_one.ps1 -Strict` PASS, 0 errors, 0 warnings. Log: `framework/build/compile/20260709_115746/QM5_10694_tv-ict-silver.compile.log`.
- `QM5_10360`: `framework/scripts/compile_one.ps1 -Strict` PASS, 0 errors, 0 warnings. Log: `framework/build/compile/20260709_115801/QM5_10360_et-donch-decay.compile.log`.

## Test Evidence

- `QM_AGENT_ID=codex python -m unittest tools.strategy_farm.tests.test_p2_full_dwx_fanout` PASS.
- `QM_AGENT_ID=codex python -m unittest tools.strategy_farm.tests.test_dwx_history_range_filter` PASS.
- `python -m py_compile tools/strategy_farm/farmctl.py` PASS.

## Farm DB Actions

- Claimed task `813a5fe2-e18c-4aed-95ac-de9c6daf551f` as `codex:agents/board-advisor`.
- Created repair approval `ea_review` rows for stale rejected reviews:
  - `QM5_11174`: `6097a23b-32fd-4aeb-be78-60732f5464bd`
  - `QM5_10694`: `2460eb3f-f309-41fe-a8f0-c27ddaaf13fb`
- Enqueued Q02:
  - `QM5_11174`: task `1247a343-b287-4e7d-90a3-c69441443e63`, 5 pending work items.
  - `QM5_10694`: task `836c7563-c4bf-482d-836b-1c96a742c23d`, 6 new valid pending work items plus existing pending EURUSD work item `c7e1993e-e908-4092-9d28-6b53fe4ce855`.
  - `QM5_10360`: task `40bf3c97-87d7-4e25-a553-82f10b66e4f0`, 5 valid pending work items.

## Guardrail Notes

- `tools/strategy_farm/farmctl.py` was patched so Q02 setfile auto-retarget skips symbols without an active `magic_numbers.csv` row instead of defaulting missing symbols to slot 0.
- `QM5_10360` fanout rows for `NDX.DWX` and `WS30.DWX` were marked `INVALID` because those symbols do not have active `magic_numbers.csv` rows for EA `10360`.
- `QM5_10694` fanout row for `WS30.DWX` was marked `INVALID` and the generated untracked setfile was removed because `WS30.DWX` does not have an active `magic_numbers.csv` row for EA `10694`.
- No T_Live, AutoTrading, portfolio gate, or live manifest artifacts were touched.
