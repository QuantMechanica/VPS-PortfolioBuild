# QM5_12712 FX Cointegration Q07 Pass / Q08 Pending - 2026-07-08

Branch: `agents/board-advisor`
Checked at: `2026-07-08T20:03:12+02:00` / `2026-07-08T18:03:12Z`

## Scope

Mission: grow the V5 book with market-neutral FX cointegration sleeves, preferring
`QM5_12532` / `QM5_12533` Q02 unblocks if still blocked. Guardrails observed:
no `T_Live`, no AutoTrading, no deploy manifest, and no portfolio admission,
portfolio KPI, or Q08 contribution code edits.

## Decision

The controlling strict scan remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. It hard-certified only
`QM5_12533` and `QM5_12532`, and both are no longer Q02-blocked:

| EA | Pair | Current state |
|---|---|---|
| `QM5_12532` | `AUDUSD.DWX` / `NZDUSD.DWX` | Q02 PASS, Q04 PASS, later Q05 FAIL |
| `QM5_12533` | `EURJPY.DWX` / `GBPJPY.DWX` | Q02 PASS, later Q04 FAIL |

No approved, allocated FX cointegration card was found without a matching
`framework/EAs/QM5_*` folder. The non-duplicate fallback lane is therefore the
already-built `QM5_12712` EURGBP/EURAUD basket.

## Funnel State

`QM5_12712` has advanced beyond the earlier CPU-ceiling note:

| Gate | Work item | Verdict | Evidence |
|---|---|---|---|
| Q07 | `1b9fa7a5-48a7-4e57-a699-9e55dfb0cb19` | PASS | `D:/QM/reports/work_items/1b9fa7a5-48a7-4e57-a699-9e55dfb0cb19/QM5_12712/Q07/QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1/aggregate.json` |
| Q08 | `b1bd1d06-dbfb-4d16-9951-3ea89e14d64f` | PENDING | farm DB row, promoted by `pump_cascade` from the Q07 work item |

Q07 headline metrics from the aggregate:

| Metric | Value |
|---|---:|
| min_pf | 1.13 |
| max_pf | 1.13 |
| variance_pct | 0.00 |
| trades per seed | 172 |

The card metadata was updated from stale `Q04_REQUEUED` to `Q08_PENDING`.

## CPU Ceiling

Farm state at check time:

| Status | Count |
|---|---:|
| active | 6 |
| pending | 5198 |
| done | 44113 |
| failed | 45305 |

Because six worker items were already active and `QM5_12712` already has a
non-duplicate pending Q08 row, no manual MT5 tester was launched and no duplicate
queue item was inserted.

Machine-readable snapshot:
`artifacts/fx_cointegration_12712_q08_pending_20260708T180312Z.json`.
