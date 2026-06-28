# QM5_12728 FX Cointegration Q02 Requeue - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan artifact. Its strict-threshold survivors,
`QM5_12533` and `QM5_12532`, have both reached logical-basket Q02 `PASS` and
later produced Q04 strategy failures. The later relaxed next-best baskets
`QM5_12624`, `QM5_12712`, `QM5_12723`, and `QM5_12728` are already built, so no
unbuilt non-duplicate pair remained in this pass.

Per the mission fallback, I advanced an existing forex basket: `QM5_12728`
NZDUSD/GBPJPY, the newest built FX cointegration sleeve.

## Prior Q02 Evidence

The first `QM5_12728` logical-basket Q02 row returned an infra failure, not an
EA `OnInit` failure:

| Field | Value |
|---|---|
| Prior work item | `8ecabdc1-8f54-4eff-aa86-ddd4734ba1b0` |
| Verdict | `INFRA_FAIL` |
| Reason classes | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| Evidence | `D:/QM/reports/work_items/8ecabdc1-8f54-4eff-aa86-ddd4734ba1b0/QM5_12728/20260627_235413/summary.json` |
| Tester log signal | `GBPUSD.DWX: history synchronization error` on `T2` |

`build_check.ps1 -EALabel QM5_12728_edgelab-nzdusd-gbpjpy-cointegration
-SkipCompile` passed before requeue. Report:
`D:/QM/reports/framework/21/build_check_20260628_003310.json`.

## Queue Action

Inserted one non-duplicate logical-basket Q02 row in
`D:/QM/strategy_farm/state/farm_state.sqlite`.

| Field | Value |
|---|---|
| New work item | `14a6ae04-aad9-4561-bb0d-d7e350a83925` |
| EA | `QM5_12728` |
| Symbol | `QM5_12728_NZDUSD_GBPJPY_COINTEGRATION_D1` |
| Status at insert | `pending` |
| Setfile | `framework/EAs/QM5_12728_edgelab-nzdusd-gbpjpy-cointegration/sets/QM5_12728_edgelab-nzdusd-gbpjpy-cointegration_QM5_12728_NZDUSD_GBPJPY_COINTEGRATION_D1_D1_backtest.set` |
| Host symbol/timeframe | `NZDUSD.DWX`, `D1` |
| Basket manifest | `framework/EAs/QM5_12728_edgelab-nzdusd-gbpjpy-cointegration/basket_manifest.json` |
| Tester currency/deposit | `USD`, `100000` |
| Risk fixed | `1000` |
| Timeout | `120` minutes |
| Priority track | `true` |
| Enqueued by | `codex_board_advisor_qm5_12728_post_infra_q02_requeue_2026-06-28` |
| DB backup | `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_12728_q02_requeue_20260628_003403.sqlite` |

No manual MT5 run was launched. At queue time the factory already had 7 active
worker-owned backtests and 5003 pending work items. The paced worker then
claimed the new row immediately:

| Field | Value |
|---|---|
| Status at verification | `active` |
| Claimed by | `T5` |
| Worker PID | `13524` |
| MT5 child PID | `10300` |
| Updated at | `2026-06-28T00:34:42+00:00` |
| Report root | `D:/QM/reports/work_items/14a6ae04-aad9-4561-bb0d-d7e350a83925` |

Stopped here under the CPU-ceiling discipline. The worker owns the running Q02
attempt; no duplicate row or manual tester launch was created.
