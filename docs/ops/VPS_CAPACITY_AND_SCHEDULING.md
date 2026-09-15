# VPS Capacity & Scheduling

Canonical page for the factory's physical capacity and its resource-aware
scheduling on the **existing** host. Created for OWNER directive 3 (2026-09-15)
§11–§13, §39, §44; slice `g1_vps_resource_scheduler`. Runtime numbers come from
generated read-models under `D:/QM/reports/state/`; policy comes from the config
contracts named below. Do not treat volatile free-RAM values as permanent facts
(directive §39): the stable facts are the hardware, the reserved resources, the
RAM classes, and the admission rules — the current bottleneck block is a
snapshot and is regenerated.

## OWNER decision — NO VPS UPGRADE / NO VPS MIGRATION

> **OWNER-DEC-D3-20260915 (§13):** For the current planning horizon there is
> **no VPS move and no VPS hardware upgrade.** Optimize the existing host. Do not
> repeatedly surface "buy a bigger VPS" as the solution. If a task genuinely
> cannot run on the current machine: classify it, park it, find a more
> resource-efficient implementation, schedule it differently, reduce redundant
> computation, use hash-bound reuse where valid. Continue measuring constraints
> so the OWNER understands opportunity cost, but solve them in software /
> scheduling first.

This decision is FINAL (directive §47). This page therefore documents how the
factory extracts **maximum useful evidence per wall-clock hour on the existing
VPS** (directive §12), not how to grow the machine.

## 1. Current hardware

| Item | Value | Source |
|------|-------|--------|
| Host | Hetzner **AX42-U**, bare metal | CLAUDE.md infra; fleet-scaling note 2026-09-01 |
| CPU | 8 cores / 16 threads | CLAUDE.md; power plan → High Performance (2026-09-01) |
| Physical RAM | ~63 GB (63.1 GB seen live) | terminal_worker drain arithmetic notes |
| Pagefile | 64 GB fixed | reboot record 2026-09-11 |
| Factory drive | `D:/` | `factory_disk_policy.v1.json` |
| Repo / OS drive | `C:/` | infra constants |
| Timezone | W. Europe Standard Time | CLAUDE.md |

The host is shared by the T1–T10 backtest factory, the T_Live live terminal, and
the FTMO demo terminal (all on the same box; the custom-history isolation
separates directories, not accounts — OQ-17).

## 2. Live-reserved resources (never scheduled against)

These are held out of the factory's schedulable capacity:

- **T_Live** — the live Darwinex Zero terminal (`C:/QM/mt5/T_Live`). Never a
  factory worker; excluded from the path-anchored terminal selection.
- **FTMO demo terminal** — read-only to the factory.
- **MT5_Base / OS baseline** — the drain arithmetic reserves an *undrainable
  host baseline* of `DRAIN_WINDOW_HOST_BASELINE_GB = 10 GB` (T_Live + workers +
  OS) and never schedules a job into it.
- **Per-worker RAM headroom floor** — `RAM_MIN_FREE_GB = 14 GB` must remain free
  after any candidate's reservation (`OPT_CENSUS_POST_RESERVATION_FLOOR_GB = 8 GB`
  for the small census lane).
- **Disk low-water** — the tester-cache purge parks `D:` at **60 GB** free
  (`tester_cache_purge_low_water_gb`, live task `QM_StrategyFarm_TesterCachePurge`
  `-LowWaterGB 60`); `worker_disk_min_free_gb = 40 GB`;
  `research_scratch_min_free_gb = 20 GB`. Layering invariant: worker floor ≤
  purge low-water ≤ research floor on the factory drive.
- **Research scratch placement** — research scratch lives on **`C:`** (the OS
  drive), not the factory drive, so research I/O never competes with tester cache
  on `D:`. When research scratch is on the factory drive it reads
  `tester_cache_purge_low_water_gb` as its protection floor
  (`research/research_env.py`), so the two can never contradict.

## 3. RAM classes and the reservation table

Every claimable row is assigned a conservative **launch reservation** — the RAM
that must be free before the worker starts its terminal64/metatester subtree.
The class is derived in `terminal_worker._ram_reservation_detail_for_candidate`;
the final reservation is `max(flat_class, measured_expectation, phase_floor)`, so
a live measurement or a phase floor can only ever **raise** it. The RAM
emergency reaper is the backstop for a run whose working set balloons past its
reservation.

