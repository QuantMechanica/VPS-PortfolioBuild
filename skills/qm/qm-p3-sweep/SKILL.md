---
name: qm-p3-sweep
description: Use when Research is launching a P3 parameter sweep on PASS symbols from P2, or when Pipeline-Operator is executing a P3 run assigned by Research. Don't use without confirmed P2 PASS symbols. Don't use for P3.5 walk-forward (that is qm-run-pipeline-phase).
owner: Research
reviewer: CEO
last-updated: 2026-05-08
basis: framework/scripts/run_smoke.ps1 + docs/ops/PIPELINE_PHASE_SPEC.md § P3
---

# qm-p3-sweep

Procedure for launching a P3 Parameter Sweep — the optimization phase that finds the best parameter set on the P2 PASS symbols. Distinct from P3.5 Walk-Forward (robustness check on best P3 parameters).

## When to use

- P2 report exists with ≥1 `verdict=PASS` symbol
- CEO has authorized P3 promotion (gate decision on Paperclip issue)
- Research has defined a sweep parameter grid in the EA's `.set` file or YAML config

## When NOT to use

- No P2 PASS symbols (no evidence for optimization)
- CEO has not approved promotion from P2
- P3.5 walk-forward already running (that is a separate phase)
- EA has `verdict=FAIL` across all P2 symbols

## P3 vs P3.5 distinction

| Phase | Name | What it does |
|-------|------|--------------|
| **P3** | Parameter Sweep | Find best parameters on IS (in-sample) window |
| **P3.5** | Cross-Sectional Robustness | Test P3's best params on OOS (out-of-sample) window across orthogonal asset classes |

This skill covers P3. P3.5 uses `qm-run-pipeline-phase`.

## P3 symbols

P3 runs only on the **P2 PASS symbols** (not the full 36-symbol matrix). Confirm the list from `report.csv`:
```bash
python -c "
import csv
with open('D:/QM/reports/pipeline/QM5_<NNNN>/P2/report.csv') as f:
    rows = [r for r in csv.DictReader(f) if r['verdict']=='PASS']
print([r['symbol'] for r in rows])
"
```

## Procedure

### Step 1: Identify sweep parameters

Read the EA's P3 config. The sweep parameter grid should be defined in either:
- `framework/EAs/QM5_<NNNN>_<slug>/sets/<ea_label>_<SYMBOL>_H1_backtest.set` (MT5 .set file with ranges)
- Or a YAML sweep config discussed with CTO

### Step 2: Launch sweep via run_smoke.ps1

```powershell
pwsh framework/scripts/run_smoke.ps1 `
  -EALabel QM5_<NNNN>_<slug> `
  -Symbol <SYMBOL>.DWX `
  -Period H1 `
  -Mode sweep
```

For multi-symbol P3 (run PASS symbols in sequence):
```powershell
foreach ($sym in @('EURUSD.DWX','GBPUSD.DWX')) {
    pwsh framework/scripts/run_smoke.ps1 -EALabel QM5_<NNNN>_<slug> -Symbol $sym -Period H1 -Mode sweep
}
```

Or via MT5 Strategy Tester directly on T1-T4 (not T5, not T6):
- Open EA on tester
- Set Optimization mode: Slow complete algorithm
- Set date range: IS window per `PIPELINE_PHASE_SPEC.md`
- Enable results export to `D:\QM\reports\pipeline\QM5_<NNNN>\P3\`

### Step 3: Extract best parameters

From the optimization results, select the parameter set with best combination of:
- Profit Factor ≥ threshold (per `PIPELINE_V5_SUB_GATE_SPEC.md` § P3)
- Max Drawdown ≤ threshold
- Trade count ≥ minimum (avoid sparse-trade overfitting)

Apply "cherry-pick penalty": reject parameter sets that win by 1-2 trades — they are overfitted.

### Step 4: Write best-params .set file

Save the selected parameters to:
```
framework/EAs/QM5_<NNNN>_<slug>/sets/<ea_label>_<SYMBOL>_H1_P3_best.set
```

### Step 5: Write P3 report

Create `D:\QM\reports\pipeline\QM5_<NNNN>\P3\report.csv` with:
```
ea_id,phase,symbol,verdict,best_pf,best_dd,best_trades,params_path,evidence
```

Verdict:
- `PASS` — best params meet all P3 gate criteria
- `FAIL` — no parameter set met criteria (EA parked at P3)
- `OVERFIT_RISK` — best params won by < 3 trades margin (flag for CTO review)

### Step 6: Attach evidence and request P3.5

Comment on parent Paperclip issue with:
```
P3 sweep complete.
PASS symbols: [list]
Best params saved: framework/EAs/.../sets/<ea_label>_<SYMBOL>_H1_P3_best.set
Evidence: D:/QM/reports/pipeline/QM5_<NNNN>/P3/report.csv
Next: CEO authorize P3.5 walk-forward
```

## Boundary

- Research owns the parameter selection rationale; Pipeline-Operator executes the sweep.
- Cherry-pick penalty applies — Research must document selection reason.
- P3 does NOT run on P2 FAIL symbols. No exceptions.
- P3.5 starts only after CEO approves the P3 result.

## References

- `framework/scripts/run_smoke.ps1` — sweep runner
- `docs/ops/PIPELINE_PHASE_SPEC.md` § P3 — phase definition, IS window, criteria
- `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` § P3 — gate thresholds
- `docs/ops/PIPELINE_AUTONOMY_MODEL.md` — who can change gate thresholds
