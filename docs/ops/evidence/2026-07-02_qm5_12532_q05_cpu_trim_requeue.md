# QM5_12532 Q05 CPU-Trim Requeue

Date: 2026-07-02
Branch: `agents/board-advisor`

## Scope

Mission fallback path was used. The controlling scan
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` documents only two
strict 66-pair FX cointegration survivors, `QM5_12533` and `QM5_12532`; both
are already built and neither is currently blocked at Q02. The allocated
EdgeLab FX cointegration tail through `QM5_12803` also already has matching EA
folders, so no non-duplicate unbuilt pair was available.

Selected existing forex basket:

- EA: `QM5_12532_edgelab-audnzd-cointegration`
- Logical basket: `QM5_12532_AUDNZD_COINTEGRATION_D1`
- Host/run symbol: `AUDUSD.DWX`
- Prior state: Q02 `PASS`, Q04 `PASS`, latest Q05 `INFRA_FAIL`

## Finding

The latest Q05 aggregate for work item
`82cab3d1-bf05-4aa4-8278-86c8064b16e7` was infrastructure-invalid:

- reason: `invalid_summary:INCOMPLETE_RUNS,TIMEOUT`
- runner timeout: 3420 seconds
- summary:
  `D:\QM\reports\work_items\82cab3d1-bf05-4aa4-8278-86c8064b16e7\QM5_12532\20260630_041853\summary.json`

The EA tick path also performed a redundant host-symbol news lookup after
`Strategy_NewsFilterHook()` had already checked both AUDUSD/NZDUSD basket legs.
That duplicate call ran on every tick during the full-history Q05 model-4 run.

## Code Change

`framework/EAs/QM5_12532_edgelab-audnzd-cointegration/QM5_12532_edgelab-audnzd-cointegration.mq5`
now relies on `Strategy_NewsFilterHook()` for basket news gating and removes the
second per-tick `_Symbol` news check.

`SPEC.md` revision history was updated with the Q05 CPU-trim note. Strict
compile refreshed the `.ex5` and setfile build hashes.

## Queue Action

Command:

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12532 --phase Q05
```

Result:

| Field | Value |
|---|---|
| Requeued work item | `82cab3d1-bf05-4aa4-8278-86c8064b16e7` |
| Created rows | `0` |
| Status after | `pending` |
| Verdict after | `null` |
| Updated at | `2026-07-01T23:05:11+00:00` |
| Archived prior report root | `D:\QM\reports\work_items\82cab3d1-bf05-4aa4-8278-86c8064b16e7.requeued_20260701T2305110000` |

Payload retained basket context:

- `portfolio_scope`: `basket`
- `logical_symbol`: `QM5_12532_AUDNZD_COINTEGRATION_D1`
- `host_symbol`: `AUDUSD.DWX`
- `host_timeframe`: `D1`
- `tester_currency`: `USD`
- `tester_deposit`: `100000`
- `q04_latest_full_year`: `2024`

## Validation

```text
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12532_edgelab-audnzd-cointegration/QM5_12532_edgelab-audnzd-cointegration.mq5 -Strict
python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12532_edgelab-audnzd-cointegration --verbose
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12532_edgelab-audnzd-cointegration -RepoRoot C:/QM/repo -SkipCompile
python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py -q
```

Results:

- Strict compile: `PASS`
- Symbol scope: `BASKET_OK`, 0 violations
- Build check: `PASS`, 0 failures, 16 existing shared-framework DWX advisory warnings
- Basket manifest tests: `6 passed`

Safety: no manual MT5 tester run was launched, no `T_Live` or AutoTrading
touched, and no portfolio admission/KPI/Q08 contribution or deploy manifest
files were edited.