| RAM class | Live flat reservation | Notes |
|-----------|-----------------------|-------|
| `opt_census_cell` | 4 GB | DL-089 annual census cell (small lane, protected) |
| `ordinary` | 8 GB | single-symbol ordinary tester |
| `two_leg_fx_pair` | 24 GB | two-leg FX basket sleeve |
| `two_leg_metal_pair` | 24 GB | XAU/XAG two-leg metal basket |
| `single_index_tick` | table (see below), else 44 GB | per index base |
| `multi_leg_fx_basket` | 44 GB | ≥3-leg FX basket |
| `heavy_or_unknown_multisymbol` | 44 GB | heavy / unclassified multi-symbol |

**Per-index-base table** (`INDEX_TICK_RESERVATION_GB_BY_BASE`, live; rollback
`QM_INDEX_TICK_RESERVATION_TABLE=0`): SP500 44, NDX 12, GDAXI 24, WS30 12,
UK100 24.

### Calibrated table proposal (measured, opt-in)

`resource_footprint_readmodel.py` derives the empirical footprint per (RAM class,
symbol class, gate, run-kind) from the worker's per-run ledger
(`tester_memory_ledger.jsonl`, schema `qm.tester_memory_ledger/v1`) over a
trailing 14-day window and writes:

- **`D:/QM/reports/state/resource_footprints.json`** (schema
  `qm.resource-footprints/v1`) — peak-RAM percentiles, duration percentiles,
  sample counts, run-kind mix. CPU share and disk I/O are **NOT_EVALUATED /
  EVIDENCE_MISSING**: the ledger records neither counter, so they are not
  derivable from this source and are reported as such rather than guessed.
- **`tools/strategy_farm/config/resource_footprints.v1.json`** (schema
  `qm.resource-footprints-proposal/v1`) — the **calibrated reservation table
  proposal** with `n`, `p95`, safety factor and proposed reservation per class
  and index base. Formula: `proposed = clamp(ceil(p95*1.5 + 2), 6, 48)`; a key
  with `n < 8` keeps its live reservation (`low_evidence: true`, never lowered
  without evidence).

Selected calibration findings (14-day window, ~19k runs, generated
2026-09-15) — these are **proposals**, not applied:

| Class / base | n | p95 peak RAM | live | proposed | delta |
|--------------|---|--------------|------|----------|-------|
| `single_index_tick` | 489 | 10.6 GB | 44 | 18 | **−26** |
| `ordinary` | 2421 | 11.9 GB | 8 | 20 | +12 |
| `two_leg_fx_pair` | 15 | 33.3 GB | 24 | 48 | +24 |
| index base NDX | 284 | 10.6 GB | 12 | 18 | +6 |
| index base GDAXI | 162 | 9.3 GB | 24 | 16 | −8 |
| index base WS30 | 31 | 3.2 GB | 12 | 7 | −5 |
| SP500 | 0 | EVIDENCE_MISSING | 44 | 44 | kept |

The headline: `single_index_tick` is reserved at 44 GB but its measured p95 is
~10.6 GB — the single largest driver of the head-of-line block. The proposal
lowers it toward the measured envelope while keeping SP500 at 44 GB (no
full-window SP500 run in the window) and keeping the RAM reaper as the balloon
backstop.

**Activation is opt-in and staged.** The live reservation table is **not**
switched automatically (directive §12). Set `QM_RAM_TABLE=calibrated` (machine
scope) to make the worker substitute the calibrated flat reservation for a
class/base; the `max(flat, measured, floor)` machinery, every admission floor and
the reaper are unchanged. Default (unset / `observed` / `0`) reproduces today's
behaviour byte-for-byte. Rollback: clear the env and reload workers.

## 4. Heavy-job handling and admission rules

The claim path is resource-aware, not FIFO. Ordinary admission (always on):

1. A candidate is admitted only when `free_ram − reservation ≥ floor`
   (14 GB / 8 GB census). Otherwise it is RAM-skipped and the worker falls
   through to lighter work.
2. **CENSUS-FIRST** (`QM_CENSUS_FIRST_RAM_PRIORITY`): while claimable census
   cells exist, a heavy candidate that would push free RAM below the protected
   census band is deferred this round so the small cells keep flowing.
3. **Bounded drain window** (`QM_DRAIN_WINDOW`): a genuinely heavy row
   (≥ 24 GB) that can never win under the normal gate may arm a bounded drain
   that parks short rows so the heavy row can run; auto-expires after 30 min,
   90-min cooldown.
