# FX cointegration Q02 continuation — CPU-ceiling stop

**Observed:** 2026-07-24T01:45:13Z  
**Branch:** `agents/board-advisor`  
**Outcome:** `STOP_CPU_CEILING`

## Selection and duplicate check

The controlling research record,
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, has no unbuilt
qualifying FX cointegration pair left:

- `QM5_12532` AUDUSD/NZDUSD and `QM5_12533` EURJPY/GBPJPY both have
  logical-basket Q02 PASS evidence and later genuine strategy failures.
- All seven qualifying rows from the strict sign-aware extension already have
  approved cards, compiled EAs, `RISK_FIXED` backtest setfiles, and basket
  manifests.

The mission fallback is already represented in the canonical headless queue
exactly once per basket:

| Queue | EA | Host symbol | Phase | Status | Config hash |
|---:|---|---|---|---|---|
| 2 | `QM5_12760` | `GBPUSD.DWX` | Q02 | queued | `q02_fx_coint_12760_s20260629_001` |
| 4 | `QM5_13119` | `USDJPY.DWX` | Q02 | queued | `q02_fx_coint_13119_s20260710_001` |

Both rows remain unassigned, with no dispatch decision or error. Creating
another card, EA, or queue row would be duplicate work.

## Paced-fleet ceiling

A path-anchored process check found seven factory terminals:

```text
T1, T2, T4, T6, T7, T9, T10
```

`T_Live` was excluded from the factory count and was not controlled. Seven
factory processes equal the documented paced-fleet ceiling. The canonical
scheduler was then invoked read-only:

```text
python -m framework.scripts.mt5_saturation_scheduler
  --sqlite D:/QM/reports/pipeline/mt5_queue.db
  --dispatch-state D:/QM/reports/pipeline/dispatch_state.json
  --dry-run
```

It returned:

```json
{"available_slots_after":0,"available_slots_before":0,"dry_run":true,"duplicate":0,"invalid":0,"no_capacity":0,"queued_scanned":0,"scheduled":0,"status":"ok"}
```

Per the explicit mission stop rule, no queue mutation or MT5 launch was made.
The existing dispatcher remains the continuation path when capacity becomes
available.

## Safety boundary

No EA source or binary, card, registry, setfile, basket manifest, terminal,
AutoTrading setting, `T_Live` artifact, deploy manifest, portfolio-admission
gate, portfolio KPI, or Q08-contribution path was changed.
