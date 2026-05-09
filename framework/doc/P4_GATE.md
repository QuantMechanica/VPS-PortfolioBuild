# P4 Gate (Monte Carlo)

## Purpose

P4 Monte Carlo validates robustness after upstream baseline/selection gates. This gate is pass/fail and writes structured evidence JSON under `<output-root>/<ea_id>/P4/`.

## Inputs

Runner: `framework/scripts/p4_montecarlo.py`

Required CLI parameters:
- `--ea`
- `--baseline-pf`
- `--baseline-max-dd-pct`
- `--mc-pf-p05`
- `--mc-net-profit-p05`
- `--mc-max-dd-pct-p95`

Optional parameters:
- `--symbol` (default `EURUSD.DWX`)
- `--output-root` (default `D:/QM/reports/pipeline`)
- `--min-pf-p05` (default `1.00`)
- `--max-dd-multiplier` (default `1.50`)

## Hard Criteria

PASS requires all checks:
1. `mc_pf_p05 >= min_pf_p05`
2. `mc_net_profit_p05 > 0`
3. `mc_max_dd_pct_p95 <= baseline_max_dd_pct * max_dd_multiplier`

Any violation returns `FAIL` and process exit code `2`.

## Evidence Contract

The script prints a compact JSON summary to stdout and writes a full evidence payload with:
- `phase` (`P4`)
- `ea_id`
- `verdict`
- `criterion`
- `details` (baseline, monte_carlo, thresholds)
- `evidence_path`

## Example

```powershell
python framework/scripts/p4_montecarlo.py `
  --ea QM5_1004 `
  --symbol EURUSD.DWX `
  --baseline-pf 1.42 `
  --baseline-max-dd-pct 9.8 `
  --mc-pf-p05 1.11 `
  --mc-net-profit-p05 1250.0 `
  --mc-max-dd-pct-p95 13.7
```

## Notes

- This gate does not consume external market APIs.
- Symbol defaults preserve `.DWX` suffix discipline in research/backtest contexts.
- Threshold overrides should be documented in issue-level evidence before use.
