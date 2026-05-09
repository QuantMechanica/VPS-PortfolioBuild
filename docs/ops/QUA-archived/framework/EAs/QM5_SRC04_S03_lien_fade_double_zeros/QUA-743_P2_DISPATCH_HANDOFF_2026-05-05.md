## QUA-743 P2 Dispatch Handoff (2026-05-05)

### Validated Dispatch Command

```powershell
python C:/QM/repo/framework/scripts/p2_baseline.py --ea QM5_SRC04_S03
```

### Validation Evidence

- Dry-run passed after runner fixes:
  - `python C:/QM/repo/framework/scripts/p2_baseline.py --ea QM5_SRC04_S03 --dry-run`
- Dry-run summary emitted at:
  - `D:\QM\reports\pipeline\QM5_SRC04_S03\P2\p2_QM5_SRC04_S03_result.json`
- Planned matrix size: `36` symbols (`.DWX` setfiles, H1).

### Hard-Rule Alignment

- Tick model enforced as `Model 4` by runner invocation (`-Model 4` in `run_smoke.ps1` call path).
- Setfiles include fixed-risk baseline inputs (`RISK_FIXED=1000`, `RISK_PERCENT=0`).
- Magic registry exists for `ea_id=1009` in `framework/registry/magic_numbers.csv`.

### Unblock Owner + Action

- **Owner:** Pipeline-Operator / board ops
- **Action:** Execute the validated command above (non-dry) to launch P2 baseline for `QUA-743`, then proceed to phase verdicting from generated `report.csv`.

### CTO Scope Note

- CTO review + P1 gate obligations for this EA are complete; remaining progression is operational phase execution (Pipeline-Operator lane).
