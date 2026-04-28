---
name: DL-032 — CEO Autonomy Waiver, Research Source-Queue Ordering (v3)
description: Third extension of the CEO autonomy waiver; research source-queue ordering, source-survey ratification, SRC0N parent creation, and per-batch T3 source approval are now CEO-autonomous; pre-flight rule added for paperclip-prompts patches that align with an existing DL-NNN
type: decision-log
---

# DL-032 — CEO Autonomy Waiver, Research Source-Queue Ordering (v3)

Date: 2026-04-27
Issue: [QUA-188 comment 5caf4b97](https://paperclip.local/QUA/issues/QUA-188#comment-5caf4b97-a309-442c-ad4f-de84608eb06f) (OWNER directive 2026-04-27 ~19:55 local, relayed by Board Advisor)
Recording issue: [QUA-273](https://paperclip.local/QUA/issues/QUA-273) (this entry's authoring task)
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`)
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
Supersedes: none. **Additive to DL-017** (hire-approval waiver) and **DL-023** (technical / operational / process broadening, v2).
Status: Active.

> **Recorder's note (Doc-KM scope per BASIS).** This file is a faithful transcription of OWNER's v3 broadening as it landed in QUA-188 comment 5caf4b97 and as the CEO already mirrored verbatim into `paperclip-prompts/ceo` AGENTS.md (see [QUA-188 comment 56d8ba6a](https://paperclip.local/QUA/issues/QUA-188#comment-56d8ba6a-98de-4423-b007-c12943773e88)). Doc-KM is recording, not interpreting. The authoritative narrative remains in QUA-188; if QUA-188 and this file ever diverge, QUA-188 wins until a successor DL-NNN entry is filed.

## Decision

OWNER broadens CEO unilateral authority a third time. Four new classes — all in the research-resource lane — move out of OWNER scope into CEO scope. The escalation list is reframed (the prior "strategic direction" item is narrowed to "**true** strategic direction") and a pre-flight rule is added for prompt-patch work that aligns with an existing DL-NNN.

DL-017 (hires) and DL-023 v2 (technical / operational / process) remain in force. DL-032 is additive, not superseding.

## Why

OWNER directive 2026-04-27 ~19:55 local, relayed by Board Advisor on QUA-188. Source-queue ordering, source-survey ratification, opening the next SRC0N parent, and per-batch T3 source approval were the highest-frequency surfacing events in the research lane. None of them is "true" strategic direction (kill V5, change broker, change goal-tier outcome) — they are operational scheduling of an already-ratified research workflow (DL-029). The fix is the same pattern as DL-023 v2: bias to action, fewer interrupts, same retroactive-DL safety valve.

The pre-flight rule for `paperclip-prompts/*.md` is a direct response to a near-miss observed earlier in the same heartbeat where prompt-patch work risked being committed-then-surfaced rather than pre-aligned with its DL-NNN.

## Broadened CEO authority — v3 additions (no OWNER surfacing required)

The four classes below are **new** CEO-unilateral authority added by this DL. They sit alongside the four classes already CEO-autonomous under DL-017 + DL-023 v2:

1. **Research source-queue ordering** — which source Research extracts next within an already-ratified queue. (Davey vs Chan first, JBM batch 3 vs 4, etc.)
2. **Source-survey ratification** — accepting / rejecting / re-scoping a source-survey deliverable produced under DL-029.
3. **SRC0N parent creation** — opening the next `SRC0N` parent issue when the current one closes, including its child cohort skeleton.
4. **Per-batch T3 source approval** — approving the per-batch T3 source bundle that goes to Pipeline-Operator under DL-029's binding-sequential workflow.

These join the prior CEO-autonomous classes (verbatim from DL-023 v2):
- Hires (DL-017).
- Technical implementation choices within the framework spec.
- Operational decisions for non-T6 deploys.
- Internal process choices (heartbeat cadence, issue-tree shape, parallel-run rules, agent-vs-agent escalation).

## Still requires OWNER surfacing — reframed v3 list

The seven classes below remain OWNER-scope. The narrowing on item 3 ("**true** strategic direction") is the v3 change; everything else is unchanged from DL-023 v2 except for explicit listing of "brand application" and "V5 hard-rule changes" as standalone classes (already implicit in v2 but easier to read here):

1. **T6 anything** — OFF LIMITS without explicit OWNER approval (no code, no read, no inference). V5 hard rule.
2. **Live deploy** — first T6 deploy manifest, AutoTrading toggle, live-account credential touches, live capital exposure changes.
3. **True strategic direction** — kill V5 entirely, pivot to a different broker, change the goal-tier strategic outcome. Source-queue ordering is **not** strategic direction; that is now CEO's lane per § "Broadened CEO authority — v3 additions" above.
4. **Compliance / legal** — news-compliance variants (FTMO / 5ers / DXZ blackouts), broker-of-record changes, account-class transitions.
5. **Brand application** to public-facing artifacts that OWNER personally approves (logo, mascot, episode pack).
6. **Budget step-changes** — anything materially raising monthly token / compute spend beyond the existing operating envelope.
7. **V5 hard-rule boundary changes** — ML ban, Model 4, .DWX suffix, Friday Close default, magic-formula registry.

## Pre-flight rule for `paperclip-prompts/*.md` patches

When CEO (or any agent) is about to patch a prompt under `paperclip-prompts/*.md` and the patch aligns with an **existing** DL-NNN (e.g., copying broadened-authority text from DL-032 into `paperclip-prompts/ceo.md`), the workflow is:

- **Either** pre-flight a `request_confirmation` interaction to OWNER on the patch itself, **or**
- Treat the commit as DL-aligned routine work that CEO can ship under broadened authority, citing the DL-NNN in the commit body.

**Never** commit-then-ask-after. The "ask after" anti-pattern was the failure mode this rule prevents — once a `paperclip-prompts/*.md` file is committed, hot-reload propagates it to every wake of the affected agent, and a retroactive `request_confirmation` is no longer a confirmation but a notification. OWNER manages the BASIS source-of-truth; CEO ships aligned patches under DL authority or surfaces explicitly before committing.

This pre-flight rule applies only when a DL-NNN already exists. Brand-new prompt changes that are not yet covered by a DL stay in their existing surfacing path.

## Decision rule for ambiguous cases

Same as DL-023 v2: **err toward acting**. OWNER's stated preference is bias to action, fewer interrupts. CEO can retroactively raise to OWNER via a successor DL-NNN if the call needs ratification. The v3 narrowing of "strategic direction" to "**true** strategic direction" makes this rule easier to apply — most operational research-queue calls land squarely in the broadened lane.

## Scope

- **Applies to:** CEO agent decisions across the QuA company on the four new v3 classes (source-queue ordering, source-survey ratification, SRC0N parent creation, per-batch T3 source approval), plus the pre-flight rule on prompt-patch work.
- **Does not apply to:** other agents acting outside CEO direction; OWNER-scope classes listed above; hard rules in `CLAUDE.md` and `docs/ops/V5_HARD_RULES_CHECKLIST.md`; the V5 hard rule that **AutoTrading is OWNER-manual** (DL-025).

## Non-Goals

- No change to T6 isolation, live-deploy gating, or any V5 hard rule.
- No change to DL-029's binding-sequential research workflow — DL-032 only moves the *approval surface* for that workflow's per-batch decisions to CEO; the workflow itself (one-source-at-a-time, `_v2` lineage rule, V4 taxonomy reuse, T1-T5 load balancing) is unchanged.
- No change to Doc-KM publish discipline (no auto-publish; OWNER sign-off on episode artifacts remains).
- No change to the `paperclip-prompts/*.md` OWNER-managed boundary — DL-032 disciplines *when* CEO may patch (DL-aligned, never commit-then-ask), not *whether* OWNER owns the source-of-truth.

## Cross-links

- **Predecessors / scope ancestors:**
  - DL-017 — original hire-approval waiver (`requireBoardApprovalForNewAgents=false`).
  - DL-023 — broadened scope v2 (technical / operational / process classes). DL-032 is additive to both.
- **Source directive:** [QUA-188 comment 5caf4b97](https://paperclip.local/QUA/issues/QUA-188#comment-5caf4b97-a309-442c-ad4f-de84608eb06f) — OWNER's v3 broadening text.
- **CEO authoritative-phrasing mirror:** [QUA-188 comment 56d8ba6a](https://paperclip.local/QUA/issues/QUA-188#comment-56d8ba6a-98de-4423-b007-c12943773e88) — CEO already updated own AGENTS.md (broadened-authority list + reframed escalation list + prompt-patch pre-flight rule) this heartbeat.
- **Recording task:** [QUA-273](https://paperclip.local/QUA/issues/QUA-273) — this DL entry's authoring task.
- **Workflow it operationalises against:** DL-029 (Strategy Research Workflow) — DL-032's four new classes are the per-batch approval surfaces that DL-029 names.
- **Worktree-isolation reference:** DL-028 (per-agent worktree isolation standard) — the `fetch+rebase before allocating DL slot` discipline cited in QUA-273's deliverable spec.
- **Registry:** [`decisions/REGISTRY.md`](./REGISTRY.md) — DL-032 row.
- **Process doc:** [`processes/process_registry.md`](../processes/process_registry.md) § "CEO Authority Boundaries".

## Boundary reminder

T6 still OFF LIMITS. Live deploy still surfaces to OWNER. **True** strategic direction (kill V5, change broker, change goal-tier outcome) still surfaces to OWNER. Compliance, brand application to OWNER-personal artifacts, budget step-changes, and V5 hard-rule changes still surface to OWNER. Everything else — including the four new v3 research-resource classes — CEO acts.

— OWNER directive via Board Advisor, 2026-04-27 ~19:55 local. Recorded by Documentation-KM 2026-04-27.
