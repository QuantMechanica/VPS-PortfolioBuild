# 7c0eb88f Basket Symbol Mismatch Q02 Reset

Task: `7c0eb88f-0a65-4f00-b8c6-0edffac4c6b7`

Repository used: `C:/QM/repo`

## Scope

Routed task requested the basket/index symbol mismatch fix for:

`QM5_10209`, `QM5_1075`, `QM5_1181`, `QM5_1182`, `QM5_1207`, `QM5_1209`, `QM5_1210`, `QM5_1211`, `QM5_1212`, `QM5_1214`, `QM5_1215`, `QM5_1217`, `QM5_1218`, `QM5_1220`, `QM5_1221`.

The scheduled worktree `C:/QM/worktrees/codex-orchestration-1` did not contain these EA directories. The canonical repo checkout `C:/QM/repo` did contain them, so verification and queue work were executed there.

## Source State

No source edit was needed in `C:/QM/repo`: the target EA `.mq5` files and setfiles already used imported `.DWX` symbols such as `GDAXI.DWX`, `UK100.DWX`, `JPN225.DWX`, `XAUUSD.DWX`, and `XTIUSD.DWX`.

Bad-symbol verification:

```powershell
rg -n "GER40\.DWX|FRA40\.DWX|XCUUSD\.DWX|AUS200\.DWX" `
  framework/EAs/QM5_10209_tv-atr-ema-session `
  framework/EAs/QM5_1075_as-accel-dualmom `
  framework/EAs/QM5_1181_qp-pre-ecb-dax `
  framework/EAs/QM5_1182_qp-ecb-d0-dax-short `
  framework/EAs/QM5_1207_bbadx-index-skew `
  framework/EAs/QM5_1209_carver-mrinasset `
  framework/EAs/QM5_1210_carver-skewabs `
  framework/EAs/QM5_1211_carver-skewrv `
  framework/EAs/QM5_1212_carver-kurtsabs `
  framework/EAs/QM5_1214_vidal-holiday-effect `
  framework/EAs/QM5_1215_papailias-ma-trail `
  framework/EAs/QM5_1217_zarattini-donchian-ensemble `
  framework/EAs/QM5_1218_carver-relmomentum `
  framework/EAs/QM5_1220_carver-mrwings `
  framework/EAs/QM5_1221_carver-kurtsrv `
  -g "*.mq5" -g "*.set" -g "SPEC.md" -g "strategy_card.md"
```

Result: no matches.

## Compile Verification

