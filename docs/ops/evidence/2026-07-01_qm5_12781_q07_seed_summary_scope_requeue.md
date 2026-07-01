# QM5_12781 Q07 Seed Summary Scope Requeue

Date: 2026-07-01
Branch: `agents/board-advisor`

## Scope

Mission fallback path: the strict 66-pair FX cointegration survivors
`QM5_12532` and `QM5_12533` are already built and not Q02-blocked, so this pass
advanced the existing FX basket `QM5_12781` USDJPY/AUDJPY cointegration.

No `T_Live`, AutoTrading, portfolio admission, portfolio KPI, Q08 contribution,
or deploy manifest files were touched. No manual MT5 tester run was launched.

## Finding

The latest Q07 aggregate for work item
`38226031-b41f-4f03-ab86-d1697ca5e203` was infra-invalid, not a strategy
verdict:

- phase: `Q07`
- symbol: `QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1`
- reason classes: `NO_HISTORY`, `INCOMPLETE_RUNS`
- aggregate:
  `D:\QM\reports\work_items\38226031-b41f-4f03-ab86-d1697ca5e203\QM5_12781\Q07\QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1\aggregate.json`

All five seed details pointed at the same run-smoke summary path:

`D:\QM\reports\work_items\38226031-b41f-4f03-ab86-d1697ca5e203\QM5_12781\20260701_052328\summary.json`

That showed Q07 was selecting the latest `summary.json` under the whole work
item after each seed, so later seeds could inherit stale or foreign evidence.

## Code Repair

`framework/scripts/q07_multiseed.py` now:

- treats `run_smoke.summary=...` from the seed subprocess output as the
  authoritative summary path;
- falls back only to a `summary.json` whose mtime is after that seed subprocess
  started;
- applies the same per-run timestamp scope to `report.htm` fallback metrics.

Regression coverage in `framework/scripts/tests/test_q05_q07_verdicts.py`
creates a stale pre-existing summary and verifies Q07 uses the seed-owned
`run_smoke.summary` path instead.

## Validation

```text
python -m py_compile framework/scripts/q07_multiseed.py
python -m pytest framework/scripts/tests/test_q05_q07_verdicts.py -q
```

Result: `15 passed`.

## Queue Action

Command:

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12781 --phase Q07
```

Result:

| Field | Value |
|---|---|
| Requeued work item | `38226031-b41f-4f03-ab86-d1697ca5e203` |
| Created rows | `0` |
| Status after | `pending` |
| Verdict after | `null` |
| Claimed by | `null` |
| Archived prior report root | `D:\QM\reports\work_items\38226031-b41f-4f03-ab86-d1697ca5e203.requeued_20260701T0749300000` |

Payload retained the basket context:

- `portfolio_scope`: `basket`
- `logical_symbol`: `QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1`
- `host_symbol`: `USDJPY.DWX`
- `host_timeframe`: `D1`
- `tester_currency`: `USD`
- `tester_deposit`: `100000`
- `timeout_min`: `120`

Stopped here under paced-fleet discipline. The pending Q07 row is left for the
worker fleet to claim.
