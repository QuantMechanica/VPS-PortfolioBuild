# QM5_12533 Detached-Terminal Q02 Reclassification - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan. It documents only two strict-threshold
market-neutral FX cointegration survivors:

- `QM5_12533` EURJPY/GBPJPY D1 basket.
- `QM5_12532` AUDUSD/NZDUSD D1 basket, already logical-basket Q02 `PASS`; later
  Q04 failed for low pooled fold trades.

No third unbuilt strict-threshold FX cointegration pair exists in that scan, so
this pass continued unblocking `QM5_12533` instead of creating a weaker duplicate
card.

## Worker Fix

The latest `QM5_12533` Q02 row was incorrectly left as `INFRA_FAIL` because the
worker classified the work item after the `run_smoke.ps1` parent process exited,
while the detached T7 `terminal64.exe` was still running. MT5 later completed and
wrote a valid final `summary.json`.

Fixed in `tools/strategy_farm/terminal_worker.py`:

- keep monitoring the terminal slot when the parent PID is gone but the claimed
  factory terminal is still alive;
- stop the terminal slot as well as the parent on timeout/stall cleanup;
- do not classify a short run as `launch_fault` when a real summary is already
  present.

Regression coverage:

- `test_monitor_waits_for_detached_terminal_summary`
- deterministic RAM probe in `test_q02_logical_basket_claims_before_ordinary_winner_pool`

Validation:

```text
python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q
15 passed
```

## Q02 Reclassification

Database backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12533_detached_terminal_q02_reclass_20260627_112223Z.sqlite`

Work item repaired:

| Field | Value |
|---|---|
| Work item | `76cb11ee-7e9d-4d75-be9d-626c205bca62` |
| EA | `QM5_12533` |
| Symbol | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` |
| Old status / verdict | `done` / `INFRA_FAIL` |
| Old evidence | `D:/QM/reports/work_items/76cb11ee-7e9d-4d75-be9d-626c205bca62/QM5_12533/20260627_083939/summary.json` |
| New status / verdict | `done` / `PASS` |
| New evidence | `D:/QM/reports/work_items/76cb11ee-7e9d-4d75-be9d-626c205bca62/QM5_12533/20260627_092645/summary.json` |

Final Q02 smoke evidence from the repaired summary:

| Metric | Value |
|---|---:|
| Result | `PASS` |
| Model | `4` |
| Real-tick marker | `true` |
| Trades | `170` |
| Profit factor | `0.98` |
| Net profit | `-52,115 JPY` |
| Drawdown | `313,489 JPY (2%)` |

`ea_metrics` was refreshed for `QM5_12533`; the repaired row now records the real
Q02 metrics above. Because net profit is negative, the normal Q02-to-Q03 profit
prefilter should not promote this row into Q03.

## Follow-On State

The scheduled paced fleet detected the repaired Q02 `PASS` and inserted/claimed
the existing Q04 default probe path:

| Field | Value |
|---|---|
| Work item | `7b8a32f6-0daa-4b55-8a48-b8815ba20550` |
| Phase | `Q04` |
| Status | `active` |
| Claimed by | `T4` |
| Promotion source | `pump_q04_early_probe` |
| Promoted from | `76cb11ee-7e9d-4d75-be9d-626c205bca62` |
| Runner | `framework/scripts/q04_walkforward.py` |
| Active process | `pwsh.exe` PID `11224`; `terminal64.exe` PID `10996` on `D:/QM/mt5/T4` |
| Report root | `D:/QM/reports/work_items/7b8a32f6-0daa-4b55-8a48-b8815ba20550` |

No manual tester was launched. No additional Q02 duplicate was inserted.

## Stop Condition

Stopped under the mission CPU-ceiling rule: `QM5_12533` is now consuming a paced
T4 worker slot in Q04, so the next useful action is to let the worker finish and
then classify the Q04 result.
