# QM5_10009 Q04 Latest-PASS Enqueue - 2026-07-02

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate or live-manifest edits.

## Mission Route

The controlling FX cointegration scan remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. It documents only two
strict 66-pair survivors: `QM5_12533` and `QM5_12532`. Both are already built
and no longer Q02-blocked:

| EA | Current state checked |
|---|---|
| `QM5_12532` | logical Q02 `PASS`, Q04 `PASS`, latest Q05 `INFRA_FAIL` with `summary_missing` / crash-style exit code after earlier timeout-payload repair |
| `QM5_12533` | logical Q02 `PASS`, later Q04 completed as strategy `FAIL` |

No non-duplicate unbuilt strict FX cointegration pair remains in the local
EdgeLab frontier. This pass used the mission fallback: advance an existing
market-neutral FX cointegration sleeve through the funnel.

## Target

`QM5_10009_rw-fx-cointeg-bb`

- Logical basket: `QM5_10009_AUD_NZD_CAD_COINTEG_D1`
- Host/timeframe: `AUDUSD.DWX`, `D1`
- Basket symbols: `AUDUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`
- Setfile:
  `framework/EAs/QM5_10009_rw-fx-cointeg-bb/sets/QM5_10009_rw-fx-cointeg-bb_QM5_10009_AUD_NZD_CAD_COINTEG_D1_D1_backtest.set`
- Manifest:
  `framework/EAs/QM5_10009_rw-fx-cointeg-bb/basket_manifest.json`

## Fix

`farmctl enqueue-backtest --ea <EA> --phase Q04` scans done Q02 `PASS` rows for
the EA. `QM5_10009` had two logical Q02 PASS rows:

| Work item | Updated | Note |
|---|---|---|
| `18f70d58-1419-4109-9b34-5c03ac3c884f` | 2026-06-30T03:46:42Z | older logical Q02 PASS |
| `2ae2c04e-5b5c-47de-a9eb-c46caeeefe0a` | 2026-07-01T13:30:54Z | latest logical Q02 PASS after review rework |

The cascade query previously ordered prior PASS rows oldest-first, which could
requeue an existing Q04 row from stale prior evidence and then skip the newer
PASS as already pending. `tools/strategy_farm/farmctl.py` now orders prior PASS
rows newest-first. A focused regression was added in
`tools/strategy_farm/tests/test_farmctl_cascade.py`.

## Queue Action

Backup before the initial queue mutation:
`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_10009_q04_enqueue_20260702_154959.sqlite`

Command:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_10009 --phase Q04
```

Result:

| Field | Value |
|---|---|
| Work item | `52731ceb-42b5-4b20-94b9-3e7785fe2546` |
| Action | requeued existing Q04 row, no duplicate insert |
| Status | `pending` |
| Verdict | `NULL` |
| Claimed by | `NULL` |

Because the code fix landed after the first enqueue command, the pending row was
then refreshed from the latest Q02 PASS using the same farmctl payload helpers.

Backup before payload refresh:
`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_10009_q04_payload_refresh_20260702T135239Z0000.sqlite`

Payload after refresh:

| Field | Value |
|---|---|
| `promoted_from_work_item` | `2ae2c04e-5b5c-47de-a9eb-c46caeeefe0a` |
| `q04_latest_full_year` | `2024` |
| `q04_history_checked_window` | `2023-2024` |
| `q04_history_checked_symbols` | `AUDUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX` |
| `portfolio_scope` | `basket` |

No manual MT5 backtest was launched. The paced worker owns the pending Q04 row.

## Validation

- `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_10009_rw-fx-cointeg-bb --verbose --json`: `BASKET_OK`, 0 violations.
- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_10009_rw-fx-cointeg-bb -RepoRoot C:/QM/repo -SkipCompile`: PASS, 0 failures, 19 advisory warnings.
- Build-check report: `D:/QM/reports/framework/21/build_check_20260702_134935.json`.
- Build-check refreshed the four QM5_10009 backtest setfile hashes; all remain
  `environment=backtest`, `risk_mode=FIXED`, `RISK_FIXED=1000`, and
  `RISK_PERCENT=0`.
- `python -m unittest tools.strategy_farm.tests.test_farmctl_cascade`: PASS, 17 tests.
- `git diff --check -- tools/strategy_farm/farmctl.py tools/strategy_farm/tests/test_farmctl_cascade.py`: PASS, line-ending warnings only.

Safety checks:

- `farmctl mt5-slots`: no pipeline terminal worker was active; one unrelated
  non-pipeline T5 smoke process existed and was not touched.
- `T_Live` process was observed only by `mt5-slots`; no live file, manifest, or
  AutoTrading setting was changed.
