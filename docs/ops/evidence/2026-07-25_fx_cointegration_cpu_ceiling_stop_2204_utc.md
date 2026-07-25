# FX Cointegration Paced-Fleet Stop — 2026-07-25 22:04 UTC

**Branch:** `agents/board-advisor`

## Decision

Stop without card, build, enqueue, dispatch, or MT5 launch.

The governed 66-pair frontier remains exhausted rather than under-built:

- `QM5_12532` (AUDUSD/NZDUSD) already has Q02 PASS evidence and later Q05 FAIL.
- `QM5_12533` (EURJPY/GBPJPY) already has Q02 PASS evidence and later Q04 FAIL.
- All seven qualifying positive-beta or strict sign-aware scan rows already have
  EA builds and terminal Q02 evidence, as reconciled in
  `docs/research/FX_COINTEGRATION_FRONTIER_DUPLICATE_GUARD_2026-07-24.md`.

Creating another card or re-enqueueing a stale legacy row would duplicate
governed work.

## Current capacity evidence

At `2026-07-25T22:04:44Z`, the path-aware canonical command

```text
python -m tools.strategy_farm.farmctl mt5-slots
```

found eight active factory MT5 terminals:

```text
T1, T2, T3, T4, T6, T7, T9, T10
```

The separately observed `T_Live` and FTMO terminal processes were excluded
from the factory count and were not controlled.

The canonical saturation scheduler dry-run independently returned:

```json
{"available_slots_after":0,"available_slots_before":0,"dry_run":true,"duplicate":0,"invalid":0,"no_capacity":0,"queued_scanned":0,"scheduled":0,"status":"ok"}
```

Eight active factory terminals exceed the documented seven-process paced-fleet
ceiling, while the scheduler exposes zero dispatch capacity. The mission's
explicit CPU-ceiling stop is therefore binding.

## Safety

No portfolio admission, KPI, Q08 contribution, T_Live manifest, AutoTrading
state, queue row, terminal process, card, EA, binary, setfile, basket manifest,
registry, or magic allocation was changed.
