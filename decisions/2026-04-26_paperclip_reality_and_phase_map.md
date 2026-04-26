# Decision: Paperclip reality check + 7-phase project map

- Date: 2026-04-26
- Status: accepted
- Owner: OWNER + Claude Board Advisor
- Affected docs: `PROJECT_BACKLOG.md` (new), `CLAUDE.md` (pointer added), `docs/ops/PHASE0_EXECUTION_BOARD.md` (today's-owner annotation)

## Context

Across the last days of repo work the documentation has accumulated owner assignments like `Owner: CTO + Development`, `Owner: CEO + Pipeline-Operator`, `Owner: Quality-Tech`. These reflect the planned organisation per `docs/ops/ORG_SELF_DESIGN_MODEL.md` and `docs/ops/PAPERCLIP_V2_BOOTSTRAP.md` — Paperclip's Wave 0 four agents (CEO-Claude, CTO-Codex, Research-Claude, Documentation-KM-Claude), with later waves adding DevOps, Pipeline-Operator, Development, Quality-Tech, Quality-Business, Controlling, Observability-SRE, LiveOps, R-and-D.

OWNER raised on 2026-04-26 the obvious-but-unwritten point: **Paperclip is not installed yet**. The only active actors on the VPS are OWNER and Claude Board Advisor (this instance). Codex on the laptop is a read-only research helper, not a deployable agent. Every workstream item assigned to a Paperclip role is therefore aspirational until Phase 1 (Paperclip Bootstrap) closes.

This is a real planning gap: a backlog that says "CTO implements P0-26" reads like the work is queued, when in fact the work is blocked on hiring CTO.

## Decision

1. **Adopt a single project backlog file**: `PROJECT_BACKLOG.md` at repo root. It enumerates every workstream across all phases, with two owner fields: the planned long-term owner (per ORG_SELF_DESIGN_MODEL) and **today's actual owner** (OWNER, Board Advisor Claude, laptop Codex, or "blocked on Phase X").

2. **Adopt a 7-phase project map** as the canonical sequence:

   ```
   Phase 0 — VPS Foundation + Specs                  ← we are here
   Phase 1 — Paperclip Bootstrap (install + Wave 0)
   Phase 2 — V5 Framework Implementation
   Phase 3 — First V5 EA Through Pipeline
   Phase 4 — V5 Portfolio Build
   Phase 5 — Live Deployment on T6
   Phase 6 — Public Dashboard Live (parallel-eligible from Phase 1)
   Phase Final — Founder-Comms / Chief of Staff (deferred per existing ADR)
   ```

   Phases 0–5 are sequential. Phase 6 is parallel-eligible from Phase 1. Phase Final is gated by OWNER's explicit go-signal AND the trigger conditions listed in `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md`.

3. **Honest "today's owner" labelling**: where a Paperclip role is named as owner but Paperclip is not yet running, the today's-owner is either OWNER + Board Advisor (manual interim, where workable) or "blocked on Phase 1" (where it genuinely needs a Paperclip agent). No more pretending the agent exists.

4. **CLAUDE.md pointer** added so future Claude sessions (and OWNER) can find the backlog quickly. `PROJECT_BACKLOG.md` is added to the Required Local Docs list.

5. **Phase Final = Founder-Comms** confirmed as the explicit final phase. Existing `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md` is canonical and frozen until OWNER says "now build founder-comms".

6. **Specification Density Principle**: pre-specify the outer boundary (phases, acceptance gates, hard constraints) but leave interior detail (issue decomposition, sub-process design, routine cadences beyond hard rules, EA content, org evolution) to Paperclip Wave 0+ to work out themselves under the constraints. CLAUDE.md and `PROJECT_BACKLOG.md` both carry this principle. Over-specification trains the agents to be passive; under-specification leaves them with no constraints. Bound the box, not the moves inside it.

## Alternatives Considered

- **Keep using per-doc workstream lists; do not introduce a backlog.** Rejected. The per-doc lists are good local references but lose the cross-phase view. OWNER cannot answer "what can we do today?" without grepping across five docs.
- **Re-assign every Paperclip-owned task to Board Advisor + OWNER as the today's-owner.** Partially rejected. Some tasks (e.g. MQL5 framework implementation) Board Advisor *can* technically do, but doing so short-circuits the agent-routing per `ORG_SELF_DESIGN_MODEL.md` and trains a habit of bypassing the org. Today's-owner labels say "blocked on Phase 1" for these — OWNER may override case-by-case.
- **Collapse Phase 1 (Paperclip Bootstrap) into Phase 0.** Rejected. Phase 0 is "VPS Foundation + Specs" — a docs-and-infra phase. Paperclip is a software install with its own acceptance criteria. Mixing them obscures where Phase 0 actually closes.
- **Move Phase 6 (Public Dashboard) to Phase Final-1.** Rejected. The dashboard schema and skeleton can run in parallel from Phase 1 (Board Advisor work today). Pinning it as a late phase delays a parallelisable workstream.

## Consequences

- `PROJECT_BACKLOG.md` becomes the single thing OWNER opens to answer "what's next, who owns it, what's blocked?".
- The Phase 0 board (`docs/ops/PHASE0_EXECUTION_BOARD.md`) gets a today's-owner annotation pass so its rows reconcile with the backlog.
- CLAUDE.md is updated so future Claude sessions read the backlog before re-asking "where are we?".
- The handful of tasks Board Advisor + OWNER *can* progress today without Paperclip become explicitly visible (DST validation, T6 isolation, calibration JSON, public snapshot schema, EP01, Paperclip install plan).
- Founder-Comms stays exactly where it was — frozen and last.

## Sources

- OWNER conversation 2026-04-26 (Board Advisor session)
- `docs/ops/PAPERCLIP_V2_BOOTSTRAP.md` (Wave 0–5 hiring plan)
- `docs/ops/ORG_SELF_DESIGN_MODEL.md` (capability routing)
- `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md` (Phase Final scope, frozen)
- `docs/ops/PHASE0_EXECUTION_BOARD.md` (Phase 0 detail)
- `framework/V5_FRAMEWORK_DESIGN.md` (Phase 2 implementation order)
- `docs/ops/PIPELINE_PHASE_SPEC.md` and `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` (Phase 3 gates)
- `docs/ops/LIVE_T6_AUTOMATION_RUNBOOK.md` (Phase 5 deploy manifests)
- `docs/ops/WEBSITE_DASHBOARD_PAPERCLIP_STYLE.md` (Phase 6 dashboard)
