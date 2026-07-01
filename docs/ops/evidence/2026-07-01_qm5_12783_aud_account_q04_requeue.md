# QM5_12783 AUD-Account Q04 Repair And Requeue

Date: 2026-07-01
Branch: `agents/board-advisor`

## Scope

- EA: `QM5_12783_edgelab-audusd-audjpy-cointegration`
- Pair: `AUDUSD.DWX` / `AUDJPY.DWX`
- Logical basket: `QM5_12783_AUDUSD_AUDJPY_COINTEGRATION_D1`
- Prior state: Q02 PASS, Q03 PASS, Q04 INFRA_FAIL
- Action: repair Q04 conversion-history scope and requeue one Q04 row

No new unbuilt allocated EdgeLab FX cointegration pair was found; `QM5_12532`
and `QM5_12533` were checked first and were not Q02-blocked.

## Root Cause

Latest Q04 aggregate:

```text
D:/QM/reports/work_items/16267df3-00b5-4ede-abbb-75dfcadedc14/QM5_12783/Q04/QM5_12783_AUDUSD_AUDJPY_COINTEGRATION_D1/aggregate.json
```

F1 failed as `invalid_summary:INCOMPLETE_RUNS,REPORT_MISSING`. Its run summaries
showed MT5 requesting bare `USDJPY` conversion history under USD tester
accounting for the AUDJPY leg, then exiting without a report.

## Repair

- `basket_manifest.json`: switched to `tester_currency=AUD`,
  `tester_deposit=150000`.
- Logical backtest setfile: switched to `RISK_FIXED=1500`,
  `RISK_PERCENT=0`.
- EA source: removed obsolete `USDJPY.DWX` selection/warmup; AUD tester
  accounting uses the two traded AUD-base symbols only.
- Card/SPEC copies updated to document the AUD-account Q04 repair.
- Added a focused manifest regression for `QM5_12783`.

No entry, exit, sizing algorithm, portfolio gate, `T_Live`, or AutoTrading state
was changed.

## Validation

- `python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py -q`
  - PASS: `6 passed in 0.06s`
- `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12783_edgelab-audusd-audjpy-cointegration --verbose`
  - PASS: `BASKET_OK`, `n_violations=0`
- `powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12783_edgelab-audusd-audjpy-cointegration/QM5_12783_edgelab-audusd-audjpy-cointegration.mq5 -Strict`
  - PASS: errors `0`, warnings `0`
  - compile log: `C:/QM/repo/framework/build/compile/20260701_192007/QM5_12783_edgelab-audusd-audjpy-cointegration.compile.log`
  - `.ex5` SHA256: `582BC02E0C70D77147CB55174EB2B5A70B90C09D594F2FCD3A5B5F3860503032`
- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12783_edgelab-audusd-audjpy-cointegration -RepoRoot C:/QM/repo -SkipCompile`
  - PASS: failures `0`, warnings `16` existing shared-framework advisories
  - report: `D:/QM/reports/framework/21/build_check_20260701_192023.json`

## Queue Action

DB backup before queue mutation:

```text
D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12783_aud_q04_requeue_20260701T212049Z.sqlite
```

Supported command:

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12783 --phase Q04
```

Result:

| field | value |
|---|---|
| work item | `16267df3-00b5-4ede-abbb-75dfcadedc14` |
| status | `pending` |
| verdict | `null` |
| duplicate pending/active Q04 rows | `1` total, the requeued row |
| tester currency | `AUD` |
| tester deposit | `150000` |
| basket symbols | `AUDUSD.DWX`, `AUDJPY.DWX` |
| Q04 latest full year | `2024` |

No manual MT5 backtest was launched from this session. The paced workers own
execution.

Machine-readable evidence:
`artifacts/qm5_12783_aud_account_q04_requeue_20260701.json`.
