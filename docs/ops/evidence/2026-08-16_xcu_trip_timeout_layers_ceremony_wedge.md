# 2026-08-16 night ops: XCU coverage trip, basket timeout layers, ceremony wedge

All times local (UTC+2) unless suffixed Z.

## 1. XCU coverage containment trip (01:46)

Copy-on-claim fail-closed on `manifest has no archive rows for claimed
symbols: XCUUSD.DWX` (T10, QM5_21524 WTI/XCU basket). XCUUSD has no data
anywhere (master tree, D:\QM\data). Correct gate behavior, wrong layer: the
admission should never have queued it. 7 rows across 7 EAs deferred to
2026-09-01 (`xcuusd_no_archive_coverage_...`). Codex delivered the admission
gate same night (task 1ed12619, commit 7df940703, APPROVED): full member-set
manifest coverage check fail-closed across every insert path. **OWNER
decision pending: XCU data intake + manifest extension vs. retiring the 7
copper EAs.**

## 2. Basket smoke-timeout under-budgeting (root cause of all metals-basket deaths)

Three timeout layers exist; the failures ran through the middle one:

1. worker watchdog — honors payload `timeout_min` (was already 450 on most rows);
2. **farmctl smoke budget** — `max(7200, min(25200, 1800 + members*600))`:
   member COUNT, not corpus WEIGHT; a 2-member XAU/XAG basket gets the flat
   2h floor while its real full-window real-tick runtime exceeds it;
3. run_smoke per-run `-TimeoutSeconds` (receives layer 2's value).

QM5_20206, QM5_20236, QM5_20294 each burned all attempts at exactly the 2h
floor (20291 killed pre-doom to free the containment single-lease slot). The
class never had a fair Q02. Fix (Claude, commit 57e60130b, 5 unit tests):
`_payload_timeout_floor_seconds()` — `timeout_min` now also floors both
farmctl smoke branches, capped 25200s. Codex task 52e31a78 keeps the
enqueue-path derivation (rows must never appear without the override) and
reviews the commit (builder != approver). All 21 XAU/XAG rows un-deferred
after the fix went fleet-resident.

## 3. Ceremony #3 (OFF 04:39 → ON 04:55) and the health-gate wedge

- OFF #1 ended `OFF_INCOMPLETE` (task_drift=1 — manual purge triggers earlier
  that night; pacer_cleanup=False — python-husk stderr false negative). OFF #2
  completed clean. Standing release + mint
  `RTA-2026-08-16-XCU-ADMISSION-SMOKE-TIMEOUT`; codex build-lane artifacts
  interrupted by the drain (QM5_41020 build, 41018 card, magic registry) were
  absorbed by commit before minting.
- **ON wedged ~2h in `Wait-QmFactoryPostStartHealth`**: the gate requires
  fresh successful completions of the critical tasks. Pump completed (0) at
  05:43 after its ~20-min kill-safety audit, but the **AgentRouter can starve
  the gate structurally**: its runs now carry the (correct) per-card
  manifest-coverage admission and run long; the 5-min trigger cadence then
  REFUSES overlapping starts and each refusal writes 0x800710E0 into
  LastTaskResult, poisoning the freshness check indefinitely.
- Resolution: `release-on-restart` identity check confirmed
  `restart_hold_ids: []` (nothing pending an authenticated release), so the
  wedged ON host (PID 764) was terminated; its mutation lock self-removed on
  process exit (DELETE_ON_CLOSE). Workers (already PASS_ISOLATED, all fixes
  resident) began claiming immediately; QM5_11483 Q05 work took the first
  slots.

**Follow-up (before the next ceremony)** — Codex task: fix the post-start
health gate's router-completion semantics (accept a running router instance
or a task-START freshness for tasks whose legitimate runtime exceeds the
trigger cadence; do not treat scheduler overlap-refusals as failures).

## Net state at 07:15

Full parallelism restoring under claim orchestration; resident fixes:
ENOSPC transient class, claim orchestration, archive admission gate, smoke
timeout override. Parked: 7 XCU rows (OWNER data decision), QM5_1537 family
(calendar rework a96ddcdd, guard cleared, Codex implementing). Reviews
closed this night: 5b827de5, 6aa33aa5, 1ed12619, fea371c2 (all APPROVED).
