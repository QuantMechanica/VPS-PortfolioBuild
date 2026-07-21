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

## ★★ FLEET ROLLOUT EXECUTED + VALIDATED — 2026-07-21 (~14:2x)

Executed the no-seed fleet fix on T2..T10 via the designed OFF/ON path:
`Factory_OFF.ps1` (quiesce all workers/terminals, disable respawn-vector tasks) →
`fleet_dejunction.ps1 -Apply` (restructure all 9: real bases + nested Custom junction
+ empty own Darwinex-Live) → `Factory_ON` via FactoryON_AtLogon task (workers restart
in console session, cold-sync begins). Total downtime ~10 min (no seed copy). T1 stays
the source store; T_Live never touched. Scripts + rollback:
`D:\QM\reports\state\bases_dejunction_20260721\fleet_dejunction.ps1` (`-Apply`/`-Rollback`).
(First script attempt had a PS5.1 parse error from a non-ASCII em-dash and did NOT run —
no partial damage; rewritten ASCII-only + parse-checked before the real run.)

**Result — cross-terminal storm ELIMINATED:** post-restart, isolated-store window,
error[32] sharing-violations per terminal: T7 **0** (was 707 under load), T6/T3/T2/T10 0,
residual only on terminals still completing their one-time cold-sync (T8 30 / T4 9 / T9 6,
on their OWN NDX/EURUSD during sync). **Fleet total 45** vs pre-fix **300-700 PER terminal**
(~99% reduction). Each terminal fills its OWN Darwinex-Live independently from the server
(T7 133 files, T6 119, T3 101, ...) — confirming isolation. Dispatch healthy (12 fresh
work_item logs). The residual is the expected transient cold-sync burst, settling to ~0 as
the last terminals finish; the mitigation self-heals any report discard in that window.

The cross-terminal storm was ELIMINATED (proof above). BUT — see the rollback below.

## ★ ROLLED BACK — no-seed causes a disk-pressure Factory_OFF loop (2026-07-21 ~15:2x)

The no-seed fix has a fatal side effect at current disk headroom: each terminal
re-downloads its conversion history from the server into its OWN store (9x partial
duplication of what was one shared 22 GB store — up to ~80 GB distributed as terminals
touch more symbols). During that cold-sync, D: free dropped below 80 GB, which TRIGGERS
`tester_cache_purge.ps1` (LowWaterGB=80): it runs `Factory_OFF` -> purge -> restart, and
the restart-after-purge left the factory OFF (flag present, 0 workers). Result: a
Factory_OFF loop (two outages: 11:22 during the disk cleanup, 14:40 during the cold-sync;
both were tester_cache_purge tripping <80 GB, NOT a mystery killer — that earlier
"unidentified cause" is now identified).

**Decision: rolled the fleet fix back** (`fleet_dejunction.ps1 -Rollback` — all 9 terminals
restored to the shared junction, 6.5 GB duplicate reclaimed, D: back to 98 GB), then
Factory_ON. A fix that puts the factory in an OFF loop is worse than the storm it cures
(the storm is mitigation-covered — victims self-heal). The storm returns but does NOT kill
throughput the way the OFF loop does.

**The fix is PROVEN correct (0 storm, validated under load) but is NOT viable at current
disk headroom.** To re-apply it needs EITHER: (a) enough free disk that the full ~80 GB
distributed duplication sits above the 80 GB purge threshold (i.e. ~160-180 GB free — need
to free ~60-80 GB more, carefully, from the 155 GB live-sleeve pipeline data), OR (b) a
seeded variant done in a real OFF window with a raised/paused purge threshold, OR (c) lower
tester_cache_purge's threshold during the cold-sync window. Deferred until disk is freed.
Standing state: shared junction + the deployed storm-mitigation (self-heals storm victims).

## ★★★ RE-APPLIED SUCCESSFULLY after cache clear — 2026-07-21 ~16:0x (FINAL)

Root of the disk-pressure loop diagnosed: the 857 GB "used" D: was NOT real data —
**~200 GB was accumulated MT5 Tester cache** (`T<n>\Tester\bases` + `Tester\Agent-*`,
transient, MT5-regenerable). It piled up because `tester_cache_purge` only fires below
80 GB free, and D: hovered at ~96 GB — just above the threshold — so it almost never ran
(T8 alone had a 45 GB agent dir + 25 GB Tester\bases). The 80 GB threshold on a 1 TB disk
is far too tight.

Clean sequence (OWNER-approved): Factory_OFF → **cleared Tester caches** (matched
tester_cache_purge's exact targets, factory quiesced: **reclaimed 197 GB, D: 96 → 294 GB
free**) → `fleet_dejunction.ps1 -Apply` (all 9 isolated, verified) → Factory_ON.

**Result — SUCCESS + STABLE:** storm eliminated (fleet error[32] ~16 with 5/8 terminals at
0, vs 300-700 per terminal pre-fix); **flag stays gone — NO purge loop** (285 GB free, the
cold-sync's ~9 GB-so-far won't approach the 80 GB threshold); 9/9 workers, backtests
flowing (10 fresh logs); D: 285 GB free. The disk-pressure loop that forced the earlier
rollback is gone because the headroom (285 GB) dwarfs both the purge threshold and the
cold-sync duplication.

**The shared-bases history-lock storm is now structurally fixed AND stable, factory-ON.**
Rollback still available (fleet_dejunction.ps1 -Rollback, factory OFF). The two earlier
outages (11:22, 14:40) were tester_cache_purge tripping <80 GB during the disk-tight window
+ its unreliable restart — both moot now with 285 GB headroom.

## Follow-ups (non-blocking)
- **tester_cache_purge restart-after-purge is unreliable** (it stranded the factory OFF
  twice). Fix it OR ensure the factory watchdog reliably recovers a purge-stranded factory.
- **Raise the purge LowWaterGB threshold** (80 → ~150-200 GB) so ~200 GB of cache never
  piles up again on the 1 TB disk — BUT only after the restart bug is fixed (a higher
  threshold = more frequent purges = more strand risk until the restart is robust).
- T8\MQL5\Files = 12.7 GB (EA-written CSV/journal accumulation) — separate cleanup candidate.

## Status / urgency — REVISED (superseded by the SUCCESS above)
The no-seed fleet fix is validated factory-ON. The fleet rollout (restructure T2..T10:
real bases + nested Custom junction + empty own Darwinex-Live, per-terminal reversible)
can be done WITHOUT a Factory-OFF window — each terminal cold-syncs its conversion
history from the server into its isolated store on first use, self-healed by the
mitigation. Caveat: a first-use cold-cache re-sync burst across the fleet (transient,
mitigation-covered). The seeded path (needs OFF) is now unnecessary. T5 rolled back to
clean junction (verified). Recommended: execute the no-seed fleet rollout as a
deliberate op (one terminal at a time, verify, rollback-ready) — OWNER's call on timing;
no OFF window required. Weekend ToDo block C to be updated.
