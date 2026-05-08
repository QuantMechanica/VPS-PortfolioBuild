## QUA-743 Execution Unblocked -> Strategy Gate Fail (2026-05-05)

### Script-Level Fixes Applied

- `framework/scripts/run_smoke.ps1`
  - `Wait-ForReportExport` no longer exits early when no active metatester process is detected.
  - Report export wait increased from `30s` to `90s`.
- `framework/scripts/p2_baseline.py`
  - `run_smoke.summary` parse supports combined stdout/stderr.
  - One-time retry on transient infra fault classes.

### Verification Evidence

Command:

```powershell
python C:/QM/repo/framework/scripts/p2_baseline.py --ea QM5_SRC04_S03 --symbols EURUSD.DWX --runs 2 --terminal T2 --timeout 900
```

Latest smoke summary:

- `D:\QM\reports\pipeline\QM5_SRC04_S03\P2\QM5_1009\20260505_172518\summary.json`
- `reason_classes`: `MIN_TRADES_NOT_MET`
- Both runs `status=OK`
- `model4_log_marker_detected=true`
- `deterministic=true`
- `total_trades=0` on both runs

### Interpretation

- Prior infra-modal failure (`REPORT_MISSING/METATESTER_HUNG/INCOMPLETE_RUNS`) is no longer the terminal blocker for this probe path.
- Current failure is a strategy/gate outcome (zero trades => min-trades gate fail), not smoke infrastructure export failure.

### Owner + Next Action

- **Owner:** Pipeline-Operator + CTO/Development (strategy lane)
- **Action:** Run broader P2 baseline cohort for EA1009 and evaluate zero-trade prevalence before invoking zero-trade recovery workflow.
