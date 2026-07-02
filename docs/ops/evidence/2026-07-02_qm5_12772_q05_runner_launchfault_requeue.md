# QM5_12772 Q05 Runner Launch-Fault Repair + Requeue - 2026-07-02

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits, no T_Live manifest edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair scan artifact. The strict scan survivors, `QM5_12532` and `QM5_12533`,
are not Q02-blocked: both have logical-basket Q02 PASS rows. No unbuilt strict
scan-cleared FX cointegration pair was found, so this pass advanced an existing
forex basket instead.

Selected basket: `QM5_12772` GBPJPY/AUDJPY D1 cointegration.

## State Before Action

- Q02: `0ef494c0-7669-4c98-9e5c-326ff70df987`, PASS.
- Q04: `1b418d74-da86-4fb2-aa41-74ebca065f05`, PASS_SOFT.
- Q05: `dd43c7e2-7351-41e1-a4a4-f667d0789249`, INFRA_FAIL.

Latest Q05 aggregate:

`D:/QM/reports/work_items/dd43c7e2-7351-41e1-a4a4-f667d0789249/QM5_12772/Q05/QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1/aggregate.json`

The aggregate had `reason=summary_missing`, no summary/report metrics, and
Windows exit code `3221225794` (`0xC0000142`). The same log also showed a
transient 30-second timeout while spawning `gen_stress_setfile.py`.

## Repair

- `framework/scripts/q05_stress_medium.py` now generates the MED stress setfile
  in-process through `stress_setfile_text()` instead of spawning a child Python
  process.
- `framework/scripts/q06_stress_harsh.py` received the same in-process setfile
  generation repair for the next stress gate.
- Q05 now reports exhausted Windows launch faults as
  `launch_fault:exit_code=0xC0000142` instead of collapsing them into generic
  `summary_missing`.

Regression tests added in `framework/scripts/tests/test_q05_q07_verdicts.py`.

## Validation

- `python -m pytest framework/scripts/tests/test_q05_q07_verdicts.py -q`: PASS
  (`20 passed`).
- `git diff --check -- framework/scripts/q05_stress_medium.py framework/scripts/q06_stress_harsh.py framework/scripts/tests/test_q05_q07_verdicts.py`: PASS.

## Queue Action

Command:

`python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12772 --phase Q05`

Result:

- Requeued existing Q05 row in place:
  `dd43c7e2-7351-41e1-a4a4-f667d0789249`.
- Created no duplicate work item.
- Post-state: `pending`, `verdict=null`, `attempt_count=0`, `claimed_by=null`.
- Pending/active Q05 rows for `QM5_12772`: exactly 1.
- Archived previous report root:
  `D:/QM/reports/work_items/dd43c7e2-7351-41e1-a4a4-f667d0789249.requeued_20260702T1748550000`.

Confirmed payload keeps `portfolio_scope=basket`, `RISK_FIXED=1000`,
`tester_currency=USD`, `tester_deposit=100000`, `timeout_min=120`, and basket
symbols `GBPJPY.DWX`, `AUDJPY.DWX`, `USDJPY.DWX`.

No manual MT5 run was launched; execution is left to the paced farm workers.
