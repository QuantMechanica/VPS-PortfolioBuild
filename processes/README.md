# Company Processes

End-to-end flow specs for QuantMechanica. Scope: cross-agent choreography, not per-agent role definitions. For role scopes see each agent's `instructions/AGENTS.md`. For the organizational spec see `Company/QUANTMECHANICA_ORG_SPEC_v1.2.md`.

Each process file follows the same structure:

- **Trigger** — what starts the flow
- **Actors** — which agents are involved (linked)
- **Steps** — sequence with decision points (Mermaid flowchart)
- **Exits** — success, escalation, kill
- **SLA** — timing expectations

## Index

| # | Process | File | Primary owner |
|---|---------|------|----------------|
| 1 | EA Life-Cycle (G0 → P10) | [01-ea-lifecycle.md](01-ea-lifecycle.md) | [CTO](/QUAA/agents/cto) |
| 2 | ZT / NO_REPORT Recovery | [02-zt-recovery.md](02-zt-recovery.md) | [Strategy-Analyst](/QUAA/agents/strategy-analyst) |
| 3 | V-Portfolio Deploy | [03-v-portfolio-deploy.md](03-v-portfolio-deploy.md) | [Pipeline-Operator](/QUAA/agents/pipeline-operator) |
| 4 | Incident Response | [04-incident-response.md](04-incident-response.md) | [Observability-SRE](/QUAA/agents/observability-sre) |
| 5 | Dashboard Refresh Cadence | [05-dashboard-refresh.md](05-dashboard-refresh.md) | [Strategy-Analyst](/QUAA/agents/strategy-analyst) |
| 6 | Issue Triage | [06-issue-triage.md](06-issue-triage.md) | [CEO](/QUAA/agents/ceo) |
| 7 | Cross-Strand CEO ↔ CTO Dialectic | [07-ceo-cto-dialectic.md](07-ceo-cto-dialectic.md) | [CEO](/QUAA/agents/ceo) + [CTO](/QUAA/agents/cto) |
| 8 | Daily Operating Rhythm | [08-daily-operating-rhythm.md](08-daily-operating-rhythm.md) | [Documentation-KM](/QUAA/agents/documentation-km) |
| 9 | Disaster Recovery | [09-disaster-recovery.md](09-disaster-recovery.md) | [DevOps](/QUAA/agents/devops) |
| 10 | Agent Re-scope | [10-agent-rescope.md](10-agent-rescope.md) | [CEO](/QUAA/agents/ceo) |
| 11 | Disk-Management and Drive-Sync-Maintenance | [11-disk-and-sync.md](11-disk-and-sync.md) | [Observability-SRE](/QUAA/agents/observability-sre) |
| 12 | Board Escalation Contract | [12-board-escalation.md](12-board-escalation.md) | [Documentation-KM](/QUAA/agents/documentation-km) |

## Ownership & review cadence

[Documentation-KM](/QUAA/agents/documentation-km) owns this folder. Review cadence: **quarterly**. Process maps decay fast — when any flow changes materially, the agent that owns the change must open an issue against Doc-KM to update the relevant spec before merging the behavioral change.

## How agents reference these docs

Agent `system_prompt.md` / `AGENTS.md` files should **link** to the relevant process file, not duplicate steps. Example:

```markdown
## Escalation
When a ZT run yields NO_REPORT, follow [ZT recovery](../Processes/02-zt-recovery.md).
```
