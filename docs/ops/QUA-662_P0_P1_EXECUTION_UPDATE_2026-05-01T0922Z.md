# QUA-662 P0/P1 execution update (2026-05-01T09:22Z)

## Wake handling

`issue_children_completed` received; child `QUA-679` marked done. Execution resumed.

## Preflight rerun (post-QUA-679)

- `framework/registry/magic_numbers.csv`: `ea_id=1003` row present (`EURUSD.DWX`, magic `10030000`, status `active`).
- Setfile present:
  - `framework/EAs/QM5_1003_davey_baseline_3bar/sets/QM5_1003_davey_baseline_3bar_EURUSD.DWX_H1_backtest.set`

## P0 result

- Command: `framework/scripts/compile_one.ps1 -EAPath ...QM5_1003...mq5 -Strict`
- Verdict: `PASS` (0 errors, 0 warnings)
- Evidence:
  - compile log: `C:/QM/repo/framework/build/compile/20260501_091946/QM5_1003_davey_baseline_3bar.compile.log`
  - summary csv: `D:/QM/reports/compile/20260501_091946/summary.csv`

## P1 result (smoke on T1, adapted to QM5_1003 setfile)

- Command: `framework/scripts/run_smoke.ps1 ... -EAId 1003 -Expert QM5_1003_davey_baseline_3bar -Symbol EURUSD.DWX -Year 2024 -Terminal T1 -Period H1 -Runs 2 -Model 4 -SetFile <QM5_1003 setfile>`
- Verdict: `FAIL`
- Reason classes: `REPORT_MISSING;INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED`
- Evidence:
  - smoke summary: `D:/QM/reports/smoke/QM5_1003/20260501_092014/summary.json`
  - run evidence: `D:/QM/reports/framework/22/20260501_092014_QM5_1003_run_smoke.md`

## Status decision

- QUA-662 remains `in_progress` with active failure triage at P1.
- This is actionable runtime failure evidence (not synthetic output). No P2+ dispatch started.

## Next action

1. Read tester logs from `D:\QM\mt5\T1\Tester\logs\` around `20260501_092014`.
2. Classify failure as infra vs setup vs EA behavior (`NO_REPORT` rule: file-size check before EA weakness claim).
3. If infra/setup: open targeted fix child issue and re-run P1.
4. If genuine EA behavior: record P1 fail evidence and escalate per phase walk.
