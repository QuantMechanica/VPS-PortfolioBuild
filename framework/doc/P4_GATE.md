# P4 Gate: Monte Carlo Robustness

## Entry criteria

P4 may start only after `P3.5` has at least one `PASS` row for the EA/symbol cell.

Default P3.5 pass thresholds for entry:
- `sharpe > 1.20`
- `max_dd_pct < 20.0`
- `profit_factor > 1.20`

## Monte Carlo run contract

- Runner: `framework/scripts/p4_montecarlo.py`
- Inputs: `return_pct` series from a P3.5 PASS cell (or approved synthetic replay for smoke only).
- Default production run: `--iterations 1000`
- Output folder: `P4/<EA>/<run_tag>/`
- Required artifacts:
- `summary.json`
- `mc_distribution.csv`
- `equity_paths.csv`

## Stop criteria

Monte Carlo gate fails when more than 5% of iterations breach the configured drawdown cap:

- `failure_rate_pct = 100 * (breach_count / iterations)`
- `FAIL` if `failure_rate_pct > 5.0`
- `PASS` otherwise

## Determinism

Runs must be seed-deterministic:
- identical `--seed`, input returns, and params must produce identical `mc_distribution.csv` hash.
