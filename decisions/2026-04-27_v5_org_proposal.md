# V5 First Org Proposal

**Date:** 2026-04-27
**Author:** CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`)
**Source issue:** QUA-144 — Wave 0 completion hire batch (Phase 1 close)
**Closes:** PROJECT_BACKLOG PC1-06 ("First org-design issue") + Phase 1 acceptance gate condition #2 ("CEO has produced first org proposal")
**Anchor docs:** `docs/ops/ORG_SELF_DESIGN_MODEL.md`, `docs/ops/PAPERCLIP_V2_BOOTSTRAP.md`, `paperclip-prompts/README.md`

---

## TL;DR

Current org is intentionally lean: **Wave 0 (CEO, CTO, Research, Documentation-KM) + Wave 1 (DevOps, Pipeline-Operator) live; everyone else deferred.** I am not proposing any new hires this week. The next hire is **Quality-Tech (Codex)**, gated on (a) PC1-00 Drive-sync `.git/` mitigation landing AND (b) at least V5 framework Implementation Order steps 1–5 (`QM_*.mqh` includes + magic registry) committed and compiling. Until then, every additional agent multiplies the mass-delete blast radius without producing reviewable EA artifacts to justify the Quality-Tech heartbeat cost.

---

## 1. Current state (honest snapshot, 2026-04-27 ~11:25Z)

| Wave | Role | Agent ID | Status | Adapter | Hired |
|---|---|---|---|---|---|
| 0 | CEO | `7795b4b0-...` | running | claude_local | 2026-04-26 |
| 0 | CTO | `241ccf3c-...` | idle | codex_local | 2026-04-27 |
| 0 | Research | `7aef7a17-...` | idle | claude_local | 2026-04-27 |
| 0 | Documentation-KM | `8c85f83f-...` | idle | claude_local | 2026-04-27 |
| 1 | DevOps | `0e8f04e5-...` | running | codex_local | 2026-04-26 |
| 1 | Pipeline-Operator | `46fc11e5-...` | idle | codex_local | 2026-04-26 |

That is **6 agents live**. The 13-role catalogue in `paperclip-prompts/` lists 7 more (Development, Quality-Tech, Quality-Business, Controlling, Observability-SRE, LiveOps, R-and-D) plus Chief of Staff (Wave 6, explicitly deferred per `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md`).

Wave 0 producing real heartbeats was proven this morning: in the ~20 min between hire and now, CTO landed `decisions/DL-001_v5_framework_review.md` + `DL-002_pipeline_infra_audit.md` + Hard Rules canonical doc + EA-vs-Card review template + 25 child issues for the Implementation Order; Documentation-KM landed Notion+Git creds verification + EP01 show-notes draft. The runtime works.

## 2. Hiring policy this week

**No new hires this week.** Three reasons:

1. **PC1-00 Drive-sync `.git/` mass-delete risk** is still open per `lessons-learned/2026-04-20_mass_delete_incident.md` and `PROJECT_BACKLOG.md` Open Item CRITICAL #1. Every additional agent that writes to `C:\QM\repo\.git\` increases blast radius if Drive-sync re-engages. Hold to the minimum viable count until the mitigation lands (per-repo git mutex + stale-`index.lock` monitor + agent CWD isolation via worktrees).
2. **No EAs exist yet.** Quality-Tech reviews EA code; Development writes EA code; Quality-Business reviews portfolio fit. None of these have inputs until V5 framework Implementation Order steps 1–5 (`QM_Errors`, `QM_Time`, `QM_Magic`, `QM_NewsFilter`, `QM_KillSwitch` includes + the magic registry) land. Hiring before that produces idle agents burning heartbeat cost.
3. **CEO + CTO + Pipeline-Op + DevOps already cover the urgent surface.** CTO owns the framework build; Pipeline-Op owns the smoke harness once it exists; DevOps owns infra; CEO does ops + gating. No work item today is actually blocked on a missing role — every workstream blocker is upstream-spec or upstream-code, not capacity.

**This means PC1-00 is the next priority.** If DevOps does not have an open issue for the per-repo git mutex + stale-lock monitor, I will open one.

## 3. Capability-routing decisions (per `ORG_SELF_DESIGN_MODEL.md`)

Confirmed for V5, no deviations from the working assumption in `ORG_SELF_DESIGN_MODEL.md` § Capability-Based Routing:

- Code / repo edits / MQL5 review / automation: **Codex** (CTO, DevOps, Pipeline-Operator already on `gpt-5.3-codex`).
- Source mining / Strategy Card extraction / long-form synthesis: **Claude Opus 4.7** (Research already on this; Documentation-KM same).
- Strategic gates / business reasoning / portfolio narrative: **Claude Opus 4.7** (CEO; Quality-Business when hired).
- Quality-Tech review (code + stats): **Codex primary**, with Claude on the report-reasoning subset only if a clear case appears in practice.

**Heartbeat cadence policy:** event-driven by default. Timer heartbeats only when the role does scheduled recurring work (DevOps hourly cron, Documentation-KM 2h Notion sync, CTO 1h review queue). Wake-on-demand only for Research (event-driven per BASIS) and CEO (board/issue events).

## 4. Wave plan

### Wave 0 — DONE
CEO, CTO, Research, Documentation-KM. All live as of today.

### Wave 1 — DONE (legacy)
DevOps, Pipeline-Operator. Both pre-existed today's batch and are running.

### Wave 2 — Quality-Tech, then Development, then Quality-Business
Trigger conditions (ALL must hold):
1. PC1-00 mitigation merged and verified.
2. CTO Implementation Order steps 1–5 committed (`framework/include/QM_*.mqh` + `framework/registry/ea_id_registry.csv` template).
3. At least one approved Strategy Card from Research (gated on OWNER seed-source confirmation `194a59ce-...`).

Hire order inside Wave 2:
1. **Quality-Tech (Codex)** first — the EA review path needs a second reviewer beyond CTO before any EA goes to smoke. CTO is the spec author; Quality-Tech is the independent code-review gate.
2. **Development (Codex)** second — only when the framework includes exist for them to fill in `EA_Skeleton.mq5`.
3. **Quality-Business (Claude Opus)** third — gated on first PASS-eligible EA producing reports for portfolio-fit review.

### Wave 3 — Controlling, Observability-SRE
Trigger: ≥3 EAs in P10 burn-in OR live trading begins on T6 (whichever first). Until then, DevOps' monitoring scripts + CEO's gate decisions cover what these roles formalize.

### Wave 4 — LiveOps
Trigger: T6 Live/Demo automation runbook (`docs/ops/LIVE_T6_AUTOMATION_RUNBOOK.md`) operational and DXZ funded account active. Hard rule: T6 OFF LIMITS to factory automation until LiveOps is hired AND OWNER explicit-approves the runbook.

### Wave 5 — R-and-D
Trigger: Pipeline producing ≥10 PASS-eligible EAs/month, demonstrating the throughput justifies dedicated R&D heartbeat cost. Until then CTO's "deep-research pre-check via Research" pattern (per `paperclip-prompts/cto.md`) covers the same surface.

### Wave 6 — Chief of Staff
**Deferred indefinitely** per `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md`. Re-open only if OWNER → CEO bandwidth becomes the constraint.

## 5. Hiring-gate checklist (per `ORG_SELF_DESIGN_MODEL.md` § Hiring Gate)

Every Wave 2+ hire requires CEO to answer:

1. What recurring work justifies this role? (concrete: list of issues currently in queue or projected within 7 days)
2. Which current agent should not own this and why? (capability gap, not just capacity)
3. What is the write authority? (paths, repos, external systems)
4. What is the heartbeat cadence or on-demand trigger? (default: event-driven)
5. What outputs prove the role is useful? (artifact + cadence)
6. What condition retires or pauses the role?

CEO will not file a new `agent-hires` POST without writing those six answers in the hire request comment.

## 6. Quality / anti-sprawl rules

- **Maximum 8 active agents until Phase 2 framework is fully implemented (Implementation Order step 25).** That is Wave 0 (4) + Wave 1 (2) + 2 Wave 2 hires. Any 9th hire requires explicit OWNER approval.
- **No agent without a named recurring deliverable.** "Just in case" agents get paused.
- **Quarterly org effectiveness review** per `ORG_SELF_DESIGN_MODEL.md` § Org Design Cadence — first review 2026-07-27.
- **Any incident triggers an ownership-boundary review** per same § — was the failure caused or prevented by the org chart?

## 7. Process ownership matrix (initial draft)

| Process | Owner | Reviewer | Cadence |
|---|---|---|---|
| Hire approval | CEO | OWNER | per-event |
| Strategy Card extraction | Research | CEO + Quality-Business (when hired) | per-source |
| EA spec | CTO | Research (deep-research pre-check) | per-card |
| EA code review | CTO | Quality-Tech (when hired) | pre-smoke |
| Smoke harness execution | Pipeline-Operator | CTO | per-EA |
| Pipeline phase gates G0..P10 | CEO | CTO + Quality-Business | per-EA per-phase |
| Notion ↔ Git sync | Documentation-KM | DevOps (cron health) | nightly 23:00 UTC |
| Episode publishing | Documentation-KM | OWNER | per-episode |
| Infra reproducibility | DevOps | CTO | per-change |
| Public dashboard export | DevOps + Controlling (when hired) | CEO | hourly |
| Lessons archive | Documentation-KM | CEO | per-lesson |

This matrix supersedes any older "everyone owns everything" implicit model. Rows expand as Wave 2+ hires land.

## 8. What this proposal does NOT decide (out of scope)

- Research source ordering — separate OWNER confirmation `194a59ce-...` on QUA-144.
- V5 framework implementation order — owned by CTO per QUA-149.
- Phase 2 GO/NO-GO operational caveat — CTO already issued (GO for entry, NO-GO for production-pipeline execution until steps 20–24).
- DevOps PC1-00 mitigation design — owned by DevOps; CEO will open the issue if it does not exist.
- Adapter-level cost/budget review — separate Controlling task once that role lands.

## 9. Ratification

This proposal is the CEO's working organizational baseline as of today. Changes happen by CEO comment on a successor decision file (`decisions/YYYY-MM-DD_v5_org_*.md`) — do not edit this file in place.

OWNER may override any provision via comment on QUA-144 or a successor directive issue.

---

**Phase 1 acceptance gate condition #2 closes with this commit.**
