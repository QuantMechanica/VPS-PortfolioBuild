# QM5_12532 FX Cointegration Q05 Requeue - 2026-07-02

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan artifact. A read-only rerun of
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py` produced 29
positive-hedge ranked pairs; every ranked pair already has a corresponding
`framework/EAs/QM5_*_edgelab-*-cointegration` build and basket manifest.

The strict survivors are not Q02-blocked:

| EA | Pair | Current state |
|---|---|---|
| `QM5_12532` | `AUDUSD.DWX` / `NZDUSD.DWX` | Q02 PASS, Q04 PASS, Q05 INFRA_FAIL |
| `QM5_12533` | `EURJPY.DWX` / `GBPJPY.DWX` | Q02 PASS, Q04 FAIL |

Per the mission fallback, I advanced the existing strict survivor
`QM5_12532` instead of creating a duplicate tail card.

## Preflight

- EA: `QM5_12532_edgelab-audnzd-cointegration`
- Logical symbol: `QM5_12532_AUDNZD_COINTEGRATION_D1`
- Host: `AUDUSD.DWX`, `D1`
- Basket legs: `AUDUSD.DWX`, `NZDUSD.DWX`
- Manifest: `framework/EAs/QM5_12532_edgelab-audnzd-cointegration/basket_manifest.json`
- Setfile: `framework/EAs/QM5_12532_edgelab-audnzd-cointegration/sets/QM5_12532_edgelab-audnzd-cointegration_QM5_12532_AUDNZD_COINTEGRATION_D1_D1_backtest.set`
- Build check: PASS, 0 failures, 16 framework advisory warnings
- Build-check report: `D:/QM/reports/framework/21/build_check_20260702_030352.json`

Prior Q05 row:

| Field | Value |
|---|---|
| Work item | `82cab3d1-bf05-4aa4-8278-86c8064b16e7` |
| Prior verdict | `INFRA_FAIL` |
| Reason | `invalid_summary:INCOMPLETE_RUNS,TIMEOUT` |
| Evidence | `D:/QM/reports/work_items/82cab3d1-bf05-4aa4-8278-86c8064b16e7/QM5_12532/Q05/QM5_12532_AUDNZD_COINTEGRATION_D1/aggregate.json` |
| Promoted from | Q04 PASS work item `94f89f07-58ad-487f-a0ab-b57c4e99106a` |

## Queue Action

Created a SQLite backup before mutation:
`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_12532_q05_requeue_20260702_050416.sqlite`.

Ran:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_12532 --phase Q05
```

Result: the controller requeued the existing Q05 row instead of creating a
duplicate.

| Field | Value |
|---|---|
| Requeued work item | `82cab3d1-bf05-4aa4-8278-86c8064b16e7` |
| Status after requeue | `pending` |
| Verdict after requeue | `NULL` |
| Attempt count | `0` |
| Archived prior report root | `D:/QM/reports/work_items/82cab3d1-bf05-4aa4-8278-86c8064b16e7.requeued_20260702T0304210000` |
| Tester currency/deposit | `USD`, `100000` |
| Priority track | `true` |

Priority reason:
`OWNER 2026-07-02 forex portfolio fallback: strict 66-pair survivor QM5_12532 Q05 requeue after INFRA_FAIL timeout/incomplete run.`

## Stop Condition

At verification time the paced farm already had 5 active worker-owned backtests
and 5224 pending rows. I did not launch a manual MT5 run or dispatch a duplicate.
The worker queue owns the pending Q05 retry.
