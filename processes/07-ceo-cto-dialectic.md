---
title: Cross-Strand CEO ↔ CTO Dialectic
owner: CEO + CTO
last-updated: 2026-04-19
---

# 07 — Cross-Strand CEO ↔ CTO Dialectic

How strategic and technical decisions are reconciled across the two top strands. Current shape per [QUAA-68](/QUAA/issues/QUAA-68) (Option E — CTO strand rebalancing, CEO retains strategic framing).

## Trigger

- CEO proposes a new initiative with technical implications
- CTO identifies a technical constraint that changes what is feasible
- Budget or adapter-capacity change forces a re-shape of the agent org
- Quarterly review or external stimulus (board directive)

## Actors

- [CEO](/QUAA/agents/ceo) — strategic framing, final arbitration, cross-team budget
- [CTO](/QUAA/agents/cto) — technical feasibility, adapter / tool strategy, delivery shape
- Specialist advisors pulled in ad-hoc ([Strategy-Analyst](/QUAA/agents/strategy-analyst), [Quality-Tech](/QUAA/agents/quality-tech), [Research](/QUAA/agents/research))
- Board — approves only when escalated or budget threshold exceeded

## Steps

```mermaid
flowchart TD
    A[Trigger: strategic or technical change] --> B{Originator}
    B -- CEO --> C[CEO drafts strategic proposal]
    B -- CTO --> D[CTO drafts technical proposal]
    C --> E[Assign or comment to CTO for technical review]
    D --> F[Assign or comment to CEO for strategic review]
    E --> G[CTO responds: feasibility + shape]
    F --> H[CEO responds: priority + framing]
    G --> I{Aligned?}
    H --> I
    I -- yes --> J[Decision recorded, issue assigned to executor]
    I -- no --> K[Second-round dialectic: explicit trade-off comment]
    K --> L{Resolved?}
    L -- yes --> J
    L -- no --> M[Escalate to board approval]
    M --> N[Board decision]
    N --> J
    J --> O[Documentation-KM captures decision in issue doc]
```

## Exits

- **Success:** Decision is recorded on a single Paperclip issue with both CEO and CTO comment on record; executor assigned with concrete acceptance criteria.
- **Escalation:** Second-round disagreement → board approval via `request_board_approval`.
- **Kill:** A proposal withdrawn by its originator is marked `cancelled` with a comment explaining the withdrawal.

## SLA

- **First response:** each side responds within 1 business day of the handoff.
- **Second-round resolution:** within 3 business days of the disagreement surfacing; otherwise auto-escalate to board.
- **Decision record:** captured in the issue before any downstream executor picks the work up — no silent hand-offs.

## Notes

- The CTO strand was rebalanced in [QUAA-68](/QUAA/issues/QUAA-68) to diversify away from a Codex monoculture and to offload design / reasoning work. When the CTO is overloaded, CEO may route directly to specialist agents for technical review; the CTO is still consulted but not blocking on low-risk items.
- See the related research re-scope proposal in [QUAA-70](/QUAA/issues/QUAA-70).

## References

- Source issue: [QUAA-68](/QUAA/issues/QUAA-68)
- Research re-scope: [QUAA-70](/QUAA/issues/QUAA-70)
- Issue triage: [06-issue-triage.md](06-issue-triage.md)
