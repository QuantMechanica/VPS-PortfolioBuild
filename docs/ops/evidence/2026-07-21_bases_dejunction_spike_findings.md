# Shared-bases de-junction — T5 spike findings (2026-07-21)

Empirical exploration of the structural fix for the history-lock storm
(diagnosis: `2026-07-21_qm20004_infra_diagnosis.md`). OWNER asked to solve it now
rather than wait for the weekend. Reversible spike on the parked terminal T5.
Tooling: `D:\QM\reports\state\bases_dejunction_20260721\t5_spike.ps1` (`-Apply` / `-Rollback`).

## Disk blocker: RESOLVED
D: 44.7 → **98 GB free**. Reclaimed via log-bombs (4.8 GB, 506 old tester logs),
old work_item+compile report dirs >14d (22.3 GB / 99.9k dirs), and a concurrent
`tester_cache_purge` (~32 GB). The 155 GB `reports\pipeline` is genuinely
live/current Q08 sweep data (110 GB protected live-sleeve + density EAs, 42 GB
fresh <14d) — correctly kept (status-aware reclaim: only 138 tiny dead-EA dirs
were safe to purge). Evidence archive of small verdict files:
`D:\QM\reports\pipeline_evidence_archive\`.

## Structure confirmed
`D:\QM\mt5\T2..T10\bases` = ONE NTFS junction → `T1\Bases`, which holds sibling
dirs: `Custom` (43 GB, read-only backtest .DWX data — safe to share) and
`Darwinex-Live` (22 GB volatile raw broker store — the storm source), plus the
custom-symbol definition metadata (`symbols.custom.dat` + 6 more `.dat`, `Default`,
`signals`). Conversion-symbol footprint inside Darwinex-Live (history+ticks):
EURUSD 3.35, GBPUSD 2.05, USDJPY 1.93, AUDUSD 1.37, NDX 1.91 GB; index/metal
(GDAXI/WS30/XAU) ~0.1 GB. Full per-terminal seed = **10.7 GB × 9 = 96.6 GB**.

## The restructure DESIGN works
`t5_spike.ps1 -Apply` successfully: dropped T5's whole-bases junction, created a
real `T5\bases`, re-shared `Custom` via a **nested junction** (0 extra disk,
read-only data), and copied the small metadata (.dat/Default/signals). Verified:
`T5\bases\Custom` = Junction → `T1\Bases\Custom`, `T5\bases` = real dir, 7 .dat
files present. So the "share Custom, own Darwinex-Live" topology is sound.

## KEY EMPIRICAL FINDING — seeding is impossible factory-ON
The seed copy FAILED: `Copy-Item ...\Darwinex-Live\history\EURUSD\2018.hcc :
being used by another process`. A running tester holds the exact contended file.
**This is direct proof that the file-sharing IS the storm** — and that any
SEEDED fleet fix (copying conversion history from T1) REQUIRES a Factory-OFF
window (the source files are live-locked).

## Two viable rollout paths
1. **Seeded, Factory-OFF window** (T_Live untouched): OFF → for each T2..T10,
   run the restructure + seed the conversion symbols from the now-quiescent T1
   store (96.6 GB fits in 98 GB free, tight; or light-seed EURUSD+index ~49 GB) →
   ON. Clean, but needs the window.
2. **No-seed cold-cache, potentially Factory-ON**: restructure each terminal with
   an EMPTY per-terminal Darwinex-Live (NO copy → no lock problem), let each
   re-sync conversion history from the live SERVER on demand into its OWN isolated
   store. The deployed storm-mitigation (commit 3d6fc09c9) self-heals the
   cold-cache re-sync burst. If validated, this fixes the fleet WITHOUT an OFF
   window. **Open validation:** run one GDAXI ad-hoc backtest on a restructured
   T5, confirm it re-syncs EURUSD into T5's own store and completes with NO
   cross-terminal `error [32]`.

## ★ CONTENTION PROOF — path 2 (no-seed) CONCLUSIVELY VALIDATED (2026-07-21 12:24-12:31)

Ran the no-seed restructure on parked T5, then a GDAXI.DWX 2020 ad-hoc backtest
**while the factory was actively storming** the shared store (T7=GDAXI, T8=EURUSD,
T2=NDX, T4=SP500, T1=WS30 all running EUR/index Q02+ concurrently). Measured
`error [32]` sharing-violations in the SAME window:

| Terminal | store | error[32] (sharing-violation) |
|---|---|---|
| **T5** | **isolated (own Darwinex-Live)** | **0** |
| T7 (GDAXI) | shared | 707 |
| T4 (SP500) | shared | 542 |
| T8 (EURUSD) | shared | 440 |
| T2 (NDX) | shared | 318 |

T5 latched a valid GDAXI report (PASS), re-synced 110 files into its OWN store from
the server, and logged **zero** sharing-violations while the shared terminals took
300-700 each. The single T5 `history-not-found` line was the run_01 cold-cache miss,
which self-healed on run_02 (exactly the class the deployed mitigation handles) — NOT
contention. **An isolated per-terminal Darwinex-Live eliminates the storm entirely,
factory-ON, no seed copy, no OFF window.**

## Status / urgency — REVISED
The no-seed fleet fix is validated factory-ON. The fleet rollout (restructure T2..T10:
real bases + nested Custom junction + empty own Darwinex-Live, per-terminal reversible)
can be done WITHOUT a Factory-OFF window — each terminal cold-syncs its conversion
history from the server into its isolated store on first use, self-healed by the
mitigation. Caveat: a first-use cold-cache re-sync burst across the fleet (transient,
mitigation-covered). The seeded path (needs OFF) is now unnecessary. T5 rolled back to
clean junction (verified). Recommended: execute the no-seed fleet rollout as a
deliberate op (one terminal at a time, verify, rollback-ready) — OWNER's call on timing;
no OFF window required. Weekend ToDo block C to be updated.
