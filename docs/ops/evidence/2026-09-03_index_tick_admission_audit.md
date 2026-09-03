# Index single-symbol tick admission audit (read-only)

- Date: 2026-09-03
- Author lane: board-advisor (audit worktree `wf_051790b8-a85-1`)
- Scope: why single-symbol INDEX real-tick rows (GDAXI/SP500/WS30/NDX/UK100) are
  unclaimable under the 2026-09-02 physical-RAM admission gate, and whether the
  44 GB reservation is measured or extrapolated.
- Mode: READ-ONLY. Farm DB read via `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`.
  No DB writes, no enqueue/hold/restart, no constant/gate/verdict change, no commit/push.
- Worktree fast-forward merge of `agents/board-advisor`:
  before `a92cda60fe1e62eeee73de6068dd2634dba490d2`,
  after `3c0a7a72d51eb34a00b7e035a494e093d6c1d1a9` (fast-forward confirmed).
- Verification of the code claims below: `C:/Python311/python.exe -m pytest -q`
  on `tools/strategy_farm/tests/test_tester_memory_admission.py`,
  `test_tester_memory_ledger.py`, `test_terminal_worker_ram_compile_bypass.py`,
  `test_terminal_worker_atomic_claim.py`, `test_commit_reservation_decay.py`
  = 128 passed (17 + 111). `git status --short framework/calibrations/` empty
  (no QM5_9993 autostub was produced; nothing to revert).

## The admission arithmetic (mechanism under audit)

A non-multisymbol index-base row is assigned the `single_index_tick` class
(`terminal_worker.py:876-877`), whose reservation is
`SINGLE_INDEX_TICK_COMMIT_RESERVATION_GB = 44.0` (`:233`, resolved at `:911-912`).
`_ram_reservation_for_candidate` reuses that same commit class and reservation
for the PHYSICAL-RAM admission (`:1221-1223`), and the claim gate then requires
`free_ram - 44 >= RAM_MIN_FREE_GB (14)` (`:3441-3465`, floor from `:253-257`),
i.e. **>= 58 GB free physical RAM before an index row can be claimed**. The
measured-RAM override added 2026-09-03 can only raise a class via
`max(flat_gb, measured_gb)` (`:1195`), never lower it.

---

## Section 1 - Is 44 GB representative for GDAXI/NDX/WS30/UK100, or only SP500?

### 1a. Every source searched for a measured index tester working set (since 2026-08-15)

| Source (path) | Index rows carrying a measured working set | Which base | Value(s) |
|---|---|---|---|
| `D:/QM/reports/state/tester_memory_ledger.jsonl` (8 rows, all 2026-09-03 16:42Z-17:15Z) | 0 | none (energy/metal/fx_major/opt_census only) | n/a |
| `D:/QM/reports/state/tester_memory_expectations.json` (6 compiled keys) | 0 | none (no `index|*` key) | n/a |
| `docs/ops/evidence/2026-09-02_terminal_ram_class_measurement.json` | 0 (host snapshot of 7 non-index testers) | none | testers 0.03-11.43 GB WS |
| Q02 run `summary.json` / Q04 `aggregate.json` (e.g. `D:/QM/reports/pipeline/QM5_10648/Q04/GDAXI.DWX__959776bb.../aggregate.json`) | 0 | none | no memory field in schema |
| `D:/QM/reports/state/commit_sampler.log` | 0 (host-wide `phys_free_gb`, not per-symbol) | none | n/a |
| `docs/ops/evidence/2026-08-15_containment_selftrip_recovery_and_factory_on.md:140` + commit `ad1b025c24` body | 1 | **SP500 only** (QM5_1537 SP500.DWX Q02, T6, 12:15 local) | **46.8 GB working set / 45.7 GB private** |

The `single_index_tick` reservation rests on exactly **one** measurement, of
**one** symbol (SP500), from **one** run on 2026-08-15. There is no measured
working set for GDAXI, NDX, WS30, or UK100 anywhere in the ledger, the compiled
expectations, the run evidence, or the RAM-class measurement JSON. The
tester-memory ledger that would capture it went live 2026-09-03 and has recorded
zero index rows - because the gate this audit describes prevents any index row
from being claimed and therefore measured (a self-sealing evidence gap).

### 1b. Index rows DID complete since 2026-08-15 (before the 09-02 gate) - none carry a WS number

Done index rows since 2026-08-15 (status=done, `updated_at >= 2026-08-15`), by base:

