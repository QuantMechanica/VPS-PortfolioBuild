---
name: qm-p4-montecarlo
description: Use when Research is validating the robustness of P3 best parameters via Monte Carlo simulation (1000 trade-sequence reshuffles). Don't use without a confirmed P3.5 PASS result. Don't use for live trading validation — this is in-sample robustness only.
owner: Research
reviewer: CTO
last-updated: 2026-05-08
basis: docs/ops/PIPELINE_PHASE_SPEC.md § P4 + docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md § P4
---

# qm-p4-montecarlo

Procedure for running Phase 4 Monte Carlo simulation to validate that the strategy's edge is not a product of lucky trade sequencing.

## When to use

- P3.5 walk-forward has a confirmed PASS result (OOS result in `D:\QM\reports\pipeline\QM5_<NNNN>\P3_5\report.csv`)
- CEO has authorized P4 promotion
- Research is interpreting robustness; CTO is validating simulation parameters

## When NOT to use

- No P3.5 PASS result (Monte Carlo on overfitted parameters is meaningless)
- EA is at P3 FAIL (parked; no point in robustness testing)
- Using MC to justify a marginal P3.5 result — P3.5 must PASS first

## Metrics to evaluate

| Metric | Threshold |
|--------|-----------|
| Max Drawdown (95th percentile) | ≤ PIPELINE_V5_SUB_GATE_SPEC.md § P4 DD threshold |
| Final equity (5th percentile) | > 0 (must be positive) |
| Sharpe ratio distribution | Median > 1.0 (advisory) |

## Procedure

### Step 1: Locate P3.5 equity curve

Source file: `D:\QM\reports\pipeline\QM5_<NNNN>\P3_5\report.csv` (or `P3_5_<ea>_result.json`)  
Confirm `verdict=PASS` for the target symbol.

### Step 2: Run Monte Carlo via MT5 Strategy Tester (preferred)

In MT5 Strategy Tester on T1-T4 (NOT T5, NOT T6):
1. Load EA with P3 best-params `.set` file
2. Run single backtest on the P3.5 OOS window
3. Go to: Optimization tab → Monte Carlo
4. Set passes: **1000**
5. Run and export results

Export CSV to: `D:\QM\reports\pipeline\QM5_<NNNN>\P4\<SYMBOL>_montecarlo_raw.csv`

### Step 3: Alternative — custom script (if MT5 MC unavailable)

```python
# framework/scripts/run_montecarlo.py (if it exists)
python framework/scripts/run_montecarlo.py \
  --ea QM5_<NNNN> \
  --symbol <SYMBOL>.DWX \
  --passes 1000 \
  --source D:/QM/reports/pipeline/QM5_<NNNN>/P3_5/
```

### Step 4: Compute distribution statistics

From the 1000 reshuffled equity curves, compute:
- Max Drawdown: 95th percentile value
- Final equity: 5th percentile value
- Sharpe ratio: distribution (median, 5th, 95th pct)

### Step 5: Apply verdict

**PASS** (both conditions met):
- 95th pct Max DD ≤ threshold AND 5th pct final equity > 0
→ Advance to P5

**FAIL** (either condition broken):
- Distribution too wide → EA parked at P4
- Reason: curve-fit / over-optimized parameters

### Step 6: Write P4 report

```
D:\QM\reports\pipeline\QM5_<NNNN>\P4\<SYMBOL>_montecarlo.json
```

Schema:
```json
{
  "ea_id": "QM5_<NNNN>",
  "phase": "P4",
  "symbol": "<SYMBOL>.DWX",
  "passes": 1000,
  "dd_95th_pct": <value>,
  "equity_5th_pct": <value>,
  "sharpe_median": <value>,
  "verdict": "PASS|FAIL",
  "evidence": "D:/QM/reports/pipeline/QM5_<NNNN>/P4/<SYMBOL>_montecarlo_raw.csv",
  "reviewed_at": "<ISO date>",
  "reviewer": "Research"
}
```

### Step 7: CTO validation

CTO reviews simulation parameters (pass count, reshuffle method, OOS window used) and confirms the run is methodologically sound before the verdict is accepted.

### Step 8: Comment and close

Comment on Paperclip issue:
```
P4 MC complete.
Passes: 1000
DD 95th pct: <value> (threshold: <threshold>)
Equity 5th pct: <value>
Verdict: PASS/FAIL
Evidence: D:/QM/reports/pipeline/QM5_<NNNN>/P4/<SYMBOL>_montecarlo.json
```

## Boundary

- P4 is a Research + CTO joint step. CTO validates simulation parameters; Research interprets verdict.
- FAIL at P4 means parked at P4 — EA does not advance to P5.
- Do NOT run MC on P2/P3 equity curves (those are IS windows, not OOS).
- Do NOT interpret a PASS as "strategy will succeed live" — further gates follow.

## References

- `docs/ops/PIPELINE_PHASE_SPEC.md` § P4 — phase definition and criteria
- `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` § P4 — threshold values
- `docs/ops/PIPELINE_AUTONOMY_MODEL.md` — who may change thresholds
