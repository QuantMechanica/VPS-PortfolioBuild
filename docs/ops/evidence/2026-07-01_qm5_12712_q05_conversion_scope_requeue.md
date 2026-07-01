# QM5_12712 Q05 Conversion Scope Requeue

Date: 2026-07-01 (Europe/Berlin)
Branch: `agents/board-advisor`

## Scope

The forex expansion mission first checked the preferred FX cointegration baskets:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` is not Q02-blocked; it has logical-basket
  Q02 `PASS` and later Q04/Q05 handling.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` is not Q02-blocked; it has
  logical-basket Q02 `PASS` and later Q04 handling.

All registered approved/local `edgelab-*-cointegration` FX basket rows currently
have matching EA folders, so no non-duplicate unbuilt registered FX pair was
available. This pass advanced the existing forex basket
`QM5_12712_edgelab-eurgbp-euraud-cointegration`
(`QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1`).

## Pre-Action State

`QM5_12712` had already reached:

| Phase | Work item | Verdict |
|---|---|---|
| Q02 | `dcc9e3f9-0639-4423-b6e2-ddd03c0188a6` | `PASS` |
| Q03 | `a60a9de9-1637-4250-aca8-db1e7ae58f71` | `PASS` |
| Q04 | `06e86ebb-4f8d-4763-ac11-1966a890cf22` | `PASS` |
| Q05 | `f064eb24-9f7e-4d80-8180-88b1b0165b52` | `INFRA_FAIL` |

The prior Q05 aggregate was:

`D:\QM\reports\work_items\f064eb24-9f7e-4d80-8180-88b1b0165b52\QM5_12712\Q05\QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1\aggregate.json`

It was classified as infra-invalid with
`invalid_summary:BARS_ZERO,EMPTY_EXPERT,EMPTY_SYMBOL,HISTORY_CONTEXT_INVALID,INCOMPLETE_RUNS,M0_1970_PERIOD,NO_HISTORY,REPORT_MISSING,RUN_STATUS_INVALID`.

## Finding

The basket EA trades `EURGBP.DWX` and `EURAUD.DWX`, but it also selects and warms
`EURUSD.DWX`, `GBPUSD.DWX`, and `AUDUSD.DWX` for USD-denominated cross accounting.
`SPEC.md` already documented those conversion-history requirements and
`Strategy_EnsureBasketScope()` already allowed those symbols.

The manifest underdeclared runtime scope: `basket_manifest.json` listed only
`EURGBP.DWX` and `EURAUD.DWX`. The Q05 evidence showed MT5 synchronizing
`EURUSD.DWX` and `EURAUD.DWX`, then failing on
`GBPUSD.DWX: history synchronization error`, which matched the missing manifest
conversion history.

## Repair

Updated `basket_manifest.json` to declare the complete custom-symbol history
scope:

- traded legs: `EURGBP.DWX`, `EURAUD.DWX`
- conversion history: `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`

Updated `SPEC.md` with the Q05 repair note and refreshed the RISK_FIXED setfile
build hashes through the local build check.

Added a regression in `tools/strategy_farm/tests/test_fx_basket_manifests.py`
that asserts the QM5_12712 manifest declares all runtime-allowed FX symbols.

## Queue Action

Requeued the existing Q05 row in place:

```text
python tools\strategy_farm\farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12712 --phase Q05
```

Result:

| Field | Value |
|---|---|
| Requeued work item | `f064eb24-9f7e-4d80-8180-88b1b0165b52` |
| Created rows | `0` |
| Skipped rows | `0` |
| Status after enqueue | `pending` |
| Updated at | `2026-07-01T01:05:24+00:00` |
| Archived prior report root | `D:\QM\reports\work_items\f064eb24-9f7e-4d80-8180-88b1b0165b52.requeued_20260701T0105240000` |

Current `farmctl work-items --ea QM5_12712` summary:

- `Q02_done_PASS`: 1
- `Q03_done_PASS`: 1
- `Q04_done_PASS`: 1
- `Q05_pending`: 1

## Verification

- `python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py -q`
  - Result: `4 passed in 0.06s`.
- `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12712_edgelab-eurgbp-euraud-cointegration --verbose`
  - Result: `BASKET_OK`, 0 violations, 5 manifest symbols.
- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12712_edgelab-eurgbp-euraud-cointegration -RepoRoot C:/QM/repo -SkipCompile`
  - Result: `PASS`, 0 failures, 16 existing shared-framework DWX advisory
    warnings.
  - Report: `D:\QM\reports\framework\21\build_check_20260701_010454.json`.

## CPU Ceiling

No manual MT5 tester run was launched. All T1-T5 workers were active, so the Q05
row was left pending for the paced fleet.

## Guardrails

- No `T_Live` manifest touched.
- AutoTrading not toggled.
- No portfolio admission, portfolio KPI, Q08 contribution, or deploy manifest
  files touched.
- Q05 remains a RISK_FIXED backtest queue item.
