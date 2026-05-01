# DL-051 — Housekeeping-Freeze Rule (issue-creation gate)

- **Date:** 2026-05-01
- **Author:** CEO (`7795b4b0-…`)
- **Authority basis:** OWNER directive [QUA-665](/QUA/issues/QUA-665) D3 + DL-017 broadened CEO authority (operational decisions, internal process choices) + DL-023 waiver v3.
- **Successor / superset of:** [QUA-639](/QUA/issues/QUA-639) D2 (which set a 72h heartbeat throttle on infra/QUA-### housekeeping).
- **Related:** [DL-046](./DL-046_meta_work_purge_qua641.md) R-046-1 (no-keepalive-churn) and R-046-3 (no new self-monitoring infra without explicit OWNER ask).
- **Scope:** company-wide; binding on every agent (CEO, CTO, DevOps, Doc-KM, QT, QB, Research, Pipeline-Operator, Development) until explicit successor DL.

## Diagnosis

QUA-639 D2 closed a specific incident (infra/QUA-### housekeeping flooding the heartbeat queue) with a *time-bounded* 72h throttle. DL-046 closed the broader meta-work-purge with cancellations and demotions. Neither codified a *creation-time test* an agent can apply before opening a new issue.

Board Advisor finding 2026-05-01 (recorded in [QUA-665](/QUA/issues/QUA-665) issue body): "issue-creation-as-work is itself a diagnosed failure mode." Without a binding gate, the throttle decays the moment the 72h window expires.

This DL replaces the time-bounded throttle with a permanent creation-time gate.

## Binding rule (R-051-1) — Issue-creation gate

**Before any agent creates a new issue, the proposed issue MUST advance at least one of the following four critical-path workstreams:**

1. **An active Phase 3 EA gate** — the issue produces evidence on a P1..P10 transition for an APPROVED Strategy Card with an allocated `ea_id`.
2. **The Public Dashboard MVP (M3 / Phase 6)** — the issue ships a snapshot-schema row, a dashboard page, or a stale-alert wiring.
3. **A parked deliverable in [QUA-665](/QUA/issues/QUA-665) D2** — PC1-00 .git/ exclusion, PC6-01..06 dashboard, P0-13 T6 manifest dry-run, P0-15 expense log, VPS slippage/latency calibration JSON, CoS naming DL.
4. **A real incident with evidence** — i.e. an artifact in `docs/ops/`, a log line, a commit SHA, or an email/comment thread documenting a concrete failure that has already happened (not a theoretical one).

If a proposed issue cannot point at one of (1)..(4), it MUST NOT be created.

The gate test is intentionally narrow: "infrastructure for future agents", "framework hygiene sweep", "executionPolicy sentinel design", "token-cost observability shim", "prompt-audit pass", "wake-filter follow-up", "weekly run-rate snapshot" — none pass the gate unless they are bolted onto a specific (1)..(4) item with evidence.

## Binding rule (R-051-2) — Enforcer authority

Quality-Tech (Class-3 reviewer) and Documentation-KM (process-registry custodian) carry **enforcer authority**: either may close (transition `cancelled`, status comment naming this DL) any new issue that fails the R-051-1 gate, without escalation. The original creator may file a single appeal comment naming the (1)..(4) item the issue actually advances; if no item is named, the cancellation stands.

CEO retains ratification authority — if QT or Doc-KM cancels an issue and the creator's appeal is rejected, the creator can escalate to CEO via a single fresh comment. CEO ruling is final under DL-017.

## Binding rule (R-051-3) — Self-test before issue creation

Every agent, in the same turn that drafts a new issue body, MUST include a one-line `[gate-test]` annotation in the issue description naming the (1)..(4) bucket and the specific deliverable advanced. Example:

```
[gate-test] R-051-1 (3): advances QUA-665 D2 PC1-00 (Drive-sync .git/ exclusion).
```

Issues without a `[gate-test]` line are subject to R-051-2 cancellation on sight.

The annotation is short by design — it is a discipline artifact, not a justification essay. If the agent cannot fill the parenthetical truthfully, the issue does not pass the gate.

## Out-of-scope (gate does NOT apply)

- **OWNER-authored issues.** OWNER may create any issue without the gate-test line.
- **Board Advisor audit issues.** Board Advisor's diagnostic / audit issues (typically QUA-### filed against the company itself) are exempt — those *are* the incident-with-evidence input that drives DL revisions.
- **Subtasks of an already-gated parent.** If the parent issue passed R-051-1 at creation time, child issues inherit the gate-pass. The CEO sentinel duty (DL-030) is to verify the parent actually passed and the chain isn't a fictitious lineage to a gated grandparent.
- **Done-comments and PATCH updates.** R-051-1 gates issue *creation*, not status transitions, comment churn, or PATCH updates. Other rules govern those (R-046-1, etc).

## Rationale

OWNER's standing complaint (QUA-641, QUA-665) is throughput: the company's heartbeat budget keeps landing on infra/process meta-work instead of EA-build deliverables. DL-046 cancelled the existing meta-tickets but did not stop new ones from being filed. R-051-1 is the structural fix.

The four allowed buckets reflect the real V5 critical path:
- Phase 3 EA gates produce baseline reports → Phase 4 portfolio → Phase 5 T6 deploy.
- Dashboard MVP fulfills the build-in-public commitment.
- The parked deliverables in QUA-665 D2 are the queue of known unblockers.
- Real incidents are how the company learns; meta-incidents (theoretical risks) are not.

## Closeout / acceptance

This DL is steady-state, not a one-shot deliverable. Closeout signals (any of):

1. The 6 parked deliverables in QUA-665 D2 are all `done` or have explicit "deferred until X" triggers in PROJECT_BACKLOG.md.
2. By 2026-05-15, the count of company issues created with status `cancelled` due to R-051-2 enforcement is monotonically decreasing across each weekly window (i.e. agents have internalized the gate).
3. Token-spend trajectory bends down (CEO informal monitoring).

Successor DLs may tighten or loosen the buckets; this DL does not pre-commit a sunset date.

## Memory

This DL adds the following durable lessons to CEO memory:

- **Issue-creation-as-work is a failure mode.** The right counter is a creation-time gate, not a periodic backlog-purge.
- **Time-bounded throttles decay.** The 72h window from QUA-639 D2 evaporates at hour 73; permanent rules need permanent gates.
- **Enforcer authority must be named.** Without explicit QT + Doc-KM cancellation rights, the rule is aspirational.

## References

- [QUA-639](/QUA/issues/QUA-639) — prior 72h throttle (this DL is its permanent successor)
- [QUA-665](/QUA/issues/QUA-665) — parent directive
- [DL-046](./DL-046_meta_work_purge_qua641.md) — meta-work purge precedent (R-046-1, R-046-3)
- [DL-030](./2026-04-27_execution_policies_v1.md) — execution policy convention (CEO sentinel role basis)
- [DL-017](./DL-017_ceo_unilateral_hire_authority.md) and DL-023 — broadened CEO authority basis
