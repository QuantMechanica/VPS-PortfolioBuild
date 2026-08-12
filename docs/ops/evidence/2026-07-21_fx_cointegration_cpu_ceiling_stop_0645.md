# FX Cointegration CPU Ceiling Stop — 2026-07-21 06:45 Europe/Berlin

Mission: grow the certified V5 forex sleeve book with market-neutral FX
cointegration baskets, preferring a Q02 repair for `QM5_12532` or `QM5_12533`
and otherwise advancing one non-duplicate existing forex basket.

## Frontier decision

The canonical 66-pair scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` has no unbuilt strict
survivor. Its only two qualifying pairs are already built and past Q02:

| Basket | Pair | Current decisive evidence |
|---|---|---|
| `QM5_12532` | AUDUSD / NZDUSD | Q02 `PASS`, Q04 `PASS`, Q05 `FAIL` |
| `QM5_12533` | EURJPY / GBPJPY | Q02 `PASS`, Q04 `FAIL` |

The previously active extended-frontier basket `QM5_13029` GBPCAD / GBPNZD is
also no longer a Q02 candidate: Q02 and Q03 passed, then Q04 failed. Creating a
new card from a pair that failed the scan's reputable-source threshold would
duplicate or weaken the approved frontier, so the mission fallback would be to
advance an existing forex basket.

## CPU ceiling stop

At `2026-07-21 06:44:32 +02:00`, read-only `farmctl.py mt5-slots` inspection
showed active tester runs on `T2`, `T3`, `T4`, `T8`, and `T10`. The paced-fleet
launch gate is `1` (`D:/QM/strategy_farm/state/launch_gate_max.txt`). The CPU
ceiling was therefore already occupied/exceeded, so no backtest was enqueued,
reprioritized, dispatched, or launched.

Active work at the snapshot:

| Terminal | Work |
|---|---|
| `T2` | pipeline run for `QM5_9502` |
| `T3` | `QM5_12836` Q03 |
| `T4` | `QM5_10687` Q02 |
| `T8` | `QM5_13144` Q07 |
| `T10` | `QM5_10287` Q07 |

## Safety

No MT5 process was started or stopped. `T_Live`, AutoTrading, deploy manifests,
portfolio admission/KPI/Q08-contribution gates, EA sources, and farm queue rows
were not modified. Existing unrelated worktree changes were preserved.

Machine-readable companion:
`artifacts/fx_cointegration_cpu_ceiling_stop_20260721T0645_board_advisor.json`.
