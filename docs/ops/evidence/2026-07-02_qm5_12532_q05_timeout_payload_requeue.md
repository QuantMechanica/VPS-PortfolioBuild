# QM5_12532 Q05 Timeout-Payload Requeue - 2026-07-02

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan. It lists only two strict market-neutral FX
cointegration survivors:

| EA | Pair | Current state |
|---|---|---|
| `QM5_12532` | `AUDUSD.DWX` / `NZDUSD.DWX` | Q02 PASS, Q04 PASS, Q05 INFRA_FAIL |
| `QM5_12533` | `EURJPY.DWX` / `GBPJPY.DWX` | Q02 PASS, Q04 strategy FAIL |

There is no unbuilt strict-threshold FX cointegration pair in that scan, so this
action advanced the existing forex survivor `QM5_12532`.

## Code Repair

The latest `QM5_12532` Q05 retry failed with
`invalid_summary:INCOMPLETE_RUNS,TIMEOUT`. Its Q05 row had no `timeout_min`
payload, while the current Q05/Q06 stress runners and reaper budget expect a
120-minute outer budget for full-history stressed runs.

Changed `tools/strategy_farm/farmctl.py` so both cascade paths stamp the phase
timeout on Q05/Q06 work items:

- direct operator path: `farmctl enqueue-backtest --ea <EA> --phase Q05`
- pump path: automatic Q04 PASS -> Q05 promotion

Updated focused tests to lock the Q05/Q06 5400-second runner default and Q05
`timeout_min=120` promotion payload.

## Validation

- `python -m unittest framework.scripts.tests.test_q05_q07_verdicts tools.strategy_farm.tests.test_farmctl_cascade`: PASS, 31 tests.
- `git diff --check`: PASS, line-ending warnings only.
- `build_check.ps1 -EALabel QM5_12532_edgelab-audnzd-cointegration -SkipCompile`: PASS, 0 failures, 16 existing shared-framework advisory warnings.
- Build-check report: `D:/QM/reports/framework/21/build_check_20260702_100537.json`.
- `build_check` refreshed the `QM5_12532` setfile `build_hash` metadata; RISK_FIXED backtest risk settings remain unchanged.

## Queue Action

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_12532_q05_timeout_payload_requeue_20260702_100503.sqlite`

Ran:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12532 --phase Q05
```

Result: requeued the existing Q05 row, creating no duplicate.

| Field | Value |
|---|---|
| Work item | `82cab3d1-bf05-4aa4-8278-86c8064b16e7` |
| EA | `QM5_12532` |
| Symbol | `QM5_12532_AUDNZD_COINTEGRATION_D1` |
| Status after requeue | `pending` |
| Verdict after requeue | `NULL` |
| Attempt count | `0` |
| Timeout payload | `timeout_min=120` |
| Archived prior report root | `D:/QM/reports/work_items/82cab3d1-bf05-4aa4-8278-86c8064b16e7.requeued_20260702T1005080000` |
| Tester currency/deposit | `USD`, `100000` |
| Q04 source | `94f89f07-58ad-487f-a0ab-b57c4e99106a` |

Duplicate guard after mutation: exactly one pending/active Q05 row for
`QM5_12532` / `QM5_12532_AUDNZD_COINTEGRATION_D1`.

No manual MT5 launch was created. `farmctl mt5-slots` showed no active terminal
workers at verification time; a separate non-pipeline T5 smoke process existed
and was not touched.
