# Q08/Q11 Worst-Case Commission Task D Evidence

Task: dec7617d-d49d-459e-a454-d4a78be3e049

Scope completed:
- Added `framework/registry/live_commission.json` with the OWNER-approved class rates and complete `dwx_symbol_matrix.csv` DWX symbol universe mapped to `forex`, `index`, or `commodity`.
- Added `tools/strategy_farm/portfolio/commission.py` with `CommissionModel.cost_round_trip(symbol, volume, notional_acct)`.
- Unknown symbols fall back to `default_class` and log a warning.
- Legacy streams with `notional_acct is None` use flat-per-lot only and set `degraded=True` plus `degraded_symbols`.
- Added focused unittest coverage in `tools/strategy_farm/tests/test_commission.py`.

Verification:
- `python -m unittest tools.strategy_farm.tests.test_commission`
