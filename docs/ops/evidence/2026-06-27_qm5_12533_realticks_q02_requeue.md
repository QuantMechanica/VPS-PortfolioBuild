# QM5_12533 Real-Tick Classifier Q02 Requeue - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling 66-pair
FX cointegration scan. It documents only two strict-threshold survivors:

- `QM5_12533` EURJPY/GBPJPY D1 market-neutral cointegration basket.
- `QM5_12532` AUDUSD/NZDUSD D1 market-neutral cointegration basket.

No third unbuilt FX cointegration pair from that scan meets the documented build threshold,
so this action advances the existing blocked forex basket rather than creating a weak duplicate.

The latest `QM5_12533` logical-basket Q02 row
`e13e4576-f46d-446e-bd3a-ce70ec4ae9fd` was marked `INFRA_FAIL` with
`NO_REAL_TICKS;INCOMPLETE_RUNS`. Its MT5 evidence was not actually a no-history or no-real-ticks
run:

- `report.htm` shows `History Quality: 100% real ticks`.
- tester log shows `EURJPY.DWX,Daily: 427767746 ticks, 1684 bars generated`.
- tester log shows `1566380513 total ticks for all symbols`.
- runtime was about 67 minutes, not a fast empty launch.

The false infra verdict came from `framework/scripts/run_smoke.ps1` only accepting the legacy
`generating based on real ticks` log marker before applying the zero-trade fast-finish guard.

## Code Fix

Added `Test-ReportShowsRealTicks` to `framework/scripts/run_smoke.ps1` and use it as a fallback
model-4 evidence source when the legacy tester-log marker is absent. This keeps valid zero-trade
reports from being classified as `NO_REAL_TICKS_MARKER_FAST_FINISH`.

Regression test added:

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/tests/Test-RunSmokeRealTicksReportEvidence.ps1
```

## Queue Action

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_12533_realticks_q02_requeue_20260626_221943.sqlite`

Inserted one non-duplicate logical-basket Q02 row:

| Field | Value |
|---|---|
| Parent task | `972054f2-113d-4577-b6be-c0356c0f360c` |
| Work item | `e9e4e602-77e2-441f-8709-a13ec0285496` |
| EA | `QM5_12533` |
| Symbol | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` |
| Host | `EURJPY.DWX`, `D1` |
| Payload | `portfolio_scope=basket`, `tester_currency=JPY`, `timeout_min=120`, `priority_track=true` |
| Inserted status | `pending` |
| Current status after post-insert check | `active`, claimed by `T1` at `2026-06-26T22:20:49+00:00` |
| Enqueued UTC | `2026-06-26T22:20:21+00:00` |

Post-insert check confirmed this is the only `pending` or `active` row for the
`QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` target.

## Validation

- `build_check.ps1 -EALabel QM5_12533_edgelab-eurjpy-gbpjpy-cointegration -SkipCompile`: `PASS`, 0 failures, 16 existing framework include advisory warnings.
- `Test-RunSmokeRealTicksReportEvidence.ps1`: `PASS`.
- `Test-RunSmokeOnInitTradeScope.ps1`: `PASS`.
- `Test-RunSmokeNoHistoryScope.ps1`: `PASS`.

No backtest was launched manually. The paced terminal worker owns the pending Q02 row.
