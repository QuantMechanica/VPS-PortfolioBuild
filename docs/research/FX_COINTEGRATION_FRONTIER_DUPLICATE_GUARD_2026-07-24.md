# FX Cointegration Frontier — Cross-Ledger Duplicate Guard

**Date:** 2026-07-24
**Branch:** `agents/board-advisor`
**Outcome:** stop at paced-fleet capacity; no card, build, enqueue, or dispatch

## Decision

Do not create another card or EA from the documented FX cointegration scan, and
do not dispatch either forex row currently present in the legacy headless
queue.

The original positive-beta 66-pair scan and its strict sign-aware extension are
already fully mechanized. A repository-wide reconciliation found 71
cointegration-card files resolving to 46 unique allocated EA IDs, with a
matching EA directory for every ID. The seven strict scan rows all have builds
and canonical Strategy Farm Q02 PASS evidence:

| Rank cohort | Pair | EA | Current terminal evidence |
|---|---|---|---|
| positive-beta anchor | AUDUSD / NZDUSD | `QM5_12532` | Q02 PASS; later Q05 FAIL |
| positive-beta anchor | EURJPY / GBPJPY | `QM5_12533` | Q02 PASS; later Q04 FAIL |
| strict sign-aware | GBPUSD / USDCAD | `QM5_12978` | Q02 PASS; later Q04 FAIL |
| strict sign-aware | USDCAD / NZDUSD | `QM5_13003` | Q02 PASS; later Q04 FAIL |
| strict sign-aware | AUDUSD / EURGBP | `QM5_13106` | Q02 PASS exists; later repaired attempt INFRA_FAIL |
| strict sign-aware | EURGBP / AUDJPY | `QM5_13117` | Q02 PASS; later Q08 FAIL_HARD |
| strict sign-aware | USDJPY / EURAUD | `QM5_13119` | fresh Q02 PASS on 2026-07-19 |

Creating an eighth "next-best" strict sleeve would therefore duplicate the
governed frontier. The broader pure-FX cointegration-card inventory likewise
contains no built EA lacking a terminal Q02 result. The only cointegration
cards without terminal Q02 evidence are two already-pending cross-asset
XBR/FX relative-spread rows, not new pure-FX pairs.

## Legacy queue correction

The legacy headless database
`D:/QM/reports/pipeline/mt5_queue.db` contains four queued rows. Two are labeled
as FX cointegration continuations:

| Queue id | EA | Host | Legacy status | Canonical farm conflict |
|---:|---|---|---|---|
| 2 | `QM5_12760` | `GBPUSD.DWX` | queued | Q02 PASS work item `6154567b-875f-416c-903b-b171a4d4eefc`; later Q04 FAIL |
| 4 | `QM5_13119` | `USDJPY.DWX` | queued | three Q02 PASS results, most recently work item `1e8da3f0-8f2e-4414-b734-c7b63373b69d` on 2026-07-19 |

These rows are not valid mission fallbacks. They are cross-ledger duplicates
of terminal Strategy Farm work and must not be dispatched or copied into
another queue. This finding supersedes the continuation language in
`docs/research/FX_COINTEGRATION_Q02_CPU_CEILING_STOP_2026-07-23.md` that treated
the two rows as unfinished Q02 work.

No external queue row was updated or deleted. Retiring or invalidating legacy
rows is a separate scheduler-governance action and is not inferred from this
read-only mission.

## Paced-fleet stop

At `2026-07-24T15:46:21Z`, the path-aware Strategy Farm scan reported five
running factory terminals:

```text
T1, T3, T7, T8, T9
```

`T_Live` was observed only to exclude it and was not controlled. The canonical
legacy saturation scheduler independently returned:

```json
{"available_slots_after":0,"available_slots_before":0,"dry_run":true,"duplicate":0,"invalid":0,"no_capacity":0,"queued_scanned":0,"scheduled":0,"status":"ok"}
```

Its dispatch ledger records all T1-T10 slots at their configured maximum, so
the scheduler exposes no dispatch capacity even though the process snapshot is
lower. Per the mission's explicit CPU-ceiling rule, no MT5 run, queue mutation,
or speculative fallback enqueue was attempted.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No `T_Live` manifest, terminal, or AutoTrading state changed.
- No card, EA source, binary, registry, magic row, setfile, or basket manifest
  changed.
- No live setfile or live deployment artifact was created.

The next valid action requires either a newly OWNER-approved hypothesis outside
the exhausted scan or a scheduler-governed reconciliation of the saturated
legacy dispatch ledger. Neither is authorized implicitly by this stop record.
