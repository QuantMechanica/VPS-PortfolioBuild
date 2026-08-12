# FX Cointegration Frontier CPU-Ceiling Stop

**Observed:** 2026-07-26T04:45:47Z (2026-07-26 06:45:47 CEST)  
**Branch:** `agents/board-advisor`

## Outcome

Stopped before card creation, build, Q02 enqueue, dispatch, or MT5 launch.

The repository's controlling reconciliation,
`docs/research/FX_COINTEGRATION_FRONTIER_DUPLICATE_GUARD_2026-07-24.md`,
establishes that the two positive-beta survivors and all five qualifying
strict sign-aware extensions from the governed 66-pair scan already have
dedicated builds and terminal Q02 evidence. Creating another scan-derived
pure-FX sleeve would duplicate governed work.

Neither preferred anchor has an ONINIT or NO_HISTORY Q02 blocker:

- `QM5_12532` AUDUSD/NZDUSD has logical-basket Q02 `PASS`, Q04 `PASS`, and a
  later strategy Q05 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY has logical-basket Q02 `PASS` and a later strategy
  Q04 `FAIL`.

Re-enqueueing either anchor at Q02 would therefore duplicate terminal work
rather than repair infrastructure.

## Paced-fleet ceiling

A path-anchored process snapshot found six factory terminals:

```text
T1, T2, T4, T6, T7, T8
```

The separately observed `T_Live` and FTMO processes were excluded and were not
controlled. Although the raw process count was one below the documented
seven-process ceiling, the canonical saturation scheduler is the binding
capacity authority. Its read-only dry-run returned:

```json
{"available_slots_after":0,"available_slots_before":0,"dry_run":true,"duplicate":0,"invalid":0,"no_capacity":0,"queued_scanned":0,"scheduled":0,"status":"ok"}
```

Per the mission's explicit CPU-ceiling stop rule, no fallback forex card was
enqueued and no tester process was launched.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No T_Live manifest, terminal, or AutoTrading state changed.
- No card, EA, binary, setfile, basket manifest, registry, or farm database
  changed.
- No backtest process was launched.
