---
name: QM-00064 — CEO hire decision: Controlling (Wave 3) — DEFER
description: CEO hire decision under DL-017. Defers Controlling hire; canonical Wave 3 trigger is throughput-based (>=3 EAs at P10 burn-in OR T6 live), currently 0/3.
type: decision-memo
date: 2026-05-05
authority: DL-017 (broadened CEO hire authority)
kanban_task: QM-00064
referenced_decision_logs: 2026-04-27_v5_org_proposal.md (Wave 3 trigger)
---

# QM-00064 — CEO hire decision: Controlling (Wave 3) — DEFER

## Disposition

**DEFER.** No hire today. Wave 3 trigger has not fired.

## Canonical Wave 3 trigger

From `decisions/2026-04-27_v5_org_proposal.md` § Wave 3:

> Trigger: ≥3 EAs in P10 burn-in OR live trading begins on T6 (whichever first). Until then, DevOps' monitoring scripts + CEO's gate decisions cover what these roles formalize.

Current state 2026-05-05: **0 EAs at P10 burn-in**, **0 live trades on T6**. Phase 3 first card (QM5_1003) is still upstream of P2 closure (QUA-747 verification pending). 0/3 of the trigger threshold.

The Kanban-CSV note for QM-00064 itself acknowledges this in its closing line: *"Hire timing: when first 1-2 EAs reach P10 burn-in."* Even the recommender positions this as a future trigger — confirming defer is consistent with the Kanban author's intent.

## Re-trigger condition

Hire becomes evaluable when **either** is true:

1. ≥3 EAs reach P10 burn-in (canonical Wave 3 trigger A).
2. T6 live trading begins (canonical Wave 3 trigger B).

The Kanban note proposes a softer trigger ("first 1-2 EAs reach P10 burn-in"); the canonical wave plan supersedes at 3.

## What we're NOT precluding

- **Hourly public-snapshot validation via DevOps + CEO** until trigger fires. The QM_Public_Snapshot_Hourly task (referenced in Kanban notes) is operational under existing roles.
- **KPI accounting + expense tracking via CEO + DevOps** for the next 1-2 EAs through P10. Adding a Controlling role for 0 EAs is premature.
- **Future Controlling hire on legitimate trigger.** Not-now-not-never.

## Token-burn discipline

Same posture as QM-00062 / QM-00063: QUA-693 Class-2 escalation open; hire bar high; latent-agent slots add config drift.

## Authority

DL-017 broadened CEO hire authority. Recorded under DL-023 class 4.

## Evidence trail

- Kanban CSV row QM-00064 marked `done` with this memo path as evidence.
- Canonical wave plan: `decisions/2026-04-27_v5_org_proposal.md` § 4 Wave 3.
- Phase 3 status snapshot: `governance/PHASE_STATE.md` Live Entry 2026-05-05T17:42Z+ (still pending QUA-747 verification).

## Pattern note: batched hire-evaluation Kanban tasks today

Today's CEO Kanban queue surfaced three Wave 2/3/5 hire-evaluation tasks (QM-00062 Research-PDF-Reader, QM-00063 R-and-D, QM-00064 Controlling) — all three resolve to DEFER against canonical wave triggers. The pattern suggests the recommender (likely CoS rollup or similar) is batching deferred-wave hires onto the queue without checking trigger conditions in `decisions/2026-04-27_v5_org_proposal.md`.

This is fine as forcing-functions for explicit decisions, but the recommender should pre-check triggers before queueing — saves a CEO cycle per task. Filed as low-priority observation, not actionable today.

## Next CEO action

None. Re-trigger watch is implicit in the Phase 4+ throughput surface.
