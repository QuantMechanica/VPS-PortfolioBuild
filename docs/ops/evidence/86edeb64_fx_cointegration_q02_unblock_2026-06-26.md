# FX Cointegration Basket Q02 Unblock Evidence

Task: `86edeb64-e3e9-4e39-911a-ac3e91d10714`
Date: 2026-06-26
Agent: codex

## Verdict

The FX cointegration baskets are unblocked at the queue level. No new enqueue was created in this pass because both baskets already have exactly one pending logical-basket Q02 work item in `D:/QM/strategy_farm/state/farm_state.sqlite`.

Pipeline Q02 verdicts are not available yet. Per hard rule, no PASS/FAIL strategy verdict is asserted here until phase evidence is produced by the pipeline.

## Current Queue State

`QM5_12532`:

- logical symbol: `QM5_12532_AUDNZD_COINTEGRATION_D1`
- Q02 work item: `e4890d77-b865-4a48-b946-315faefca920`
- status: `pending`
- verdict: null
- attempt_count: `0`
- parent task: `5865e8c0-c37b-4193-bc12-546c80fa357b`
- setfile: `C:/QM/repo/framework/EAs/QM5_12532_edgelab-audnzd-cointegration/sets/QM5_12532_edgelab-audnzd-cointegration_QM5_12532_AUDNZD_COINTEGRATION_D1_D1_backtest.set`
- payload: `portfolio_scope=basket`, `host_symbol=AUDUSD.DWX`, `host_timeframe=D1`, `basket_symbol_count=2`

`QM5_12533`:

- logical symbol: `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`
- Q02 work item: `fe14e345-8ea4-4fbd-a77d-831df5fedc51`
- status: `pending`
- verdict: null
- attempt_count: `0`
- parent task: `1ca1c629-19b8-4517-8071-380bb224ad22`
- setfile: `C:/QM/repo/framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/sets/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1_D1_backtest.set`
- payload: `portfolio_scope=basket`, `host_symbol=EURJPY.DWX`, `host_timeframe=D1`, `basket_symbol_count=2`

These rows were created at `2026-06-26T09:53:06+00:00` by `codex_board_advisor_manual_logical_basket_q02`.

## Guardrail Check

Command:

```powershell
python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_12532_edgelab-audnzd-cointegration framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration
```

Result: PASS for both EA directories.

- `files_checked=4` for `QM5_12532`
- `files_checked=4` for `QM5_12533`
- `max_news_stale_hours=336`
- no findings

Both logical setfiles use compliant backtest risk:

- `RISK_FIXED=1000`
- `RISK_PERCENT=0`

Neither logical setfile raises `qm_news_stale_max_hours`.

## Basket Scope Check

Commands:

```powershell
python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12532_edgelab-audnzd-cointegration --json
python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12533_edgelab-eurjpy-gbpjpy-cointegration --json
```

Results:

- `QM5_12532`: `BASKET_OK`, `n_violations=0`, manifest symbols `AUDUSD.DWX`, `NZDUSD.DWX`
- `QM5_12533`: `BASKET_OK`, `n_violations=0`, manifest symbols `EURJPY.DWX`, `GBPJPY.DWX`

## Router/Enqueue Behavior Check

Command:

```powershell
python -m pytest tools/strategy_farm/tests/test_basket_work_items.py -q
```

Result:

```text
2 passed in 1.05s
```

## Notes

- The older per-leg Q02 rows for these EAs are terminal and should not be used as the fair basket verdict.
- The current fair test is the logical-basket Q02 row for each EA.
- No terminal process was started manually.
- No T_Live or AutoTrading setting was touched.
- No additional Q02 rows were inserted in this pass, avoiding duplicate pipeline work.
