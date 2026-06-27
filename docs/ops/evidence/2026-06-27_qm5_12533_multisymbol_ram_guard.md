# QM5_12533 Multi-Symbol RAM Guard - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan. It documents only two strict-threshold FX cointegration
survivors:

- `QM5_12532` AUDUSD/NZDUSD D1 basket: logical-basket Q02 `PASS`; later Q04 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY D1 basket: still the actionable blocked forex basket.

No third unbuilt FX cointegration pair in that scan meets the documented build threshold
(`DEV > 0`, OOS net Sharpe > 0.8, and at least 4 OOS trades), so this action continues
unblocking `QM5_12533` instead of creating a weaker duplicate card.

## Latest Q02 State

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Latest `QM5_12533` logical-basket Q02 row:

| Field | Value |
|---|---|
| Work item | `12165577-fb9d-40c3-a527-f41c57cb8c45` |
| Symbol | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` |
| Status | `done` |
| Verdict | `INFRA_FAIL` |
| Updated | `2026-06-27T05:44:16+00:00` |
| Evidence | `D:/QM/reports/work_items/12165577-fb9d-40c3-a527-f41c57cb8c45/QM5_12533/20260627_054136/summary.json` |

The run did not fail on EA `OnInit`. The summary classified `NO_HISTORY` because the
MT5 report had `Bars: 0`, while the tester journal ended with:

- `EURJPY.DWX,Daily: 0 ticks, 0 bars generated`
- `not enough available memory, 12883 Mb used, 3777 Mb available, maximal available block is 60 Mb`

This is a resource-ceiling empty-bar launch, not evidence that the basket card or `.DWX`
symbol history is structurally invalid.

## Code Fix

`tools/strategy_farm/terminal_worker.py` now requires higher free-RAM headroom before
claiming multi-symbol/basket work items:

- ordinary workers still use the existing `RAM_MIN_FREE_GB = 4.0` floor;
- multi-symbol jobs require `MULTISYMBOL_RAM_MIN_FREE_GB = 12.0`;
- when the multi-symbol floor is not met, the basket row remains `pending` and ordinary
  claimable work may continue draining.

This extends the existing farm-wide multi-symbol serialization guard and prevents a
priority basket from launching into the low-memory state that produced the false
`NO_HISTORY`/zero-bar Q02 evidence.

## Validation

```powershell
python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q
```

Result: `13 passed`.

## Queue Action

No replacement `QM5_12533` Q02 row was inserted in this pass.

Reason: the live fleet had active MT5/metatester processes and an active Q04 cointegration
basket (`QM5_1156_EURUSD_GBPUSD_COINTEGRATION_M30`, claimed by `T4`). The terminal workers
were already running before this code edit, so forcing a new `QM5_12533` row immediately
would risk another old-worker resource-ceiling launch. Under the mission CPU-ceiling
constraint, the correct stop is to commit the guard and let the next worker recycle apply
it before requeueing `QM5_12533`.
