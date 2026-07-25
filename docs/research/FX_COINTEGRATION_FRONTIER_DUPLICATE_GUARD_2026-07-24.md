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

## Pure-FX umbrella exception

A fresh manifest-to-work-item reconciliation at `2026-07-24T16:47Z` found one
pure-FX pairs basket without a terminal Q02 verdict:
`QM5_12512_bt-pairs-thresh`. It is not an unbuilt next-best scan pair or a
valid mission fallback:

- its manifest bundles three relationships rather than one concrete pair;
- EURUSD/GBPUSD, EURJPY/GBPJPY, and AUDUSD/NZDUSD already have dedicated
  builds (`QM5_12732`, `QM5_12533`, and `QM5_12532`, respectively);
- it is an H1, five-bar maximum-hold threshold strategy, not the requested
  low-frequency D1 cointegration sleeve; and
- all six declared leg symbols already have canonical Q02 work items with
  `status=pending`.

Re-enqueueing or extracting any one of those relationships would therefore
duplicate existing research, code, or queue state. This exception does not
change the exhausted-frontier decision above.

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
`docs/research/FX_COINTEGRATION_Q02_CPU_CEILING_STOP_2026-07-23.md`,
`docs/research/QM5_13119_HEADLESS_Q02_CPU_CEILING_HANDOFF_2026-07-23.md`, and
`docs/ops/evidence/2026-07-24_fx_cointegration_q02_cpu_ceiling_stop_1446_cest.md`
where they treat either row as unfinished Q02 work.

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

A read-only refresh at `2026-07-24T16:47Z` reached the same binding result.
The path-aware scan observed four running factory terminals (`T1`, `T3`, `T6`,
and `T8`) and excluded `T_Live`; the canonical farm health snapshot reported
seven active work items, while the saturation scheduler again returned zero
available slots and scheduled zero jobs. The lower process snapshot therefore
does not authorize bypassing either scheduler's capacity accounting.

A second read-only refresh at `2026-07-24T18:47:24Z` again reached the same
binding result. `farmctl mt5-slots` observed six path-anchored factory
terminals (`T1`, `T6`, `T7`, `T8`, `T9`, and `T10`) and observed `T_Live`
separately without controlling it. The canonical saturation scheduler returned
`available_slots_before=0`, `available_slots_after=0`, and `scheduled=0`.
Accordingly, no fallback card was reprioritized, no duplicate Q02 row was
inserted, and no MT5 process was launched.

A third read-only refresh at `2026-07-24T20:01:29Z` found six running factory
terminals (`T1`, `T2`, `T4`, `T7`, `T8`, and `T9`) using exact executable
paths under `D:/QM/mt5/T1..T10`; `T_Live` was excluded by construction. The
canonical saturation scheduler still returned
`available_slots_before=0`, `available_slots_after=0`, `scheduled=0`, and
`status=ok`. This is the mission's binding CPU-ceiling stop: no additional
candidate search, queue mutation, tester launch, or terminal control followed.

A fourth read-only refresh at `2026-07-24T21:00:21Z` found five running
factory terminals (`T1`, `T2`, `T3`, `T6`, and `T7`) using exact executable
paths under `D:/QM/mt5/T1..T10`; `T_Live` was observed separately and excluded.
The canonical saturation scheduler again returned
`available_slots_before=0`, `available_slots_after=0`, `scheduled=0`, and
`status=ok`. Its dispatch ledger remains the binding capacity authority, so no
Q02 enqueue, dispatch, tester launch, queue mutation, or terminal control
followed.

A fifth read-only refresh at `2026-07-24T22:01:07Z`
(`2026-07-25T00:01:07+02:00`) found every factory terminal `T1` through `T10`
running from its exact executable path under `D:/QM/mt5/`. `T_Live` was
observed separately and excluded from both the factory count and any control.
The canonical saturation scheduler independently returned
`available_slots_before=0`, `available_slots_after=0`, `scheduled=0`, and
`status=ok`. With all ten factory terminals occupied and no valid unbuilt
scan pair, the mission stopped before any card, build, enqueue, dispatch,
tester launch, queue mutation, or terminal action.

