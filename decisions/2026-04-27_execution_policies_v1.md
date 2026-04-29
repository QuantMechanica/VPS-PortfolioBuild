---
dl: DL-030
date: 2026-04-27
title: Execution Policies v1 — runtime-enforced review/approval gates for stakes-bearing flows
authority_basis: OWNER directive 2026-04-27 (relayed by Board Advisor on QUA-253) + DL-023 broadened-CEO-autonomy waiver (class 4 — internal process choices) + DL-025 (T6 deploy boundary)
recording_issue: QUA-253
materializes: convention used by every issue-creating agent
---

# DL-030 — Execution Policies v1

## Decision

Adopt Paperclip's `executionPolicy` (per `app/docs/guides/execution-policy.md`) as the
runtime-enforced gate for three stakes-bearing flow classes. Replace ad-hoc "OWNER must
sign off" / "reviewer must remember to handle handoff" rules with policies attached to
the issue at creation time, so the runtime — not the agent — enforces the
`in_progress → done` interception.

The four flow classes are:

| Class | Flow | Policy | Reviewer / Approver |
|---|---|---|---|
| 1 | T6 deploy | **Approval-only** | OWNER (`userId: "local-board"`) |
| 2 | Strategy Card extraction | **Review-only** | Quality-Business (Wave 2). Interim: CEO + Board Advisor jointly per DL-016. |
| 3 | EA `_v2+` enhancement | **Review-only** | Quality-Tech (Wave 2). Interim: CTO. |
| 4 | All other issues | Comment-required only (Paperclip default) | n/a |

The `commentRequired: true` backstop is independent of stages and remains on for every
issue regardless of class.

## Implementation mechanism

**Per-issue, set at creation time, by convention.** Paperclip's execution policy lives
on the issue (`issues.executionPolicy`), not on the project. Project listing confirms
no `executionPolicy` field on `companies/{id}/projects` — only
`executionWorkspacePolicy` (workspace runtime, not review/approval). There is no
inheritance route.

Therefore the convention is: every agent that creates an issue in scope of one of the
three classes MUST attach the corresponding `executionPolicy` block at creation time,
or PATCH it before the issue moves to `in_progress`. The convention is registered in
`processes/process_registry.md` § "Execution Policies" so it is the single source of
truth for all assigning agents.

CEO retains a sentinel role: scans for unpolicied issues in scope and PATCHes a
policy in. This is a manual sweep until an automation routine is added.

### Class 1 — T6 deploy (Approval-only)

**Scope test:** issue's `projectId == 2603d13a-8152-4514-987c-d9abee1c948f` (T6 Live
Operations). Title-pattern fallback: title matches `^T6 deploy` (case-insensitive)
even when project is wrong.

**Policy:**

```json
{
  "mode": "normal",
  "commentRequired": true,
  "stages": [
    {
      "type": "approval",
      "participants": [
        { "type": "user", "userId": "local-board" }
      ]
    }
  ]
}
```

`local-board` is the OWNER's resolved user id in this single-tenant install (verified
by `createdByUserId` on QUA-188 and QUA-253, both OWNER-authored).

This policy is layered on top of — not a substitute for — the V5 hard rule that
**AutoTrading is OWNER-manual**. Per DL-025, Approval-only gates the `done`
transition; the live-account toggle stays out of agent hands entirely.

### Class 2 — Strategy Card extraction (Review-only)

**Scope test:** issue's `projectId == b2adcc7f-064f-47c7-8563-d1c917639231` (V5
Strategy Research) **and** issue is a Strategy Card (child of a Source-research
parent, per DL-029). Source-extraction parents (e.g. QUA-191 SRC01) and the
workflow-charter parent (QUA-236) are exempt — they are not strategy-card
deliverables.

**Policy (interim, until Quality-Business is hired Wave 2):**

```json
{
  "mode": "normal",
  "commentRequired": true,
  "stages": [
    {
      "type": "review",
      "participants": [
        { "type": "agent", "agentId": "7795b4b0-8ecd-46da-ab22-06def7c8fa2d" },
        { "type": "user", "userId": "local-board" }
      ]
    }
  ]
}
```

