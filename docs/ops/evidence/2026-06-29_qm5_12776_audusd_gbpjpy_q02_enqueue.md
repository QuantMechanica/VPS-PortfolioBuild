# QM5_12776 AUDUSD/GBPJPY Cointegration Q02 Enqueue Evidence

Date: 2026-06-29
Branch: `agents/board-advisor`

## Scope

Built one new, non-duplicate V5 forex basket sleeve:

- EA: `QM5_12776_edgelab-audusd-gbpjpy-cointegration`
- Logical symbol: `QM5_12776_AUDUSD_GBPJPY_COINTEGRATION_D1`
- Legs: `AUDUSD.DWX`, `GBPJPY.DWX`
- Host: `AUDUSD.DWX`, `D1`
- Risk mode: backtest `RISK_FIXED=1000`, `RISK_PERCENT=0`

No portfolio gate, T_Live manifest, or AutoTrading state was touched.

## Selection

`QM5_12532` and `QM5_12533` already had logical-basket Q02 rows, so the mission
continued to the next unbuilt FX cointegration pair from the same 66-pair scan
family. The first unbuilt candidate after the existing 12532/12533/12624/12712/
12723/12728/12731/12732/12735/12739/12747/12749/12751/12756/12758/12760/
12762/12764/12765/12766/12768/12770/12772 baskets was:

| pair | rank | DEV Sharpe | OOS net Sharpe | OOS return | state changes | hedge beta | half-life |
|---|---:|---:|---:|---:|---:|---:|---:|
| AUDUSD~GBPJPY | 24 | 0.1257 | -0.2072 | -2.3438% | 19 | 0.189701 | 117.50d |

This is explicitly an exploratory tail candidate, not a strict hard-bar survivor.
The card records that distinction.

## Build Evidence

Compile:

```text
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12776_edgelab-audusd-gbpjpy-cointegration/QM5_12776_edgelab-audusd-gbpjpy-cointegration.mq5 -Strict
compile_one.result=PASS
errors=0
warnings=0
log=C:\QM\repo\framework\build\compile\20260629_123710\QM5_12776_edgelab-audusd-gbpjpy-cointegration.compile.log
```

Build check:

```text
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12776_edgelab-audusd-gbpjpy-cointegration -RepoRoot C:\QM\repo -SkipCompile
build_check.result=PASS
build_check.failures=0
build_check.warnings=16
report=D:\QM\reports\framework\21\build_check_20260629_123754.json
```

Warnings were the shared-framework DWX advisories already seen on adjacent
cointegration baskets; no build-check failures were reported.

Hashes:

| artifact | sha256 |
|---|---|
| `.mq5` | `d17a7e9f0539c653acf4142fb6efdb6ede9774c28dcfc8e32c5be7c9609ddf08` |
| `.ex5` | `4f4ef53011a8f309d16fcd2f88aec13e19ad081e1df3593739aec567b8927632` |
| setfile | `bf7d50278a7cf66663dfbe2e65220e13ef2037af32cd3e2ef6a956b2541d49c7` |

## Q02 Evidence

Build task recorded:

```text
python tools/strategy_farm/farmctl.py record-build --task-id 8e41528c-5716-4003-97c4-0ebff1e9ec20 --result-file D:\QM\strategy_farm\artifacts\builds\8e41528c-5716-4003-97c4-0ebff1e9ec20.json
recorded=true
new_status=done
auto_q02_enqueued=1
```

Q02 work item:

| field | value |
|---|---|
| id | `5de6cce6-f2ee-4316-bf82-0b312fa625c0` |
| phase | `Q02` |
| status | `pending` |
| symbol | `QM5_12776_AUDUSD_GBPJPY_COINTEGRATION_D1` |
| setfile | `framework/EAs/QM5_12776_edgelab-audusd-gbpjpy-cointegration/sets/QM5_12776_edgelab-audusd-gbpjpy-cointegration_QM5_12776_AUDUSD_GBPJPY_COINTEGRATION_D1_D1_backtest.set` |

The auto-enqueued payload was repaired in place with basket legs, `USDJPY.DWX`
conversion history, tester deposit, fixed-risk settings, scan metrics, priority
tracking, and a 120-minute basket timeout. Backup before mutation:

```text
D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12776_priority_payload_20260629_124303Z.sqlite
```

## Safety

- No manual MT5 backtest was launched from this session.
- Q02 execution is delegated to paced farm workers.
- No T_Live files were edited.
- No AutoTrading controls were touched.
- No portfolio admission, KPI, or Q08 contribution gate files were edited.
