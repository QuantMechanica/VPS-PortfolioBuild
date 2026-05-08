# QUA-662 D2 recheck summary (2026-05-01T11:32Z)

## Execution

- Script: `D:\QM\mt5\T1\dwx_import\verify_import.py`
- Scope: 21 symbols from prior fail table (`bars_one_shot=0` cohort)
- Raw evidence: `C:\QM\repo\docs\ops\QUA-662_D2_VERIFY_RECHECK_2026-05-01T1121Z.json`

## Result

- FAIL_tail: 1
- FAIL_tail_bars: 6
- FAIL_tail_mid_bars: 13
- FAIL_tail_spec: 1

- PASS rows: `0`
- FAIL rows: `21`

## Classification

- D2 remains blocked on T1 custom-symbol bar-read access.
- Failure class persists as validator/runtime access defect, not EA logic.

## Unblock Owner/Action

- owner: CTO + Pipeline-Operator
- action:
1. Fix custom-symbol bar read path returning `(-2, 'Terminal: Invalid params')` on `copy_rates_*`.
2. Re-run the same `verify_import.py` cohort and require 21/21 pass before reopening baseline launch.
3. Keep QUA-662 blocked until D2 and D3 gates are closed.
