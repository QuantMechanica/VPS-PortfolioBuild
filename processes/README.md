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
| 3 | V-Portfolio Deploy | [03-v-portfolio-deploy.md](03-v-portfolio-deploy.md) | [Pipeline-Operator](/QUA/agents/pipeline-operator) | **V5 role-rename done 2026-04-29** (QUA-213 child — `/QUAA/` → `/QUA/`, Wave annotations) |
| 4 | Incident Response | [04-incident-response.md](04-incident-response.md) | [DevOps](/QUA/agents/devops) (interim until Obs-SRE Wave 3) | **V5 role-rename done 2026-04-29** (QUA-213 child — `/QUAA/` → `/QUA/`, Wave annotations) |
| 5 | Dashboard Refresh Cadence | [05-dashboard-refresh.md](05-dashboard-refresh.md) | [DevOps](/QUA/agents/devops) (export job + Netlify deploy); [Documentation-KM](/QUA/agents/documentation-km) (public copy + redaction); Controlling Wave 3 deferred (interim: CEO); Obs-SRE Wave 3 deferred (interim: DevOps) | **V5-authored 2026-04-29** (QUA-230 — CEO ack 2026-04-29 under DL-017/QUA-188; hourly Hetzner VPS export → public-data JSON → Netlify rebuild; V4 anchors retired: Strategy-Analyst routine `5d3aed1c`, `project_dashboard.html`, `processes.html`, `QM_ProcessesHtml_Build`) |
| 6 | Issue Triage | [06-issue-triage.md](06-issue-triage.md) | [CEO](/QUA/agents/ceo) | **V5 role-rename done 2026-04-29** (QUA-213 child — `/QUAA/` → `/QUA/`, Strategy-Analyst V4-folded, project-routing note added per DL-031) |
| 7 | Cross-Strand CEO ↔ CTO Dialectic | [07-ceo-cto-dialectic.md](07-ceo-cto-dialectic.md) | [CEO](/QUA/agents/ceo) + [CTO](/QUA/agents/cto) | **V5 role-rename done 2026-04-29** (QUA-213 child — `/QUAA/` → `/QUA/`, V4 issue refs marked historical) |
| 8 | Daily Operating Rhythm | [08-daily-operating-rhythm.md](08-daily-operating-rhythm.md) | [Documentation-KM](/QUA/agents/documentation-km) | **V5-authored 2026-04-29** (QUA-231 — CEO ack 2026-04-29 via accepted `confirmation:QUA-231:rewrite:29521e49`; 9-agent rhythm table, event-driven default + timer-cadence exception, Wave 3/4/5 deferred placeholders, anti-loop rule per DL-042 / 17-agent-runtime-health.md) |
| 9 | Disaster Recovery | [09-disaster-recovery.md](09-disaster-recovery.md) | [DevOps](/QUA/agents/devops) | **V5 role-rename done 2026-04-29** (QUA-213 child — `/QUAA/` → `/QUA/`, Obs-SRE Wave 3 annotation) |
| 10 | Agent Re-scope | [10-agent-rescope.md](10-agent-rescope.md) | [CEO](/QUA/agents/ceo) | **V5 role-rename done 2026-04-29** (QUA-213 child — `/QUAA/` → `/QUA/`, V4 prompt path flagged obsolete, LiveOps Wave 4) |
| 11 | Disk-Management and Drive-Sync-Maintenance | [11-disk-and-sync.md](11-disk-and-sync.md) | [DevOps](/QUA/agents/devops) (interim until Obs-SRE Wave 3) | **V5 role-rename done 2026-04-29** (QUA-213 child — `/QUAA/` → `/QUA/`, Obs-SRE Wave 3 annotation) |
| 12 | Board Escalation Contract | [12-board-escalation.md](12-board-escalation.md) | [Documentation-KM](/QUA/agents/documentation-km) | **V5 role-rename done 2026-04-29** (QUA-213 child — `/QUAA/` → `/QUA/`, LiveOps Wave 4, class 4 prose unchanged pending 02-zt-recovery rewrite) |
| 13 | Strategy Research Workflow | [13-strategy-research.md](13-strategy-research.md) | [Documentation-KM](/QUA/agents/documentation-km) | **V5-authored 2026-04-27** (QUA-242 — codifies OWNER directive on source/strategy/version tree) |
| 14 | EA Enhancement Loop (`_v2` versioning) | [14-ea-enhancement-loop.md](14-ea-enhancement-loop.md) | [Documentation-KM](/QUA/agents/documentation-km) | **V5-authored 2026-04-27** (QUA-245 — closed trigger list, fresh P1→P8 on `_v<n>`, single canonical card) |
| 15 | Pipeline-Op Load Balancing (T1-T5) | [15-pipeline-op-load-balancing.md](15-pipeline-op-load-balancing.md) | [Pipeline-Operator](/QUA/agents/pipeline-operator) | **V5-authored 2026-04-27** (QUA-246 — least-loaded round-robin + symbol-affinity, `(ea_id, version, symbol, phase, sub_gate_config)` de-dup registry, queue mechanics, post-restart gate); **2026-04-28 P0 update** (QUA-307 — 3-cap concurrency added) |
| 16 | Backtest Execution Discipline (DL-038 seven rules) | [16-backtest-execution-discipline.md](16-backtest-execution-discipline.md) | [Pipeline-Operator](/QUA/agents/pipeline-operator) (Rules 1-4, 7) + [DevOps](/QUA/agents/devops) (Rule 5 + Rule 7 generator) + [Research](/QUA/agents/research) (Rule 6) + [CTO](/QUA/agents/cto) (Rule 5 review-pass) | **V5-authored 2026-04-28** (QUA-418 / QUA-426 — codifies OWNER 2026-04-28 ~11:15 directive: `.DWX`-only, 36-symbol matrix, T1-T5 parallel, fail-fast-next, EA on all 5 terminals, Drive Tier 1.5 concept resource, RISK_FIXED set-file mandatory) |
| 17 | Agent Runtime Health | [17-agent-runtime-health.md](17-agent-runtime-health.md) | [CEO](/QUA/agents/ceo) (detection + first-line) + [Documentation-KM](/QUA/agents/documentation-km) (post-incident codification) | **V5-authored 2026-04-29** (QUA-514 — five triggers: hot-poll loop, stuck Codex/Claude session, bottleneck agent, token-budget pressure, recursive self-wake; new Class 6 board-escalation; companion lesson `lessons-learned/2026-04-29_development_recursive_wake.md`) |
| 18 | Company Operating System (lessons → process loop) | [18-company-operating-system.md](18-company-operating-system.md) | Chief of Staff (deferred — interim [CEO](/QUA/agents/ceo)) + [Documentation-KM](/QUA/agents/documentation-km) (closure-rule sentinel) | **V5-authored 2026-05-01** (QUA-595 / QUA-588 F5b — codifies the four-step lessons-to-process loop, hiring gate, token-control routing, dashboard-data contract; binding closure rule: no lesson `done` until ≥1 process / checklist / prompt-proposal change OR explicit no-change DL/comment; ratifying source `docs/ops/PAPERCLIP_COMPANY_REBOOT_PLAN_2026-04-30.md`) |

V5 audit detail: [`docs/ops/QUA-213_PROCESS_AUDIT_2026-04-27.md`](../docs/ops/QUA-213_PROCESS_AUDIT_2026-04-27.md). Files marked "needs full V5 rewrite" have child issues opened off QUA-213; the role-rename pass is tracked as a single follow-up.

## Ownership & review cadence

[Documentation-KM](/QUA/agents/documentation-km) owns this folder. Review cadence: **quarterly**. Process maps decay fast — when any flow changes materially, the agent that owns the change must open an issue against Doc-KM to update the relevant spec before merging the behavioral change.

## How agents reference these docs

Agent prompts (in `paperclip-prompts/<role>.md`) and per-task instructions should **link** to the relevant process file, not duplicate steps. Example:

```markdown
## Escalation
When a deploy decision is needed, follow [Board Escalation](../processes/12-board-escalation.md) class 5.
```
