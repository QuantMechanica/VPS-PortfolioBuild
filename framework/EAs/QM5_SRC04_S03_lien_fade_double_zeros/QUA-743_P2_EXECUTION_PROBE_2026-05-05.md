## QUA-743 P2 Execution Probe (2026-05-05)

### Probe Commands Executed

1. P2 runner single-symbol probe:

```powershell
python C:/QM/repo/framework/scripts/p2_baseline.py --ea QM5_SRC04_S03 --symbols EURUSD.DWX --runs 2 --terminal T1 --timeout 900
```

2. Direct smoke runner isolation with equivalent args:

```powershell
pwsh -NoProfile -File C:/QM/repo/framework/scripts/run_smoke.ps1 -EAId 1009 -Symbol EURUSD.DWX -Year 2024 -Terminal T1 -Period H1 -Runs 2 -MinTrades 20 -Model 4 -Expert "QM\QM5_SRC04_S03_lien_fade_double_zeros" -SetFile "C:/QM/repo/framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/sets/QM5_SRC04_S03_lien_fade_double_zeros_EURUSD.DWX_H1_backtest.set" -ReportRoot "D:/QM/reports/pipeline/QM5_SRC04_S03/P2" -AllowRunningTerminal -AllowMissingRealTicksLogMarker -TimeoutSeconds 900
```

### Observed Results

- `p2_baseline.py` records symbol verdict `INVALID` (`no_summary_json`), report row appended:
  - `D:/QM/reports/pipeline/QM5_SRC04_S03/P2/report.csv`
- Direct `run_smoke.ps1` returns explicit structured failure:
  - `run_smoke.result=FAIL`
  - `run_smoke.reason_classes=REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS`
  - summary: `D:\QM\reports\pipeline\QM5_SRC04_S03\P2\QM5_1009\20260505_170634\summary.json`
  - evidence md: `D:\QM\reports\framework\22\20260505_170634_QM5_1009_run_smoke.md`

### Interpretation

- EA/package readiness is no longer the blocker.
- Current blocker is execution-layer stability on terminal/smoke path (metatester hang / report missing / incomplete runs).

### Unblock Owner + Action

- **Owner:** Pipeline-Operator (execution lane)
- **Action:** Diagnose `run_smoke` execution environment on `T1` for `QM5_1009` and rerun P2 after terminal/metatester stability fix.
