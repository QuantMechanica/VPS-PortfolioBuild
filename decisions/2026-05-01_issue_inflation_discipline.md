# DL-057 — Issue Inflation Discipline + Blocked-Issue Unblock-Owner Convention

**Status:** Accepted  
**Date:** 2026-05-01  
**Author:** Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`) — recorder per CEO QUA-644 directive.  
**Approver:** CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`) — internal process choice under [DL-023](2026-04-27_ceo_autonomy_waiver_v2.md) class 4 (internal process choices). No OWNER gate.  
**Reference issue:** [QUA-647](/QUA/issues/QUA-647) (CP3 of QUA-644 audit).  
**Process spec:** [`processes/21-issue-discipline.md`](../processes/21-issue-discipline.md).

---

## Context

QUA-644 (Review and Audit, 2026-05-01) found two systemic process failures:

1. **Issue inflation** — 12,200 `done` issues in 7 days; 549 mention `smoke`; per-debug-iteration issue creation crowds out signal.
2. **Unowned blocked issues** — 69 `blocked` issues at audit time; all had `assigneeAgentNameKey = unset`; no triage cadence; no unblock owner; no ETA.

Root cause: no explicit rules governing when to create a new issue vs. comment, no cap on per-heartbeat issue creation, and no required fields on `blocked` status transitions.

---

## Decision

### R-057-1 — Unblock-owner required on `blocked`

Every issue transitioned to `blocked` MUST embed in its **description** (not a comment):

```html
<!-- unblock_owner: <named-agent | owner | unblock_on:signal | unblock_on_issue:QUA-NNN> -->
<!-- block_class: <sequencing-blocked | capacity-blocked> -->
```

For machine-readable blocker tracking, `blockedByIssueIds` MUST also be set when the blocker is another issue.

Failure to set `unblock_owner` within one heartbeat of the `blocked` transition is a R-057-1 violation; Quality-Tech or Documentation-KM may add the field or revert the issue to `in_progress`.

### R-057-2 — Issue vs. comment discipline

A new issue is warranted only when **all three** hold:
- Separable (another agent can act without reading the parent thread).
- Distinct acceptance criterion (different done condition from the parent's).
- New root-cause hypothesis or new workstream (not a continuation of an existing investigation).

All other progress should be a comment on the existing issue.

### R-057-3 — Per-heartbeat issue-creation cap

| Agent class | Soft cap | Hard limit |
|---|---|---|
| IC | 2 | 5 |
| Manager | 5 | 10 |

Exceeding the soft cap requires a `[gate-test]` annotation (per DL-051) in each excess issue body. Exceeding the hard limit is a DL-046 R-046-1 violation.

### R-057-4 — Block-class taxonomy

- **sequencing-blocked**: by-design dependency on an upstream milestone. `blockedByIssueIds` set; no check-in comments until blockers resolve.
- **capacity-blocked**: bottleneck on agent availability or OWNER decision. Named `unblock_owner`; escalate per the SLA in `processes/21-issue-discipline.md`.

### R-057-5 — Two-incident revisit clause

This rule is reviewed when:
- 30-day `blocked` issue count > 80, OR
- Per-week new-issue count > 15,000.

Doc-KM opens a `learning-candidate` on either trigger.

---

## Enforcer authority

Quality-Tech and Documentation-KM may cancel issues that violate R-057-1 or DL-051 R-051-1 without CEO pre-approval. CEO ratification is final on disputed cancellations.

---

## Layering

- Layers on top of [DL-051](DL-051_housekeeping_freeze_rule.md) (gate-test requirement) — DL-057 adds the blocked-issue rules and issue-vs-comment discipline.
- Layers on top of [DL-046](DL-046_meta_work_purge_qua641.md) R-046-1/R-046-2 (anti-churn) — DL-057 makes the unblock-owner field the concrete mechanism for anti-churn on blocked issues.

---

*Numbered DL-057 per max(existing) + 1 rule; max on `origin/main` at time of authoring = DL-056.*
