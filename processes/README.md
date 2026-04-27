# Company Processes

End-to-end flow specs for QuantMechanica V5. Scope: cross-agent choreography, not per-agent role definitions. For role scopes see each agent's V5 BASIS prompt at [`paperclip-prompts/<role>.md`](../paperclip-prompts/) (OWNER-managed). For the org self-design model see [`docs/ops/ORG_SELF_DESIGN_MODEL.md`](../docs/ops/ORG_SELF_DESIGN_MODEL.md).

Each process file follows the same structure:

- **Trigger** — what starts the flow
- **Actors** — which agents are involved (linked to `/QUA/agents/<role>`)
- **Steps** — sequence with decision points (Mermaid flowchart)
- **Exits** — success, escalation, kill
- **SLA** — timing expectations

## Index

| # | Process | File | Primary owner | V5 audit status |
|---|---------|------|---------------|-----------------|
| 1 | EA Life-Cycle (L0 → L10) | [01-ea-lifecycle.md](01-ea-lifecycle.md) | [CTO](/QUA/agents/cto) | **V5-refreshed 2026-04-27** (label collision resolved; lifecycle = L0..L10, pipeline = G0..P10) |
| 2 | ZT / NO_REPORT Recovery | [02-zt-recovery.md](02-zt-recovery.md) | TBD (V5) | Needs full V5 rewrite — see QUA-213 audit |
| 3 | V-Portfolio Deploy | [03-v-portfolio-deploy.md](03-v-portfolio-deploy.md) | [Pipeline-Operator](/QUA/agents/pipeline-operator) | Needs role-rename pass |
| 4 | Incident Response | [04-incident-response.md](04-incident-response.md) | [DevOps](/QUA/agents/devops) (interim until Obs-SRE Wave 3) | Needs role-rename pass |
| 5 | Dashboard Refresh Cadence | [05-dashboard-refresh.md](05-dashboard-refresh.md) | TBD (V5) | Needs full V5 rewrite — V4 mechanism (Strategy-Analyst routine + processes.html) is obsolete |
| 6 | Issue Triage | [06-issue-triage.md](06-issue-triage.md) | [CEO](/QUA/agents/ceo) | Needs role-rename pass |
| 7 | Cross-Strand CEO ↔ CTO Dialectic | [07-ceo-cto-dialectic.md](07-ceo-cto-dialectic.md) | [CEO](/QUA/agents/ceo) + [CTO](/QUA/agents/cto) | Needs role-rename pass |
| 8 | Daily Operating Rhythm | [08-daily-operating-rhythm.md](08-daily-operating-rhythm.md) | [Documentation-KM](/QUA/agents/documentation-km) | Needs full V5 rewrite — V4 13-agent rhythm is obsolete |
| 9 | Disaster Recovery | [09-disaster-recovery.md](09-disaster-recovery.md) | [DevOps](/QUA/agents/devops) | Needs role-rename pass |
| 10 | Agent Re-scope | [10-agent-rescope.md](10-agent-rescope.md) | [CEO](/QUA/agents/ceo) | Needs role-rename pass |
| 11 | Disk-Management and Drive-Sync-Maintenance | [11-disk-and-sync.md](11-disk-and-sync.md) | [DevOps](/QUA/agents/devops) (interim until Obs-SRE Wave 3) | Needs role-rename pass |
| 12 | Board Escalation Contract | [12-board-escalation.md](12-board-escalation.md) | [Documentation-KM](/QUA/agents/documentation-km) | Needs role-rename pass |
| 15 | Pipeline-Operator Load Balancing (T1-T5) | [15-pipeline-op-load-balancing.md](15-pipeline-op-load-balancing.md) | [Pipeline-Operator](/QUA/agents/pipeline-operator) | **V5-authored 2026-04-27** |

V5 audit detail: [`docs/ops/QUA-213_PROCESS_AUDIT_2026-04-27.md`](../docs/ops/QUA-213_PROCESS_AUDIT_2026-04-27.md). Files marked "needs full V5 rewrite" have child issues opened off QUA-213; the role-rename pass is tracked as a single follow-up.

## Ownership & review cadence

[Documentation-KM](/QUA/agents/documentation-km) owns this folder. Review cadence: **quarterly**. Process maps decay fast — when any flow changes materially, the agent that owns the change must open an issue against Doc-KM to update the relevant spec before merging the behavioral change.

## How agents reference these docs

Agent prompts (in `paperclip-prompts/<role>.md`) and per-task instructions should **link** to the relevant process file, not duplicate steps. Example:

```markdown
## Escalation
When a deploy decision is needed, follow [Board Escalation](../processes/12-board-escalation.md) class 5.
```
