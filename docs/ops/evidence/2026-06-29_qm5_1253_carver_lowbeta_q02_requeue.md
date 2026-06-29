# QM5_1253 Carver Low-Beta RV Q02 Requeue - 2026-06-29

Scope: branch `agents/board-advisor`; no T_Live or AutoTrading actions.

## Target

- EA: `QM5_1253_carver-lowbeta-rv`
- Strategy family: Rob Carver low-beta relative value, D1 cross-sectional FX/index group ranking.
- Reason selected: no approved-card build backlog item was available that was both diverse and unbuilt; this EA had no pending/active farm rows before the repair and had repeated Q02 `INFRA_FAIL` rows on diverse D1 symbols.

## Diagnosis

The repeated Q02 failures were stale-artifact infra, not a strategy verdict:

- Latest failing EURUSD lane before this repair: `4d8e3312-1d8b-4f4c-a43e-c65c308458b8`
- Failure class: `summary_missing_retries_exhausted`
- Prior payload showed the failed run started `2026-06-25T04:51:38+00:00`.
- The EA artifacts were rebuilt later on `2026-06-25` and had not been re-entered into Q02 after that rebuild.

## Fix / Verification

Recompiled the EA strictly:

```text
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_1253_carver-lowbeta-rv/QM5_1253_carver-lowbeta-rv.mq5 -Strict
```

Result:

```text
compile_one.result=PASS
compile_one.errors=0
compile_one.warnings=0
compile_one.log=C:\QM\repo\framework\build\compile\20260629_001821\QM5_1253_carver-lowbeta-rv.compile.log
compile_one.summary=D:\QM\reports\compile\20260629_001821\summary.csv
```

This refreshed:

- `framework/EAs/QM5_1253_carver-lowbeta-rv/QM5_1253_carver-lowbeta-rv.ex5`

## Farm DB Action

Applied a targeted stranded-infra Q02 retry:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_1253 --queue-ceiling 999999 --max-infra-attempts 13
```

Queue state before enqueue was below the CPU ceiling: `pending=5434`, `active=4`.

Inserted 9 pending Q02 work items:

| Work item | Symbol |
|---|---|
| `8f426a11` | `NDX.DWX` |
| `3b4fa7b6` | `AUDUSD.DWX` |
| `d1bd125d` | `UK100.DWX` |
| `66ff703a` | `USDCAD.DWX` |
| `302d2703` | `WS30.DWX` |
| `3a3b26da` | `USDCHF.DWX` |
| `af0db577` | `USDJPY.DWX` |
| `9f735b8e` | `GBPUSD.DWX` |
| `92ebd723` | `EURUSD.DWX` |

Skipped stale lanes:

- `FRA40.DWX`: setfile missing.
- `GER40.DWX`: setfile missing.

Evidence JSON: `D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`.