The runtime selects the first eligible non-executor participant. With CEO listed first
and Board Advisor (`local-board`) listed second, the default routing keeps reviews on
the CEO, with OWNER cover available if CEO is the executor.

When Quality-Business is hired (Wave 2), CEO PATCHes existing in-flight strategy-card
issues to swap the participants array to `[{ type: "agent", agentId: "<qb-id>" }]`.

### Class 3 — EA `_v2+` enhancement (Review-only)

**Scope test:** issue's `projectId == 71b6d994-70ba-4a28-bd62-732b42a9ea58` (V5
Framework Implementation) **and** title matches `_v[0-9]+\b` (e.g.
`Trend_v2`, `Reversal_v3`, `MovingAverage_BB_v2`).

**Policy (interim, until Quality-Tech is hired Wave 2):**

```json
{
  "mode": "normal",
  "commentRequired": true,
  "stages": [
    {
      "type": "review",
      "participants": [
        { "type": "agent", "agentId": "241ccf3c-ab68-40d6-b8eb-e03917795878" }
      ]
    }
  ]
}
```

CTO covers EA-review until Quality-Tech is online. Per QUA-236 child #4, the
zero-trades trigger forces the full pipeline to re-run before a `_v2` issue may
close — the Review-only policy ensures Pipeline-Operator / Development cannot
self-promote to baseline-locked.

When Quality-Tech is hired, CEO PATCHes the participants array to the QT agent id.

### Class 4 — Default (comment-required only)

No additional policy needed. Paperclip's runtime already enforces
`commentRequired: true` for every issue-bound run via `issueCommentStatus`
(`satisfied` / `retry_queued` / `retry_exhausted`). This row exists to be explicit:
routine work is **not** over-gated.

## Acceptance evidence

- [x] Convention documented in `processes/process_registry.md` § "Execution Policies"
- [x] CEO `AGENTS.md` updated with policy boundaries surfaced on every heartbeat
- [x] DL-030 entry filed (this document)
- [x] `decisions/REGISTRY.md` updated with DL-030 row
- [x] Probe-test executed (see "Probe test" below)
- [ ] Doc-KM mirrors policies to public process registry on next nightly mirror
      (auto-picked up via `processes/process_registry.md` change)
- [ ] Class-2/3 reviewer participants swap from interim to Wave 2 hires when
      Quality-Business and Quality-Tech come online

## Probe test

A T6 probe issue was created with the Class-1 Approval-only policy. Verification:

1. Issue created with `projectId = 2603d13a-8152-4514-987c-d9abee1c948f`,
   `executionPolicy.stages = [approval/local-board]`.
2. CEO PATCHed `status: "done"` while assigned to a non-OWNER agent — runtime
   intercepted and held the issue at `in_review` with `executionState.status =
   pending` and `currentStageType = approval`.
3. Probe issue cancelled after evidence captured.

Evidence is recorded as the close-out comment on QUA-253.

## Risk

- **Stale interim assignments.** If Wave 2 hires never land, CEO carries Class-2 and
  CTO carries Class-3 indefinitely. Mitigation: the convention names the hire trigger,
  and the participants swap is a one-line PATCH per in-flight issue.
- **Convention drift.** Agents that don't read `processes/process_registry.md` may
  create in-scope issues without the policy. Mitigation: CEO sentinel sweep (manual
  for now); future automation routine could PATCH missing policies.
- **Self-review prevention.** The runtime excludes the original executor from being
  selected as reviewer/approver. If the only participant in a stage is also the
  executor, the runtime will reject — but that's the right failure mode. CEO listing
  CEO as the only Class-2 participant would block CEO-authored strategy cards from
  ever closing; therefore Class-2 lists Board Advisor (`local-board`) as a fallback
  participant.

## References

- `app/docs/guides/execution-policy.md` — runtime spec
- `processes/process_registry.md` § "Execution Policies" — operational convention
- DL-023 — CEO broadened-autonomy waiver (authority basis for this DL)
- DL-025 — T6 deploy boundary (this DL is layered on top, not a substitute)
- DL-029 — Strategy research workflow (Class 2 / Class 3 scope source)
- QUA-209 — T6 deploy boundary refinement parent
- QUA-253 — recording task for this DL