| Base | Q02 done | Q03 done | Q04 done |
|---|---|---|---|
| GDAXI | 18 | 4 | 34 |
| SP500 | 16 | 4 | 17 |
| WS30 | 19 | 3 | 20 |
| NDX | 27 | 6 | 28 |
| UK100 | 7 | 2 | 10 |

All five bases ran to completion, yet none of their evidence files record a peak
working set (the `summary.json`/`aggregate.json` schemas have no memory field),
so completion count is not a memory measurement.

### 1c. The class is symbol-base-only, timeframe-blind

`_multisymbol_commit_class` assigns `single_index_tick` purely by
`host.split(".")[0] in INDEX_TICK_SYMBOL_BASES` (`terminal_worker.py:876-877`) -
timeframe is not consulted. The completed index Q02 rows since 2026-08-15 were
predominantly coarse timeframes, which do not exhibit the dense-tick footprint
the 44 GB was calibrated from:

| Timeframe | Q02 done (index) | Q02 pending (index) |
|---|---|---|
| H4 | 43 | 6 |
| H1 | 24 | 6 |
| D1 | 13 | 6 |
| M30 | 0 | 3 |
| M15 | 3 | 0 |
| M5 | 2 | 0 |
| M1 | 2 | 2 |

A D1/H4 GDAXI row and a dense M1 SP500 row receive the identical 44 GB physical
reservation.

**Section 1 finding:** 44 GB is representative of SP500 only, and only from a
single observation; it is extrapolated to GDAXI/NDX/WS30/UK100 by symbol-base
membership, not by measurement, and applied regardless of timeframe.

---

## Section 2 - How the 2026-09-02 physical-RAM guard came to reuse the commit class

`git log -S` on `tools/strategy_farm/terminal_worker.py`:

| Commit | Date | Role in the lineage |
|---|---|---|
| `66fbc3c391` | 2026-06-22 | Introduced the RAM guard as a host-wide free-RAM hysteresis pause (`factory: RAM guard + gentler purge + ...`). No per-class reservation - a single global floor. |
| `ca9060bf4a` | 2026-06-27 | `Guard basket Q02 claims on RAM headroom` - basket-scoped, still not a per-class physical reservation. |
| `ad1b025c24` | 2026-08-15 | `feat(qm): single-index-tick commit reservation class (44GB)`. Created `SINGLE_INDEX_TICK_COMMIT_RESERVATION_GB=44`, calibrated in the body from `metatester64 45.7GB private on SP500 Q02, 2026-08-15`. **This is a COMMIT-headroom class only** (pagefile-backed, 122.6 GB limit) - not a physical-RAM gate. |
| `43c069c48d` | 2026-09-02 | `worker: physical-RAM admission per reservation class at claim time`. **First reuse of the commit class for physical RAM:** `_ram_class = _multisymbol_commit_class(...)`, `_ram_expected_gb = _commit_reservation_gb(_ram_class)`, skip if `free - _ram_expected_gb < RAM_MIN_FREE_GB`. Body cites the 2026-09-02 13:45Z incident (six testers, two 44 GB-class index runs, drove free RAM to 0.9 GB, three workers died). Reverted same day. |
| `8037276ef4` | 2026-09-02 | `worker: revert claim-path RAM admission (43c069c48d); RAM-low pause thresholds 6/12 -> 14/20 GB`. Reverted because the per-class check `blocked every claim in unit tests on a low-RAM host (32 failures)`; kept the intent as a global run-loop pause and raised the latch to 14/20. |
| `23a950ea7e` | 2026-09-02 | `infra: admit workers by RAM reservation class`. **Re-introduced the reuse in its current form:** added `_ram_reservation_for_candidate` which calls `_multisymbol_commit_class` then `_commit_reservation_gb`, and the claim-gate block computing `post_reservation_free_gb` and skipping below `RAM_MIN_FREE_GB`. This is the live 09-02 guard. |
| `77fc3266a6` | 2026-09-03 | `worker: tester peak-memory ledger + measured RAM admission ...`. Wrapped the flat lookup in `_resolve_ram_reservation_gb` using `max(flat_gb, measured_gb)` (measured can only raise). Added the OPT_CENSUS-cell (4 GB) and the `qm.dl089-measurement-q02-prerequisite/v1` seed (4 GB) special-cases. |
| `49e7b029f4` | 2026-09-03 | `worker(RAM guard): DL-089 census cells need 8 GB after their 4 GB reservation ...`. Added `_ram_floor_for_class`/`OPT_CENSUS_POST_RESERVATION_FLOOR_GB=8`; the index class was not given a lowered floor and keeps the 14 GB floor. |

