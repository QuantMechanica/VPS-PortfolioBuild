# QM5_12783 AUDUSD/AUDJPY Cointegration Basket Q02 Enqueue

Date: 2026-06-29
Branch: `agents/board-advisor`

## Scope

- EA: `QM5_12783_edgelab-audusd-audjpy-cointegration`
- Logical basket symbol: `QM5_12783_AUDUSD_AUDJPY_COINTEGRATION_D1`
- Traded legs: `AUDUSD.DWX`, `AUDJPY.DWX`
- Conversion history declared: `USDJPY.DWX`
- Host/timeframe: `AUDUSD.DWX`, `D1`
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`

`QM5_12532` and `QM5_12533` were checked first via recent evidence; both already
had logical-basket Q02 PASS rows, so no active ONINIT or NO_HISTORY repair was
preferred.

## Candidate Selection

A rerun of `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py` showed
the two hard survivor pairs remain `EURJPY~GBPJPY` and `AUDUSD~NZDUSD`. All
OOS-positive positive-hedge scan pairs are already built through the current FX
cointegration frontier. `AUDUSD~AUDJPY` is the next unbuilt positive-hedge tail
candidate by OOS net Sharpe after `QM5_12781`.

| pair | rank | DEV Sharpe | OOS net Sharpe | OOS ret | OOS state changes | hedge | half-life |
|---|---:|---:|---:|---:|---:|---:|---:|
| AUDUSD~AUDJPY | 27 | 0.3295 | -0.3601 | -3.8428% | 15 | 0.236355 | 139.55d |

This is an exploratory tail build, not a certified survivor. The card states the
negative OOS result explicitly.

## Build

- Approved card: `artifacts/cards_approved/QM5_12783_edgelab-audusd-audjpy-cointegration.md`
- EA source: `framework/EAs/QM5_12783_edgelab-audusd-audjpy-cointegration/QM5_12783_edgelab-audusd-audjpy-cointegration.mq5`
- Manifest: `framework/EAs/QM5_12783_edgelab-audusd-audjpy-cointegration/basket_manifest.json`
- Setfile: `framework/EAs/QM5_12783_edgelab-audusd-audjpy-cointegration/sets/QM5_12783_edgelab-audusd-audjpy-cointegration_QM5_12783_AUDUSD_AUDJPY_COINTEGRATION_D1_D1_backtest.set`
- Build task: `4c46a971-7c57-493f-999d-04c9b18ab510`
- Build result: `D:\QM\strategy_farm\artifacts\builds\4c46a971-7c57-493f-999d-04c9b18ab510.json`

Static scope:

```text
python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12783_edgelab-audusd-audjpy-cointegration --verbose
BASKET_OK
foreign symbols referenced: USDJPY.DWX
manifest declares: 3 symbols
```

Compile:

```text
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12783_edgelab-audusd-audjpy-cointegration/QM5_12783_edgelab-audusd-audjpy-cointegration.mq5 -Strict
compile_one.result=PASS
errors=0
warnings=0
log=C:\QM\repo\framework\build\compile\20260629_164005\QM5_12783_edgelab-audusd-audjpy-cointegration.compile.log
```

Build check:

```text
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12783_edgelab-audusd-audjpy-cointegration -RepoRoot C:\QM\repo -SkipCompile
build_check.result=PASS
build_check.failures=0
build_check.warnings=16
report=D:\QM\reports\framework\21\build_check_20260629_164037.json
```

The 16 warnings are the existing shared-framework DWX advisory warnings seen on
adjacent basket builds; there were no build-check failures.

## Q02 Enqueue

`farmctl record-build` accepted the build result and auto-enqueued one logical
Q02 basket row:

| field | value |
|---|---|
| work item | `1a2e412b-1229-4b97-a627-9491e264af63` |
| status | `pending` |
| phase | `Q02` |
| symbol | `QM5_12783_AUDUSD_AUDJPY_COINTEGRATION_D1` |
| setfile | `framework/EAs/QM5_12783_edgelab-audusd-audjpy-cointegration/sets/QM5_12783_edgelab-audusd-audjpy-cointegration_QM5_12783_AUDUSD_AUDJPY_COINTEGRATION_D1_D1_backtest.set` |
| enqueued by | `record_build_result.auto_q02` |
| basket symbol count | `3` |
| tester currency | `USD` |

Duplicate guard after enqueue: exactly one pending/active Q02 row exists for
`QM5_12783`.

## Safety

- No manual MT5 backtest was launched from this session.
- Q02 execution is delegated to paced farm workers.
- No `T_Live` files were edited.
- AutoTrading was not touched.
- No `portfolio_admission`, `portfolio_kpi`, or `q08_contribution` artifacts
  were edited.
