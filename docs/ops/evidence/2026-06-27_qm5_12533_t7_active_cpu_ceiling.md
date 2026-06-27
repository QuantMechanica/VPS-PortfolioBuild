# QM5_12533 T7 Active Q02 CPU-Ceiling State - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan artifact. It documents only two strict-threshold
market-neutral FX cointegration survivors:

- `QM5_12533` EURJPY/GBPJPY D1 basket, already built and currently in Q02.
- `QM5_12532` AUDUSD/NZDUSD D1 basket, logical-basket Q02 `PASS`; later Q04
  failed for low pooled fold trades.

No third unbuilt FX cointegration pair from that scan meets the documented build
threshold. The only non-duplicate action available in this pass was to verify
the current worker-owned `QM5_12533` Q02 state and stop under the CPU-ceiling
constraint.

## Current Farm State

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Checked at `2026-06-27T09:32:48Z` (`2026-06-27T11:32:48+02:00` local).

Active logical-basket Q02 row:

| Field | Value |
|---|---|
| Work item | `76cb11ee-7e9d-4d75-be9d-626c205bca62` |
| Parent task | `qm5-12533-post-claimfix-q02-requeue-20260627_083635-76cb11ee` |
| EA | `QM5_12533` |
| Symbol | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` |
| Status | `active` |
| Claimed by | `T7` |
| Enqueued | `2026-06-27T08:37:07+00:00` |
| Started | `2026-06-27T09:26:44+00:00` |
| Timeout | `120` minutes |
| Setfile | `C:/QM/repo/framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/sets/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1_D1_backtest.set` |
| Basket manifest | `C:/QM/repo/framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/basket_manifest.json` |
| Payload | `portfolio_scope=basket`, `tester_currency=JPY`, `tester_deposit=15000000`, `risk_fixed=150000`, `priority_track=true` |
| Supersedes | `433bf1fd-c82f-4d3f-934c-21b772eea5fc` |

This was the only pending/active logical-basket Q02 row for
`QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` at the time of inspection.

## Process Evidence

- Worker process: `pythonw.exe` PID `600`, path
  `C:/Users/Administrator/AppData/Local/Programs/Python/Python311/pythonw.exe`.
- Runner process: `pwsh.exe` PID `912`, path
  `C:/Program Files/PowerShell/7/pwsh.exe`.
- MT5 process: `terminal64.exe` PID `11644`, path `D:/QM/mt5/T7/terminal64.exe`.
- Tester process: `metatester64.exe` PID `760`, path
  `D:/QM/mt5/T7/metatester64.exe`.

Current tester config:

`D:/QM/reports/work_items/76cb11ee-7e9d-4d75-be9d-626c205bca62/QM5_12533/20260627_092645/raw/run_01/tester.ini`

Key fields:

- `Symbol=EURJPY.DWX`
- `Period=D1`
- `FromDate=2018.07.02`
- `ToDate=2024.12.31`
- `Deposit=15000000`
- `Currency=JPY`
- `ExpertParameters=QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1_D1_backtest.set`

T7 terminal log showed a fresh launch at `11:26:46` local from that tester.ini
and progress to `2%` at `11:31:53` local. The EA runtime log
`D:/QM/mt5/T7/Tester/Agent-127.0.0.1-3005/MQL5/Files/QM/QM5_12533_ea-12533.log`
was updating at the inspection time.

## Prior Attempt On Same Work Item

The same work item had an earlier run tag `20260627_083939` with summary:

- Result: `FAIL`
- Reason classes: `REPORT_MISSING`, `METATESTER_HUNG`, `INCOMPLETE_RUNS`
- Evidence: `D:/QM/reports/work_items/76cb11ee-7e9d-4d75-be9d-626c205bca62/QM5_12533/20260627_083939/summary.json`

That run was not a zero-trade launch fault. Its tester log tail showed actual
EURJPY/GBPJPY basket orders through 2019 before report export failed. The worker
then retried the same active item, producing the currently running
`20260627_092645` attempt.

## Stop Condition

No new Q02 row was inserted and no manual MT5 run was launched. The corrected
`QM5_12533` logical-basket Q02 is already consuming a paced T7 worker slot, so
starting another FX basket test would duplicate worker-owned CPU work. Stop here
under the mission CPU-ceiling constraint and let the worker finish or hit its
120-minute timeout.