### Live code that produces the 58 GB requirement (current worktree line cites)

| Element | File:line | Value / effect |
|---|---|---|
| Physical-RAM floor after reservation | `terminal_worker.py:156` | `RAM_MIN_FREE_GB = 14.0` |
| Index commit reservation constant (SP500-derived) | `terminal_worker.py:233` (comment `:225-232`) | `44.0`, comment cites SP500 45.7 GB private only |
| Index-base -> single_index_tick class | `terminal_worker.py:876-877` | symbol-base membership, timeframe-blind |
| single_index_tick -> 44 GB | `terminal_worker.py:911-912` | `_commit_reservation_gb` |
| Commit class reused for physical RAM | `terminal_worker.py:1221-1223` | `_ram_reservation_for_candidate` calls `_multisymbol_commit_class` + `_commit_reservation_gb` |
| Measured override never lowers | `terminal_worker.py:1195` | `return max(flat_gb, float(measured_gb))` |
| Claim gate | `terminal_worker.py:3441-3465` | `post_reservation_free_gb = free - 44`; skip if `< 14` -> needs `>= 58` |
| Floor selector (index keeps 14) | `terminal_worker.py:253-257` | `_ram_floor_for_class` returns `RAM_MIN_FREE_GB` for non-census |

**Section 2 finding:** the 44 GB figure originated on 2026-08-15 as a
COMMIT-headroom fail-safe for a single measured SP500 run (`ad1b025c24`). On
2026-09-02 the physical-RAM admission gate was written to reuse that same commit
class and reservation for a different resource (physical RAM), first in
`43c069c48d` (reverted) and then in the live `23a950ea7e`. Combined with the
14 GB post-reservation floor this yields the >= 58 GB free requirement, and the
2026-09-03 measured-RAM path (`max()`) cannot reduce it.

---

## Section 3 - How often, in the last 24 h, did free RAM exceed 58 GB / 46 GB?

Host free-RAM series: `D:/QM/reports/state/commit_sampler.log` (`phys_free_gb`
sampled once per ~60 s by `commit_sampler.ps1`, Win32 `FreePhysicalMemory`).
Window: last 24 h = 2026-09-02T17:22:04Z -> 2026-09-03T17:22:04Z, n = 1438
samples.

| Free-RAM level | Meaning | Samples > level | Percent of 24 h |
|---|---|---|---|
| > 58 GB | required to claim an index row (44 + 14) | **0 / 1438** | **0.00%** |
| > 46 GB | measured SP500 WS (46.8) | **0 / 1438** | **0.00%** |
| > 44 GB | the bare reservation alone | **0 / 1438** | **0.00%** |
| > 20 GB | RAM_RESUME_FREE_GB | 614 / 1438 | 42.70% |
| > 14 GB | RAM_MIN_FREE_GB | 1060 / 1438 | 73.71% |
| <= 14 GB | below the backtest floor | 378 / 1438 | 26.29% |

Distribution: min 0.7 GB, median 18.7 GB, **max 42.8 GB**. The 24 h maximum free
physical RAM (42.8 GB) is below the 44 GB reservation itself, so an index row
could not be admitted at any sampled minute - not merely never above 58, but
never even above the reservation.

### Worker-side corroboration

All 12 `terminal_worker_T*.log` files (timestamped events span
2026-09-02T06:40:35Z -> 2026-09-03T17:23:28Z):

| Worker event | Count | Note |
|---|---|---|
| `ram_low_pause` | 5273 | free_ram min 0.0, median 10.4, max 19.9 (fires only below the 14/20 latch, so it cannot show the upper tail) |
| ... with `threshold_gb = 20.0` (latched) | 4304 | fleet spent most pauses waiting for the 20 GB resume level |
| ... with `threshold_gb = 14.0` | 438 | current trip floor |
| ... with `threshold_gb = 6.0 / 12.0` | 53 / 478 | pre-2026-09-02 rollback values, earlier in the window |
| `claimed` | 1630 | claim events carry no free-RAM value |
| `cpu_high_pause` | 1166 | CPU ceiling also active |
| `commit_headroom_low_pause` | 117 | commit gate also tripping |
| `ram_class_skipped` (index-row skip) | 0 logged | not emitted: `claim_declined` surfaces only `no_pending_claimable` (`terminal_worker.py:8137-8148`), so index starvation is invisible in the event stream |

