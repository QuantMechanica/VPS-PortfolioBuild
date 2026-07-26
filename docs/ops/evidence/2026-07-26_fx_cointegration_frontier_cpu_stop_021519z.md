# FX Cointegration Frontier CPU-Ceiling Stop

**Captured:** 2026-07-26T02:15:19Z

**Branch:** `agents/board-advisor`

**Decision:** `STOP_CPU_CEILING`

## Outcome

No new FX cointegration card or EA was created. The durable duplicate guard at
`docs/research/FX_COINTEGRATION_FRONTIER_DUPLICATE_GUARD_2026-07-24.md`
establishes that the governed 66-pair scan is fully mechanized. Creating
another scan-derived pure-FX pair would duplicate an existing card and build.

Neither anchor requires Q02 repair:

- `QM5_12532` has logical-basket Q02 `PASS` and later Q05 `FAIL`.
- `QM5_12533` has logical-basket Q02 `PASS` and later Q04 `FAIL`.

These are downstream strategy failures, not Q02 `ONINIT` or `NO_HISTORY`
infrastructure blocks.

## Paced-fleet ceiling

A fresh read-only `farmctl work-items --status active` returned nine active
items claimed by all nine enabled live workers: `T1`, `T2`, `T3`, `T4`, `T6`,
`T7`, `T8`, `T9`, and `T10`.

The path-aware `farmctl mt5-slots` scan observed current factory tester
processes on `T2`, `T3`, `T7`, `T9`, and `T10`. The separately observed
external FTMO terminal was excluded. `T_Live` was neither present in the
reported process list nor controlled.

The canonical saturation scheduler dry-run independently returned:

```json
{"available_slots_after":0,"available_slots_before":0,"dry_run":true,"duplicate":0,"invalid":0,"no_capacity":0,"queued_scanned":0,"scheduled":0,"status":"ok"}
```

The nine claimed worker slots and zero-capacity scheduler verdict are binding.
Per the mission's explicit CPU-ceiling rule, no fallback card was enqueued and
no tester was launched.

Machine-readable evidence:
`artifacts/fx_cointegration_frontier_stop_20260726T021519Z_board_advisor.json`.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No `T_Live` manifest, terminal, or AutoTrading state changed.
- No card, EA, setfile, basket manifest, registry, or queue row changed.
- No MT5 process was launched or controlled.
