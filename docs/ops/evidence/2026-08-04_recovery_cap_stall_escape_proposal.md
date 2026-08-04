# Recovery-Cap Stall Escape — Amendment Proposal (AWAITING OWNER RATIFICATION)

Date: 2026-08-04 ~12:55Z · Author: Claude · Status: **PROPOSED, not applied**

## Symptom

Post Factory-ON (10:15Z, decision FACTORY_PREPARATION_20260804_TEN_WORKER_ZERO_HOLD)
the fleet ran 2/10 workers for >2h against 1,681 pending work items. Throughput
10:15Z→12:30Z: 3×Q02 + 1×Q08 done. All 10 worker daemons alive (process scan),
commit headroom 90.9 GB, news-calendar preflight OK.

## Root cause (measured, read-only claim-path replication for T2)

`scratchpad/claim_diag.py` re-ran the exact `claim_atomic` filter chain over the
1,677 rows of `_priority_pending_query()`:

| skip reason                        | rows | example |
|------------------------------------|------|---------|
| recovery_capped                    | 1435 | 80c64b67 QM5_20007/XAUUSD.DWX/Q02 |
| multisym_serialized                | 141  | b837731f QM5_13079 basket Q02 |
| history:SYMBOL_NO_HISTORY_FOR_PERIOD | 52 | da441d49 QM5_12871/XBRUSD.DWX/Q02 |
| symbol_active                      | 37   | 03ee367f QM5_10305/XAUUSD.DWX/Q02 |
| avoid_terminal                     | 12   | 6ba4e2ad QM5_12382/WS30.DWX/Q02 |
| **CLAIMABLE**                      | **0** | — |

The ratified idle-only recovery cap (`farmctl.recovery_claim_allowed`, ULTRACODE
WS-A 2026-07-26) throttles recovery to ≤1 of the last 5 successful claims WHILE
any non-recovery pending row exists, and escapes only when the frontier is
GLOBALLY EMPTY. After the MNT-046 mass requeues the queue is 85% recovery-class;
the remaining 242 frontier rows exist but are all unclaimable (multisym
serialization behind one long Q05, symbol locks, missing history, avoid lists).
Existence ≠ claimability: no priority claim ever lands, the rolling ledger
window freezes with a recovery entry in it, and every worker idles. The
frontier-empty escape can never fire.

## Proposed amendment (prepared + tested, NOT applied)

`CLAIM_RECOVERY_STALL_ESCAPE_MINUTES = 15.0`: when the window cap would refuse
recovery, additionally check the age of the newest **priority** ledger entry.
If none exists in the retained tail, or the newest is older than 15 minutes,
the priority lane is provably stalled → recovery drains freely. The first
priority claim that lands re-arms the cap (share bound restored while the
frontier flows). Ordering is untouched: recovery rows still sort last and are
only reached after every priority row was claimed or skipped.

Safety properties preserved: idle-only (per-cycle ordering + fleet-wide
15-min priority silence required), durable/restart-safe (same ledger), share
bound intact while priority claims flow, unparseable timestamps keep the
conservative cap.

- Patched copies + full run: `scratchpad/sf_stall_fix/` — **26/26 tests pass**
  (4 existing synthetic drivers amended to seed a live priority lane; the old
  `test_recovery_idle_only_and_capped_with_ineligible_frontier` codified the
  starvation and is replaced by stall-drain + re-arm + conservative-cap cases).
- Diffs: `recovery_cap_stall_escape.farmctl.diff` (49 lines),
  `recovery_cap_stall_escape.tests.diff` (286 lines) in the session scratchpad;
  will be applied as a normal reviewed commit upon ratification.

## Why ratification is required

`recovery_claim_allowed` implements the RATIFIED idle-only contract with its own
decision record and explicit test coverage of the current (starving) behavior.
This is a semantic amendment of that contract, not a bug fix.

## Activation path once ratified

1. Apply the two-file amendment, commit with pathspecs.
2. The pump (`run_pump_task.py` → fresh `farmctl.py pump` subprocess, 10-min
   cadence) picks the new claim logic up immediately for dispatch-driven
   claims — the fleet refills within ~1–2 ticks without any factory window.
3. Resident terminal workers adopt at the next OFF/ON ceremony; farmctl.py is a
   bound source file, so the next mint covers the new SHA automatically.

## Related repairs from the same audit (already executed, ordinary ops)

- Stale `CLAUDE_DISABLED.flag` (set 2026-07-23 at 90% weekly, orphaned by a
  governor state reset, perpetually "leave-external" at 43%/65.7% pace):
  governor now reclaims ownership from the flag-body marker
  (`quota_governor.py`, commit 0956fe214) and released the flag on the next run.
- Dead-owner `codex_orchestration.lock` (PID 13408, killed in the OFF drain,
  3h "recent" skip loop): removed after process-scan proof; orchestration
  resumes on the next 15-min tick (Q09 round-4 ticket 177ac748 was stalled
  behind it).