Metric caveat: the admission gate reads `GlobalMemoryStatusEx.ullAvailPhys`
(available = free + standby; `terminal_worker.py:7948-7982`), whereas
`commit_sampler.log` records `FreePhysicalMemory` (truly free). `ullAvailPhys >=
FreePhysicalMemory`, so the gate's own metric can exceed 42.8 GB at moments via
reclaimable standby cache; however no available-memory series in evidence reaches
44/46/58 GB, and the persistent latching to the 20 GB resume threshold (4304
pauses) corroborates operation far below that band.

**Section 3 finding:** across the last 24 h, host free physical RAM never
exceeded 46 GB (0.00%) and never exceeded 58 GB (0.00%); the maximum observed was
42.8 GB, below the 44 GB reservation. An index row's 58 GB requirement was
unsatisfiable at every sampled minute.

---

## Section 4 - The starved backlog

All pending index-base rows (`status = pending`, symbol base in
GDAXI/SP500/WS30/NDX/UK100), all creation dates.

### 4a. By phase (Q02/Q03/Q04, the single-symbol tick-gated phases)

| Phase | Pending | Claimable (not held, not superseded) | Held | Superseded | Oldest created | Priority_track |
|---|---|---|---|---|---|---|
| Q02 | 112 | 84 | 7 | 21 | 2026-06-18 | see 4c |
| Q03 | 10 | 8 | 2 | 0 | 2026-08-23 | see 4c |
| Q04 | 369 | 346 | 3 | 20 | 2026-08-17 | see 4c |

Downstream index rows also pending (not gated by the tick physical-RAM class the
same way, listed for completeness): Q05 19, Q06 5, Q07 7, Q08 1, Q09 5,
Q09_NEWS 12, Q10_NEWS 16, Q12 5.

### 4b. By symbol base

| Base | Q02 | Q03 | Q04 |
|---|---|---|---|
| GDAXI | 16 | 2 | 99 |
| SP500 | 11 | 4 | 48 |
| WS30 | 20 | 3 | 37 |
| NDX | 58 | 1 | 174 |
| UK100 | 7 | 0 | 11 |
| **total** | **112** | **10** | **369** |

### 4c. Priority-track rows

10 pending index Q02/Q03/Q04 rows carry `priority_track = True`:

| Item (id8) | EA | Phase | Symbol | Created |
|---|---|---|---|---|
| 61b261d0 | QM5_33006 | Q02 | SP500.DWX | 2026-08-17T19:52 |
| 8322d8c7 | QM5_33007 | Q02 | SP500.DWX | 2026-08-17T19:52 |
| e4f4c8e3 | QM5_34005 | Q02 | SP500.DWX | 2026-08-17T19:52 |
| d04b183e | QM5_11881 | Q02 | NDX.DWX | 2026-08-20T09:52 |
| bef29088 | QM5_41306 | Q04 | WS30.DWX | 2026-09-02T19:23 |
| 39bbb231 | QM5_41306 | Q03 | WS30.DWX | 2026-09-02T20:08 |
| 4ca22ee4 | QM5_41321 | Q04 | NDX.DWX | 2026-09-03T01:39 |
| 0561d9a8 | QM5_41323 | Q04 | NDX.DWX | 2026-09-03T01:57 |
| bbbb46c9 | QM5_41323 | Q03 | NDX.DWX | 2026-09-03T02:36 |
| bd12175c | QM5_10815 | Q02 | GDAXI.DWX | 2026-09-03T15:41 |

Oldest priority_track: the three SP500 Q02 rows created 2026-08-17T19:52. Newest:
`bd12175c` QM5_10815 GDAXI Q02 (the OWNER-DEC-PRE0803 lineage row), created
2026-09-03T15:41 - unclaimable since creation under the 58 GB requirement.

### 4d. Parallel non-index class blocked by the same 24 h ceiling (noted, not in scope)

`multi_leg_fx_basket` rows require `MULTISYMBOL_COMMIT_MIN_FREE_GB = 48` GB commit
headroom (`terminal_worker.py:212`) plus a 32 GB physical reservation and the
14 GB floor (46 GB free physical). Example: `a64d18d3` QM5_12580 Q03, 7-leg FX
basket, created 2026-09-03T16:31, pending. Same 42.8 GB 24 h ceiling blocks it.

**Section 4 finding:** 491 pending index Q02/Q03/Q04 rows (112/10/369), 438 of
them claimable (not held or superseded), oldest Q02 dating to 2026-06-18; NDX
dominates (58 Q02 + 174 Q04). 10 are priority_track, spanning the 2026-08-17
SP500 trio through the 2026-09-03 GDAXI OWNER-DEC-PRE0803 row.
