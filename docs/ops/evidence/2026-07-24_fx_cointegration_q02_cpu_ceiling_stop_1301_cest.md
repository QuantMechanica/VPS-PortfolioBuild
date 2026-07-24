# FX Cointegration Q02 Continuation — CPU-Ceiling Stop (13:01 CEST)

**Observed:** 2026-07-24T13:01:51.8049274+02:00

**Branch:** `agents/board-advisor`

**Outcome:** `STOP_CPU_CEILING`

## Frontier and anchor check

The documented qualifying frontier from the OWNER-requested 66-pair scan is
fully mechanized. A repository comparison of approved FX cointegration cards
against `framework/EAs/` found no approved card without a matching EA build,
including the later `*-coint` and sign-aware extensions. Creating another card
or copying an existing basket would therefore be duplicate work.

The two anchor baskets are not blocked at Q02:

- `QM5_12532` AUDUSD/NZDUSD has terminal Q02 PASS and Q04 PASS evidence, then
  terminal Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY has terminal Q02 PASS evidence, then terminal Q04
  FAIL.

The mission fallback is consequently an existing built forex basket. The
canonical headless queue already contains exactly one row for each current FX
continuation:

| Queue | EA | Host | Phase | Config hash | Status |
|---:|---|---|---|---|---|
| 2 | `QM5_12760` | `GBPUSD.DWX` | Q02 | `q02_fx_coint_12760_s20260629_001` | queued |
| 4 | `QM5_13119` | `USDJPY.DWX` | Q02 | `q02_fx_coint_13119_s20260710_001` | queued |

Both rows are unassigned and have no dispatch decision or error. The queue has
four queued rows total. No duplicate row was added.

## Binding capacity check

A path-anchored process query found seven active factory terminals:

```text
T1, T2, T3, T4, T7, T8, T10
```

`T_Live` and the separate FTMO terminal were excluded from the factory count
and were not controlled. Seven factory terminals equal the mission's paced
CPU ceiling. The canonical scheduler was invoked read-only:

```powershell
python -m framework.scripts.mt5_saturation_scheduler `
  --sqlite D:/QM/reports/pipeline/mt5_queue.db `
  --dispatch-state D:/QM/reports/pipeline/dispatch_state.json `
  --dry-run
```

It independently reported zero capacity:

```json
{"available_slots_after":0,"available_slots_before":0,"dry_run":true,"duplicate":0,"invalid":0,"no_capacity":0,"queued_scanned":0,"scheduled":0,"status":"ok"}
```

Per the explicit CPU-ceiling stop rule, no dispatcher tick, queue mutation,
manual backtest, or MT5 launch was attempted. The machine-readable snapshot is
`artifacts/fx_cointegration_cpu_ceiling_stop_20260724T130151_board_advisor.json`.

## Safety boundary

No strategy card, EA source or binary, setfile, basket manifest, registry row,
runtime database, terminal state, AutoTrading setting, `T_Live` artifact,
deploy manifest, portfolio-admission gate, portfolio KPI, or Q08-contribution
path was changed.