4. **Exclusive lane** (`QM_DRAIN_EXCLUSIVE`): a ≥ 40 GB row (SP500 /
   heavy multi-symbol) runs **alone** — a pre-drain refuses new long-run claims
   while short rows finish, then the fleet parks and the row runs solo. Daily
   cap + cooldown.

### Resource-aware pre-drain admission (directive §12, opt-in)

The failure mode this fixes (see the bottleneck block below): a single heavy row
at the claim head arms an exclusive pre-drain that self-parks the whole fleet,
even though many smaller rows would fit the current headroom — idling 7–8 of 10
terminals while hundreds of claimable rows wait.

When `QM_RESOURCE_SCHEDULER` is on (`resource_scheduler.py` +
`config/factory_scheduler.v1.json`), the worker adds one selection-only rule
around **arming** a pre-drain (it never touches the case where a pre-drain is
already open, never changes a verdict or reservation, and preserves the drain
lane semantics and tests):

- **Bin-packing over the head window.** The worker surveys the top-N claimable
  rows (default 12, widening the legacy top-3 preflight) and identifies the
  highest-value candidate that FITS current headroom. A candidate that does not
  fit is skipped **without** opening a pre-drain.
- **Heavy-job policy.** A heavy (≥ 24 GB) candidate opens the exclusive
  pre-drain **only** when *no fitting smaller candidate* exists in the head
  window **and** the fleet is in a quiet window (fewer than
  `quiet_window_max_active_cells = 2` active cells). Otherwise it waits and the
  fitting smaller rows keep the terminals busy.
- **Starvation guard.** A heavy candidate continuously suppressed for
  `heavy_starvation_max_wait_minutes = 45` is allowed to open a pre-drain
  regardless of fill, so heavy work never starves. The override is logged
  (`resource_scheduler_predrain_suppressed` events; sidecar
  `state/resource_scheduler.json`).

Kill switch `QM_RESOURCE_SCHEDULER=0` (default) restores the legacy behaviour;
all knobs live in `config/factory_scheduler.v1.json` with defaults that reproduce
today's thresholds.

## 5. Current bottlenecks (generated snapshot)

<!-- GENERATED from D:/QM/reports/state/factory_bottleneck.json — regenerate; do not treat free-RAM as permanent (directive §39). -->

_Snapshot generated_at_utc: **2026-09-15T17:52:02+00:00** — regenerated by the
factory-bottleneck read-model; values are volatile._

- **[CRITICAL] `unwinnable_reservation_head_of_line_block`** — 7/10 terminals
  self-parked in `drain_predrain` (reservation None GB, ea None) while **356**
  claimable pending rows wait unclaimed. This is the exact failure the
  resource-aware pre-drain admission above targets.
- **[HIGH] `frontier_band_Q02`** — 2090 pairs have Q02 as their highest
  contiguous valid gate (largest advanceable frontier band).
- **[MEDIUM] `hold_backlog_RAM_RESERVATION_44GB_NOT_WINNABLE_20260914`** — 531
  rows held under `RAM_RESERVATION_44GB_NOT_WINNABLE_20260914` (largest
  non-benign active-hold class). The calibrated table proposal (§3) plus the
  pre-drain admission (§4) address the root cause of this hold class.
- Disk: `D:` free 62.2 GB (low-water 60 GB).

To refresh this block, re-run the factory-bottleneck read-model and paste the new
summary; the numbers above are a point-in-time snapshot, not a permanent fact.

## 6. Objective

Maximum useful evidence per wall-clock hour on the fixed host: fill available
capacity with the highest-value combination of runnable jobs; let heavy jobs run
alone, in quiet windows, or with reduced concurrency; keep the small census lane
flowing; and never let one 44-GB-class job head-of-line block the fleet.

## Files & contracts

- `tools/strategy_farm/resource_footprint_readmodel.py` → `D:/QM/reports/state/resource_footprints.json` (`qm.resource-footprints/v1`) + `tools/strategy_farm/config/resource_footprints.v1.json` (`qm.resource-footprints-proposal/v1`)
- `tools/strategy_farm/resource_scheduler.py` (pure decision math) + `tools/strategy_farm/config/factory_scheduler.v1.json` (`qm.factory-scheduler/v1`)
- `tools/strategy_farm/terminal_worker.py` — admission seam (kill switch `QM_RESOURCE_SCHEDULER`), calibrated-table override (`QM_RAM_TABLE=calibrated`)
- `tools/strategy_farm/config/factory_disk_policy.v1.json` — disk low-water policy
- Read-model: `D:/QM/reports/state/factory_bottleneck.json` (`qm.factory-bottleneck/v1`)