A sixth read-only refresh at `2026-07-25T00:00:37Z`
(`2026-07-25T02:00:37+02:00`) exposed a scheduler-accounting mismatch rather
than usable capacity. `farmctl mt5-slots` found no running factory terminal in
`T1` through `T10`; the only `terminal64.exe` process was the separately
excluded `T_Live` instance. In contrast, the legacy `dispatch_state.json`
still recorded `running=3` for every factory terminal, and the canonical
saturation scheduler returned `available_slots_before=0`,
`available_slots_after=0`, and `scheduled=0`. The scheduler verdict remains
the binding CPU-ceiling signal, but this snapshot narrows the blocker to an
unreconciled legacy dispatch ledger rather than current factory process load.
Clearing or rewriting that external ledger is a separate scheduler-governance
action and was not inferred. The machine-readable snapshot is
`artifacts/fx_cointegration_cpu_ceiling_stop_20260725T000037_board_advisor.json`.
No stale forex queue row was dispatched or duplicated.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No `T_Live` manifest, terminal, or AutoTrading state changed.
- No card, EA source, binary, registry, magic row, setfile, or basket manifest
  changed.
- No live setfile or live deployment artifact was created.

The next valid action requires either a newly OWNER-approved hypothesis outside
the exhausted scan or a scheduler-governed reconciliation of the saturated
legacy dispatch ledger. Neither is authorized implicitly by this stop record.

## 2026-07-25 canonical-farm capacity refresh

A current read-only reconciliation at `2026-07-25T07:27:55Z` confirms that the
mission still has no non-duplicate pure-FX pair to card or build:

- all 21 approved pair cards whose filenames contain `cointegration` or `coint`
  have matching EA directories;
- `QM5_12532` remains Q02 `PASS` followed by Q05 `FAIL`;
- `QM5_12533` remains Q02 `PASS` followed by Q04 `FAIL`; and
- the only open rows returned by the wider cointegration-text reconciliation
  are the cross-asset XBR/FX rows `QM5_13087` and `QM5_13092`, plus the metals
  basket `QM5_20012`. None is a new pure-FX pair from the governed scan.

The canonical farm had nine active work items and nine live terminal-worker
daemons, with 2,289 pending items. Six factory `terminal64.exe` processes were
present under exact `D:/QM/mt5/T<n>/` paths; the separately observed `T_Live`
process was excluded. Because every live worker already owned an active work
item, paced capacity was unavailable even though not every phase had an MT5
child process at the instant of inspection.

The machine-readable snapshot is
`artifacts/fx_cointegration_frontier_stop_20260725T072755Z_board_advisor.json`.
No card, EA, setfile, manifest, queue row, terminal, portfolio gate, or live
artifact was changed by this refresh.

## 2026-07-25 09:47Z capacity refresh

The non-duplicate decision remains binding. The two anchor baskets are still
past Q02 (`QM5_12532` PASS then Q05 FAIL; `QM5_12533` PASS then Q04 FAIL), all
21 approved pair-card filenames containing `cointegration` or `coint` still
have matching EA directories, and no eligible unbuilt pure-FX pair exists.

The canonical farm contained eight active and 2,264 pending work items. Its
dispatch ledger reported `running=3` for every T1-T10 slot, and the scheduler
dry-run returned zero available slots and scheduled zero jobs. A path-anchored
process snapshot found no factory `terminal64.exe` child at that instant; the
only observed terminal was the separately excluded `T_Live` process. This is
a scheduler-accounting mismatch, not authorization to bypass the canonical
capacity decision.

The current machine-readable snapshot is
`artifacts/fx_cointegration_frontier_stop_20260725T094728Z_board_advisor.json`.
No card, build, enqueue, dispatch, tester launch, terminal control, portfolio
gate, or live artifact change followed.

## 2026-07-25 13:00Z capacity refresh

The non-duplicate frontier decision remains unchanged: `QM5_12532` and
`QM5_12533` are already Q02-cleared and subsequently failed Q05 and Q04,
respectively, while all seven governed scan pairs are built with terminal Q02
evidence. There is no eligible unbuilt pure-FX pair or legitimate open
successor to enqueue.

The path-aware process scan observed three factory terminals (`T4`, `T9`, and
`T10`). `T_Live` and the external FTMO terminal were observed only to exclude
them and were not controlled. The canonical saturation scheduler remained the
binding capacity authority and returned `available_slots_before=0`,
`available_slots_after=0`, and `scheduled=0`.

The machine-readable snapshot is
`artifacts/fx_cointegration_frontier_stop_20260725T130020Z_board_advisor.json`.
Per the explicit CPU-ceiling rule, no card, build, enqueue, dispatch, tester
launch, terminal control, portfolio-gate change, or live-artifact change
followed.
