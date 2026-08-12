# FX Cointegration Frontier CPU-Ceiling Stop

**Captured:** 2026-07-26T00:30:30Z

**Branch:** `agents/board-advisor`

**Decision:** `STOP_CPU_CEILING`

## Outcome

No new FX cointegration card or EA was created. The governed 66-pair
frontier remains fully mechanized, so another pair would duplicate an
existing card and build. The two anchor baskets do not need Q02 repair:

- `QM5_12532` has logical-basket Q02 `PASS` and later Q05 `FAIL`.
- `QM5_12533` has logical-basket Q02 `PASS` and later Q04 `FAIL`.

The mission fallback could not be dispatched because the paced fleet was at
its canonical CPU ceiling. `farmctl work-items --status active` returned nine
active items, claimed by every live worker (`T1`, `T2`, `T3`, `T4`, `T6`,
`T7`, `T8`, `T9`, and `T10`). The legacy saturation scheduler independently
returned:

```json
{"available_slots_after":0,"available_slots_before":0,"dry_run":true,"duplicate":0,"invalid":0,"no_capacity":0,"queued_scanned":0,"scheduled":0,"status":"ok"}
```

A path-aware process scan observed four factory tester processes (`T1`, `T2`,
`T7`, and `T9`). This lower instantaneous child-process count does not
override the nine claimed canonical worker slots or authorize bypassing the
scheduler.

Machine-readable evidence:
`artifacts/fx_cointegration_frontier_stop_20260726T003030Z_board_advisor.json`.

## Safety

No queue row, MT5 process, terminal, EA, setfile, basket manifest, registry,
portfolio admission/KPI/Q08 contribution file, `T_Live` artifact, or
AutoTrading state was changed.
