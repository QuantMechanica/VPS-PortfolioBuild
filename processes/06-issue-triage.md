---
title: Issue Triage Workflow
owner: CEO
last-updated: 2026-04-19
---

# 06 — Issue Triage Workflow

Routes a new issue (from board, agent, or automated source) to the right owner with the right priority.

## Trigger

- Board user opens an issue in Paperclip
- An agent creates an issue as a by-product of its heartbeat (child task, cross-team delegation, post-incident follow-up)
- External source fires a webhook routine that creates an issue

## Actors

- [CEO](/QUAA/agents/ceo) — primary triage (default inbox for unassigned top-level work)
- [CTO](/QUAA/agents/cto) — technical work delegate
- Domain specialists — [Quality-Tech](/QUAA/agents/quality-tech), [Quality-Business](/QUAA/agents/quality-business), [Strategy-Analyst](/QUAA/agents/strategy-analyst), etc.
- [Documentation-KM](/QUAA/agents/documentation-km) — docs / spec changes
- Reporter — responds to clarifying questions during triage

## Steps

```mermaid
flowchart TD
    A[Issue created] --> B{Has assignee?}
    B -- yes --> OWN[Assignee proceeds in normal heartbeat]
    B -- no --> C[CEO triage queue]
    C --> D{Clear scope?}
    D -- no --> E[CEO asks reporter for clarification]
    E --> C
    D -- yes --> F{Domain?}
    F -- technical build --> G[Assign CTO or Development]
    F -- quality / spec --> H[Assign Quality-Tech or Quality-Business]
    F -- strategy / research --> I[Assign R-and-D or Strategy-Analyst]
    F -- infra / live --> J[Assign DevOps or Pipeline-Operator]
    F -- docs / process --> K[Assign Documentation-KM]
    F -- observability --> L[Assign Observability-SRE]
    G --> OWN
    H --> OWN
    I --> OWN
    J --> OWN
    K --> OWN
    L --> OWN
    OWN --> M{Blocker identified?}
    M -- yes --> BLK[Set blockedByIssueIds, status=blocked]
    M -- no --> PROG[status=in_progress, work proceeds]
    BLK --> ESC[Escalate via chainOfCommand if blocker owner unresponsive]
```

## Exits

- **Success:** Issue reaches a correct owner within the triage SLA, moves to `in_progress` or `blocked` with explicit reasoning.
- **Escalation:** If the triage chain disputes ownership, [CEO](/QUAA/agents/ceo) is the tie-breaker; if CEO is disputed, escalate to board.
- **Kill:** Duplicates / invalid issues are moved to `cancelled` with a comment pointing to the canonical issue.

## SLA

- **Unassigned → CEO triage:** within 1 CEO heartbeat (≈ 15–30 min during active window).
- **Triage → assigned:** same business day.
- **Clarification round-trip:** not more than 2 rounds before CEO makes a best-guess assignment and notes the assumption.

## References

- Paperclip coordination skill (covers status lifecycle + API endpoints): invoke via the `paperclip` skill in-session; there is no repo-local `api-reference.md` today — the skill itself is the canonical source.
- Cross-strand coordination: [07-ceo-cto-dialectic.md](07-ceo-cto-dialectic.md)
