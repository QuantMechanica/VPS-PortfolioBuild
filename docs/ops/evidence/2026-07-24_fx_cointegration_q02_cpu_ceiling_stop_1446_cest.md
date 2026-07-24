# FX Cointegration Q02 Continuation — CPU-Ceiling Stop (14:46 CEST)

**Observed:** 2026-07-24T14:46:33.9033752+02:00

**Branch:** `agents/board-advisor`

**Outcome:** `STOP_CPU_CEILING`

## Non-duplicate selection audit

The controlling 66-pair scan still has no unbuilt qualifying sleeve. Its two
hard survivors are already beyond Q02:

- `QM5_12532` AUDUSD/NZDUSD has logical-basket Q02 PASS and Q04 PASS
  evidence, followed by terminal Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY has logical-basket Q02 PASS evidence, followed by
  terminal Q04 FAIL.

A fresh comparison of the canonical approved card directory against
`framework/EAs/` found 21 FX cards whose names contain `cointegration` or
`coint`, with zero missing EA directories and zero missing
`basket_manifest.json` files. Creating another card or copying a basket would
therefore duplicate the approved, mechanized frontier.

The canonical headless queue already contains the two valid forex
continuations exactly once:

| Queue | EA | Host | Phase | Config hash | Status |
|---:|---|---|---|---|---|
| 2 | `QM5_12760` | `GBPUSD.DWX` | Q02 | `q02_fx_coint_12760_s20260629_001` | queued |
| 4 | `QM5_13119` | `USDJPY.DWX` | Q02 | `q02_fx_coint_13119_s20260710_001` | queued |

Both are unassigned and have no dispatch decision or error. The queue contains
four queued rows total, so no duplicate row was added.

## Binding capacity check

The path-anchored process query observed six factory terminals:

```text
T1, T3, T6, T7, T8, T10
```

`T_Live` and the separate FTMO terminal were excluded from this count and were
not controlled. Although the raw process count was below the documented
seven-process ceiling at the instant of observation, the canonical scheduler
is the binding capacity authority. Its read-only dry-run reported zero
available slots:

```json
{"available_slots_after":0,"available_slots_before":0,"dry_run":true,"duplicate":0,"invalid":0,"no_capacity":0,"queued_scanned":0,"scheduled":0,"status":"ok"}
```

Per the mission's CPU-ceiling stop rule, no dispatcher tick, queue mutation,
manual backtest, or MT5 launch was attempted. The machine-readable snapshot is
`artifacts/fx_cointegration_cpu_ceiling_stop_20260724T144633_board_advisor.json`.

## Safety boundary

No strategy card, EA source or binary, setfile, basket manifest, registry row,
runtime database, terminal state, AutoTrading setting, `T_Live` artifact,
deploy manifest, portfolio-admission gate, portfolio KPI, or Q08-contribution
path was changed.
