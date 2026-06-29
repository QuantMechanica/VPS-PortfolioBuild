# QM5_12778 AUDUSD/EURJPY Conversion-History Repair

Date: 2026-06-29
Branch: `agents/board-advisor`

## Scope

- EA: `QM5_12778_edgelab-audusd-eurjpy-cointegration`
- Logical symbol: `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`
- Traded legs: `AUDUSD.DWX`, `EURJPY.DWX`
- Conversion history: `EURUSD.DWX`, `USDJPY.DWX`
- Host/timeframe: `AUDUSD.DWX`, `D1`
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`

`QM5_12532` and `QM5_12533` were checked first; both already had logical-basket
Q02 PASS rows, so there was no active ONINIT/NO_HISTORY repair to prefer.

## Failure Diagnosis

Prior Q02 work item:

| field | value |
|---|---|
| id | `8f0e511f-0f93-42eb-b2c5-b07e1f7a6f1e` |
| status/verdict | `done` / `INFRA_FAIL` |
| reason classes | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| evidence | `D:/QM/reports/work_items/8f0e511f-0f93-42eb-b2c5-b07e1f7a6f1e/QM5_12778/20260629_134605/summary.json` |

The tester reached normal EA runtime and placed both basket legs, so this was
not an ONINIT failure or a missing `.DWX` traded-leg issue. The terminal log
then synchronized `EURUSD.DWX`, fell through to bare `USDJPY`, timed out on
history sync, and produced an empty final report. That matches a conversion
preload gap for EURJPY accounting in a USD tester account.

## Repair

- Added explicit preselection of `EURUSD.DWX` and `USDJPY.DWX` before framework
  initialization.
- Expanded the basket warmup/guard symbol scope to
  `AUDUSD.DWX`, `EURJPY.DWX`, `EURUSD.DWX`, `USDJPY.DWX`.
- Updated `basket_manifest.json` so the farm's basket history scope includes
  the conversion symbols. Only `AUDUSD.DWX` and `EURJPY.DWX` are traded legs.
- Left strategy logic, beta, z-score thresholds, exits, and fixed-risk settings
  unchanged.

## Verification

Static symbol scope:

```text
python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12778_edgelab-audusd-eurjpy-cointegration --verbose
BASKET_OK
foreign symbols referenced: EURUSD.DWX, USDJPY.DWX
manifest declares: 4 symbols
```

Fixed-risk setfile check:

```text
RISK_FIXED=1000
RISK_PERCENT=0
PORTFOLIO_WEIGHT=1
```

Strict compile:

```text
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12778_edgelab-audusd-eurjpy-cointegration/QM5_12778_edgelab-audusd-eurjpy-cointegration.mq5 -Strict
compile_one.result=PASS
errors=0
warnings=0
log=C:\QM\repo\framework\build\compile\20260629_143633\QM5_12778_edgelab-audusd-eurjpy-cointegration.compile.log
```

Build check:

```text
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12778_edgelab-audusd-eurjpy-cointegration -RepoRoot C:\QM\repo -SkipCompile
build_check.result=PASS
build_check.failures=0
build_check.warnings=16
report=D:\QM\reports\framework\21\build_check_20260629_143644.json
```

The 16 warnings are the existing shared-framework DWX advisory warnings seen on
adjacent basket builds; there were no build-check failures.

## Q02 Requeue

The repaired result artifact was written to:

`D:\QM\strategy_farm\artifacts\builds\e6ac4aae-f214-40f0-b037-1a9eeea4e2f8_conversion_repair_20260629T143819Z.json`

`farmctl record-build` accepted the repaired result and auto-enqueued one
replacement logical-basket Q02 work item:

| field | value |
|---|---|
| id | `7f04ff6a-35ca-45bd-a702-afc37b310f97` |
| status | `pending` |
| symbol | `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1` |
| enqueued by | `record_build_result.auto_q02` |
| basket symbol count | `4` |
| tester currency | `USD` |

Duplicate guard: after enqueue there is exactly one pending/active Q02 row for
`QM5_12778`; the original `8f0e511f-0f93-42eb-b2c5-b07e1f7a6f1e` row remains
`done/INFRA_FAIL` as prior evidence.

## Safety

- No manual MT5 backtest was launched from this session.
- Q02 execution is delegated to paced farm workers.
- No `T_Live` files were edited.
- AutoTrading was not touched.
- No `portfolio_admission`, `portfolio_kpi`, or `q08_contribution` artifacts
  were edited.