Strict compile command used per EA:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EALabel <label> -Strict
```

Initial compile pass hit transient include-copy locks on some MetaQuotes include directories. Retrying only the failed subset succeeded. Final strict compile result:

| EA label | Result | Errors | Warnings | Final log |
|---|---:|---:|---:|---|
| QM5_10209_tv-atr-ema-session | PASS | 0 | 0 | `C:/QM/repo/framework/build/compile/20260625_183538/QM5_10209_tv-atr-ema-session.compile.log` |
| QM5_1075_as-accel-dualmom | PASS | 0 | 0 | `C:/QM/repo/framework/build/compile/20260625_183542/QM5_1075_as-accel-dualmom.compile.log` |
| QM5_1181_qp-pre-ecb-dax | PASS | 0 | 0 | `C:/QM/repo/framework/build/compile/20260625_183548/QM5_1181_qp-pre-ecb-dax.compile.log` |
| QM5_1182_qp-ecb-d0-dax-short | PASS | 0 | 0 | `C:/QM/repo/framework/build/compile/20260625_183653/QM5_1182_qp-ecb-d0-dax-short.compile.log` |
| QM5_1207_bbadx-index-skew | PASS | 0 | 0 | `C:/QM/repo/framework/build/compile/20260625_183659/QM5_1207_bbadx-index-skew.compile.log` |
| QM5_1209_carver-mrinasset | PASS | 0 | 0 | `C:/QM/repo/framework/build/compile/20260625_183703/QM5_1209_carver-mrinasset.compile.log` |
| QM5_1210_carver-skewabs | PASS | 0 | 0 | `C:/QM/repo/framework/build/compile/20260625_183709/QM5_1210_carver-skewabs.compile.log` |
| QM5_1211_carver-skewrv | PASS | 0 | 0 | `C:/QM/repo/framework/build/compile/20260625_183714/QM5_1211_carver-skewrv.compile.log` |
| QM5_1212_carver-kurtsabs | PASS | 0 | 0 | `C:/QM/repo/framework/build/compile/20260625_183556/QM5_1212_carver-kurtsabs.compile.log` |
| QM5_1214_vidal-holiday-effect | PASS | 0 | 0 | `C:/QM/repo/framework/build/compile/20260625_183602/QM5_1214_vidal-holiday-effect.compile.log` |
| QM5_1215_papailias-ma-trail | PASS | 0 | 0 | `C:/QM/repo/framework/build/compile/20260625_183608/QM5_1215_papailias-ma-trail.compile.log` |
| QM5_1217_zarattini-donchian-ensemble | PASS | 0 | 0 | `C:/QM/repo/framework/build/compile/20260625_183721/QM5_1217_zarattini-donchian-ensemble.compile.log` |
| QM5_1218_carver-relmomentum | PASS | 0 | 0 | `C:/QM/repo/framework/build/compile/20260625_183727/QM5_1218_carver-relmomentum.compile.log` |
| QM5_1220_carver-mrwings | PASS | 0 | 0 | `C:/QM/repo/framework/build/compile/20260625_183733/QM5_1220_carver-mrwings.compile.log` |
| QM5_1221_carver-kurtsrv | PASS | 0 | 0 | `C:/QM/repo/framework/build/compile/20260625_183615/QM5_1221_carver-kurtsrv.compile.log` |

## Guardrails

Command:

```powershell
python tools/strategy_farm/validate_build_guardrails.py `
  framework/EAs/QM5_10209_tv-atr-ema-session `
  framework/EAs/QM5_1075_as-accel-dualmom `
  framework/EAs/QM5_1181_qp-pre-ecb-dax `
  framework/EAs/QM5_1182_qp-ecb-d0-dax-short `
  framework/EAs/QM5_1207_bbadx-index-skew `
  framework/EAs/QM5_1209_carver-mrinasset `
  framework/EAs/QM5_1210_carver-skewabs `
  framework/EAs/QM5_1211_carver-skewrv `
  framework/EAs/QM5_1212_carver-kurtsabs `
  framework/EAs/QM5_1214_vidal-holiday-effect `
  framework/EAs/QM5_1215_papailias-ma-trail `
  framework/EAs/QM5_1217_zarattini-donchian-ensemble `
  framework/EAs/QM5_1218_carver-relmomentum `
  framework/EAs/QM5_1220_carver-mrwings `
  framework/EAs/QM5_1221_carver-kurtsrv
```

Result: `PASS` for all fifteen directories. `max_news_stale_hours` remained `336`; no `RISK_PERCENT` or stale-news bypass findings.

## Q02 Queue Reset

The active queue database was `D:/QM/strategy_farm/state/farm_state.sqlite`.

Before the reset, the target Q02 rows were terminal:

- `done/FAIL`: 2
- `done/INFRA_FAIL`: 27
- `failed/<blank verdict>`: 9
- `failed/INFRA_FAIL`: 1001

There were zero active Q02 rows for the target EAs, so no live backtest was interrupted.

Backup created before modification:

`D:/QM/strategy_farm/state/backups/farm_state_pre_7c0eb88f_q02_symbol_reset_20260625_184000.sqlite`

Transaction result:

- Updated rows: 1039
- Final target Q02 state: `pending`, blank verdict, `attempt_count=0`, no claim/evidence path.

Final pending counts:

| EA | Pending Q02 rows |
|---|---:|
| QM5_10209 | 10 |
| QM5_1075 | 24 |
| QM5_1181 | 12 |
| QM5_1182 | 12 |
| QM5_1207 | 36 |
| QM5_1209 | 108 |
| QM5_1210 | 96 |
| QM5_1211 | 108 |
| QM5_1212 | 96 |
| QM5_1214 | 48 |
| QM5_1215 | 60 |
| QM5_1217 | 72 |
| QM5_1218 | 141 |
| QM5_1220 | 84 |
| QM5_1221 | 132 |

## Result

`PASS`: target basket/index EAs reference available `.DWX` symbols, all fifteen strict-compile cleanly, guardrails pass, and their Q02 work_items are pending for re-run.

Systemic recommendation not implemented here: add a dispatch-time symbol-alias map so future cards that say `GER40`/`FRA40` can normalize to the imported custom symbols before build/enqueue.
