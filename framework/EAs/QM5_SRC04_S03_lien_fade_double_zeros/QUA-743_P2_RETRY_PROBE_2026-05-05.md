## QUA-743 P2 Retry Probe (2026-05-05)

### Script Hardening Applied

- `framework/scripts/p2_baseline.py` now performs a one-time retry for transient smoke fault classes:
  - `REPORT_MISSING`
  - `METATESTER_HUNG`
  - `INCOMPLETE_RUNS`

### Verification Command

```powershell
python C:/QM/repo/framework/scripts/p2_baseline.py --ea QM5_SRC04_S03 --symbols EURUSD.DWX --runs 2 --terminal T2 --timeout 900
```

### Observed Outcome

- Attempt 1: `FAIL` with `run_smoke_fail:REPORT_MISSING;INCOMPLETE_RUNS` (triggered retry path).
- Attempt 2: `FAIL` with `run_smoke_fail:REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS`.
- Final symbol verdict remains `FAIL` (not parser-related).

### Conclusion

- The failure pattern persists across retries and terminals.
- This is confirmed execution-lane instability, not a one-off transient parse/integration issue.

### Unblock Owner + Action

- **Owner:** Pipeline-Operator
- **Action:** Stabilize MT5/metatester report export path for this EA/symbol run class, then rerun full P2 baseline matrix.
