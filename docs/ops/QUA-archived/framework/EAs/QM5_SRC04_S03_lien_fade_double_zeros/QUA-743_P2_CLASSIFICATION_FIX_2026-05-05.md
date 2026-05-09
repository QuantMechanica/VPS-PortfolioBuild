## QUA-743 P2 Classification Fix (2026-05-05)

### What Was Fixed

- Updated `framework/scripts/p2_baseline.py` to parse `run_smoke.summary=` from combined `stdout + stderr` instead of `stdout` only.
- This removes false `INVALID/no_summary_json` outcomes when `run_smoke` prints summary markers on stderr.

### Verification Run

```powershell
python C:/QM/repo/framework/scripts/p2_baseline.py --ea QM5_SRC04_S03 --symbols EURUSD.DWX --runs 2 --terminal T1 --timeout 900
```

Result:

- `FAIL` (not `INVALID`)
- reason: `run_smoke_fail:REPORT_MISSING;INCOMPLETE_RUNS`
- summary path produced at:
  - `D:\QM\reports\pipeline\QM5_SRC04_S03\P2\p2_QM5_SRC04_S03_result.json`

### Operational Meaning

- Parser/integration bug is resolved.
- Remaining blocker is genuine execution/gate failure in smoke run path, not missing-summary parsing.

### Unblock Owner + Action

- **Owner:** Pipeline-Operator
- **Action:** Investigate and clear `REPORT_MISSING` / `INCOMPLETE_RUNS` in the T1 run path, then rerun P2 baseline matrix for EA1009.
