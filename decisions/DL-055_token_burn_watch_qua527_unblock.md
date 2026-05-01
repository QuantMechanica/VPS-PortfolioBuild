# DL-055 — Token-burn watch ownership: unblock QUA-527, raise to high, name DevOps as owner

**Date:** 2026-05-01
**Authority:** CEO under DL-023 (broadened authority) + QUA-684 D5 directive (OWNER 2026-05-01 via Board Advisor).
**Originating issue:** [QUA-684](https://paperclip.local/QUA/issues/QUA-684) D5; reverses CEO 2026-05-01T07:25Z deferral comment on [QUA-527](https://paperclip.local/QUA/issues/QUA-527).
**Supersedes:** none. Distinct from DL-052 (Chief-of-Staff naming; OS-Controller CoS retired).

## Context

OWNER 2026-05-01 reports token consumption is on track to block the company within ~4 days. QUA-684 D5 forced a decision today: (a) re-hire OS-Controller-scope CoS with OWNER pre-authorization, (b) unblock QUA-527 (DevOps token-cost daily snapshot) and raise to high, or (c) CEO owns the watch in heartbeat with named threshold-action map. Not a deferral.

CEO at 2026-05-01T07:25Z had previously commented on QUA-527 lowering it to `low` and routing the scope to QUA-548 ("complete only after V5 EAs are in P1"). DevOps acknowledged at 07:26Z and held QUA-527 blocked. That sequencing is no longer correct under a 4-day deadline.

## Decision — Option (b)

1. **QUA-527 unblocked and raised to `high`.** Owner remains DevOps (`86015301`). Reviewer remains CTO (`241ccf3c`) on the snapshot script.
2. **Notion-mirror gate waived as a blocker.** Doc-KM tracking issue QUA-525 was cancelled; the Notion mirror requirement moves to a parallel deliverable, not a precondition for closing QUA-527. The on-disk daily snapshot is the load-bearing artifact for the token-burn watch.
3. **Acceptance criteria reaffirmed (revised):**
   - `D:\QM\reports\ops\token_usage_<date>.json` written daily for ≥3 consecutive UTC days.
   - Per-agent 24h + 7d token consumption fields present.
   - Monthly forecast field present (linear extrapolation of last-7d slope).
   - Three soft alarms wired at 70% / 80% / 95% of OWNER-set provider cap. Each alarm fires a follow-up issue assigned OWNER.
   - Provider cap value follow-up tracked via QUA-542 (existing).
   - Notion mirror — parallel deliverable, not blocking close.
4. **CEO heartbeat consumes the snapshot.** Each CEO heartbeat reads the latest `token_usage_<date>.json` and the alarm-state. If 80%+ alarm fires, CEO posts a Class-2 escalation to OWNER per `processes/12-board-escalation.md`. If 95%+ alarm fires, CEO pauses non-critical agents per the runtime-health detector pattern.
5. **QUA-548 deprioritized.** Same scope as QUA-527; QUA-527 carries the lane. QUA-548 will be cancelled in CEO's next heartbeat sweep unless DevOps reports a reason to keep it open.

## Why not (a)

Re-hiring an OS-Controller-scope CoS contradicts DL-052 (the OS-Controller variant was retired) and adds new agent token cost — counterproductive when the deadline is *token burn*. The CoS function in DL-052 explicitly remains DEFERRED to Phase Final.

## Why not (c)

CEO heartbeat is on Opus and is the most expensive per-call agent in the company. Layering data-collection on top of strategic decisions inflates the heartbeat token cost. CEO should *consume* the snapshot, not *produce* it.

## Mechanism (CEO heartbeat threshold-action map)

| Alarm | CEO action |
|---|---|
| 70% | Read snapshot; note in PHASE_STATE.md Live Entry; no other action. |
| 80% | Class-2 escalation comment to OWNER on a new issue tagged `token-budget`; pause hire decisions. |
| 95% | Class-1 escalation: pause all non-critical (Class-3+) agent timer-heartbeats company-wide; CEO + DevOps decide which lanes stay live to land Phase 3 D1. |

All three thresholds open OWNER follow-up issues with the snapshot path cited.

## Cross-references

- [QUA-684](https://paperclip.local/QUA/issues/QUA-684) — directive parent.
- [QUA-527](https://paperclip.local/QUA/issues/QUA-527) — unblocked vehicle.
- [QUA-542](https://paperclip.local/QUA/issues/QUA-542) — provider-cap value follow-up (already open to OWNER).
- [QUA-548](https://paperclip.local/QUA/issues/QUA-548) — duplicate scope; deprioritized.
- [QUA-525](https://paperclip.local/QUA/issues/QUA-525) — cancelled Doc-KM Notion mirror tracker (no longer a blocker).
- DL-052 — Chief-of-Staff naming clarification (CoS variant remains deferred).
- DL-046 — anti-theater + no-keepalive-evidence-churn (snapshot is real measurement, not theater).
- `processes/17-agent-runtime-health.md` § Trigger #4 — token-budget detector spec.
- `processes/12-board-escalation.md` — escalation path used at 80%/95%.

— Filed by CEO at OWNER direction (via Board Advisor relay), 2026-05-01.
