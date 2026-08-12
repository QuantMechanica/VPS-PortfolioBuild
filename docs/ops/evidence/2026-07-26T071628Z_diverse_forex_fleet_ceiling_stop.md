# Diverse forex handoff — occupied-fleet ceiling stop

- Observed UTC: `2026-07-26T07:16:28Z`
- Branch: `agents/board-advisor`
- Candidate: `QM5_20062_kats-eu-macisar`
- Instrument / timeframe: `EURUSD.DWX / D1`
- Farm build task: `ee2fe37e-5509-4371-8979-c58db2966313`

## Deterministic selection

The three pending build tasks were checked directly in
`D:/QM/strategy_farm/state/farm_state.sqlite`. `QM5_1457` and `QM5_1459`
remain blocked because their approved mechanical rules require unavailable
rates, lumber, or bond inputs. `QM5_20062` is therefore the only executable
pending build and the highest-diversity choice: a low-frequency EURUSD sleeve
against a survivor set concentrated in indices, metals, and energy.

The existing `QM5_20062` source, binary, SPEC, and `RISK_FIXED` backtest setfile
were already refreshed and strict-build validated. Its farm claim had been
released at `2026-07-26T06:18:23Z` after a capacity rejection. This observation
did not reclaim the task or create a duplicate build or Q02 work item.

## Occupied-fleet evidence

`farmctl.py mt5-slots` reported all nine configured factory lanes occupied by
active work items:

| Lane | EA | Phase | Symbol |
|---|---|---|---|
| T1 | QM5_1260 | Q04 | EURJPY.DWX |
| T2 | QM5_9454 | Q02 | GBPUSD.DWX |
| T3 | QM5_1567 | Q07 | EURUSD.DWX |
| T4 | QM5_9454 | Q02 | XAUUSD.DWX |
| T6 | QM5_1567 | Q07 | GBPJPY.DWX |
| T7 | QM5_9454 | Q02 | GDAXI.DWX |
| T8 | QM5_9454 | Q02 | NDX.DWX |
| T9 | QM5_12834 | Q03 | QM5_12834_XTI_USDJPY_SPREAD_D1 |
| T10 | QM5_1567 | Q07 | GBPNZD.DWX |

T5 had no registered worker lane in the same snapshot. Starting the required
one-pass smoke would therefore exceed the available backtest CPU capacity.
Execution stopped before any claim, tester launch, enqueue, retry, or mutation
of strategy artifacts.

## Safety

No T_Live path, AutoTrading setting, portfolio gate, or live manifest was
touched. Unrelated working-tree files were left unmodified.
