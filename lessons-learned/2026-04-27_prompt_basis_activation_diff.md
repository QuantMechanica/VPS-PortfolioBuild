# Lessons Learned — Two-Layer Prompt Activation Diff (Wave 0 BASIS → live AGENTS.md)

**Date:** 2026-04-27
**Phase gate:** Phase 1 (Paperclip Bootstrap) — closing
**Author:** Documentation-KM (QUA-189)
**Reviewer:** CEO + Board Advisor
**Severity:** P3 (process-quality / drift-prevention; no production impact)
**Cross-references:** `paperclip-prompts/README.md` · `lessons-learned/2026-04-26_paperclip_wave0_bootstrap.md` (Lesson 3, DL-014) · `paperclip-prompts/diffs/cto_basis_to_active.diff` · `paperclip-prompts/diffs/research_basis_to_active.diff` · `paperclip-prompts/diffs/documentation-km_basis_to_active.diff`

---

## 1. Why this lesson exists

The Wave 0 hire model is **two-layer** per DL-014 and `paperclip-prompts/README.md`:

> "These prompts are the **V5 BASIS for Wave 0 hire**. … Paperclip *processes these prompts itself* — Wave 0 reviews, adapts, role-forms, then activates. This file is the input, not the final prompt; expect Wave 0 to make adjustments and document the diff."

That instruction was clear at hire-time. What it didn't specify was *who* captures the diff between BASIS and live, or *where* to file it. As a result, there was a real risk of **silent BASIS drift**: BASIS files in Git claim to be the OWNER-managed truth, while the live `instructions/AGENTS.md` files Paperclip serves to the agent on each heartbeat may have diverged for any of the three Wave 0 hires (CTO, Research, Documentation-KM) without a record.

This file closes that loop — captures the diff today, names the owner of the loop going forward, and sets the rule for future revisions.

---

## 2. The captured diffs (Wave 0)

Three Wave 0 roles activated 2026-04-27 from the BASIS files in `paperclip-prompts/`:

| Role | Agent ID | BASIS file | Live AGENTS.md | Side artifact |
|---|---|---|---|---|
| CTO | `241ccf3c-ab68-40d6-b8eb-e03917795878` | `paperclip-prompts/cto.md` | `agents/241c…/instructions/AGENTS.md` | `paperclip-prompts/diffs/cto_basis_to_active.diff` |
| Research | `7aef7a17-d010-4f6e-a198-4a8dc5deb40d` | `paperclip-prompts/research.md` | `agents/7aef…/instructions/AGENTS.md` | `paperclip-prompts/diffs/research_basis_to_active.diff` |
| Documentation-KM | `8c85f83f-db7e-4414-8b85-aa558987a13e` | `paperclip-prompts/documentation-km.md` | `agents/8c85…/instructions/AGENTS.md` | `paperclip-prompts/diffs/documentation-km_basis_to_active.diff` |

### Diff summary

**Research** and **Documentation-KM**: prompt body adopted **verbatim**. The only addition is the appended `## Paperclip operating contract (<Role>)` block (reporting line, heartbeat, execution contract, V5 BASIS source line, boundaries, done criteria, "always update your task" line).

**CTO**: prompt body has two real diffs in the `HARD RULES` section:

1. `HARD RULES (never negotiable):` → `HARD RULES CHECKLIST (never negotiable):` with each rule prefixed `- [ ]`. This is a deliberate behavioral nudge — converting prose rules into an inline checklist. It also matches the CTO's own First-Issue #2 ("Document current Hard Rules as inline checklist in prompt and as separate Git doc"), so the agent applied that to its own running prompt at hire time. Companion artifact landed at `decisions/DL-001_cto_prompt_hard_rules_checklist.md`.
2. Two em-dashes (`—`) → hyphens (`-`) in two rule lines (likely encoding normalization at hire-time): "Darwinex MT5 native data only" line and "No fantasy numbers" line. Cosmetic, but documented for completeness — silent character substitutions are exactly the kind of drift this lesson is meant to catch.

Plus the same `## Paperclip operating contract (CTO)` appended block as the other two roles, with role-specific reporting/heartbeat/done-criteria fields.

The full unified diffs are in the side-artifact files listed in the table above.

### What is NOT in the live prompt

The BASIS files include three sections that **do not appear** in the live running prompt:

- The role metadata block at the top (Role / Adapter / Heartbeat / Reports to / Manages).
- The `## V1 → V5 Changes` table.
- The `## First Issues on Spawn` list.

These are correctly omitted — they are hire-time briefing material, not the running prompt. The First Issues become Paperclip issues on hire (e.g. Documentation-KM's QUA-150/151/152). The V1→V5 Changes table is referential history. The metadata is consumed by Paperclip's hire flow, not the running agent.

---

## 3. Format — Learning → V1 Behavior → V5 Behavior → Why

| Aspect | V1 Behavior | V5 Behavior | Why |
|---|---|---|---|
| Source of running prompt | Single layer — whatever Notion/repo source the agent was hired from is the running prompt. | Two-layer — BASIS file in `paperclip-prompts/` (OWNER-managed, Git-canonical) + Paperclip operating contract appended at activation; live `instructions/AGENTS.md` is the served prompt. | Per DL-014 + `paperclip-prompts/README.md`: BASIS is the *input* to hire, not the final prompt. The Paperclip operating contract (heartbeat, API patterns, child-issue semantics) is what makes the prompt actually executable in the runtime — it can't be in BASIS because BASIS pre-dates the runtime config. |
| Drift detection | Drift between BASIS and live could go undetected indefinitely. | Diff captured at activation and committed under `paperclip-prompts/diffs/<role>_basis_to_active.diff`. Future revisions repeat the capture. | A claim that "BASIS is the source of truth" is hollow without an audit mechanism. Today's diff is the audit. |
| Owner of the diff loop | Implicit / undefined. | Documentation-KM owns capture and Git-commit of the diff artifact when a Wave 0 BASIS file or a live AGENTS.md changes. CTO owns the *content* of any prompt change for technical roles; CEO + OWNER own the *content* of any prompt change for non-technical roles; Documentation-KM does not edit either. | Boundary: Doc-KM "does NOT edit agent system prompts (those are CTO territory)". But capturing the diff between Git-canonical and live IS in Doc-KM's "Maintain the Learnings Archive" + "lessons-learned loop" remit. Capture ≠ edit. |
| Propagation path on revision | Implicit — assume Paperclip hot-reloads, or assume re-hire, or assume nothing. | Document the propagation path explicitly: when CTO/CEO revise a `paperclip-prompts/*.md` file later, the DL entry that authorized the change MUST state whether activation requires (a) Paperclip hot-reload, (b) re-hire of the agent, (c) a config patch on `instructions/AGENTS.md`, or (d) no action because BASIS is reference-only and live is already adjusted. | Without this, BASIS edits look like they "do something" when in fact they may not propagate at all to the running agent. The V4 Codex doc/code-drift class (L-D-08) is the same shape: file-system writes that imply an activation event but don't deliver one. |
| Verification before claiming "BASIS is in effect" | None. | OWNER or CEO reviews the diff side-artifact before promoting the BASIS edit. If the diff doesn't show the expected change, the propagation path is broken. | Closes the loop: edit → propagate → diff → review. Without the diff step, the loop has no verification. |

---

## 4. Going-forward rule

**When a `paperclip-prompts/*.md` BASIS file is revised:**

1. The author of the revision (CTO for technical-role prompts, CEO + OWNER for non-technical-role prompts) names the propagation path in the DL entry that authorizes the change. Required choices:
   - `hot_reload` — Paperclip re-reads the file at next heartbeat; no re-hire needed.
   - `re_hire` — agent must be rehired for the new BASIS to land in `instructions/AGENTS.md`.
   - `config_patch` — `instructions/AGENTS.md` is hand-patched to match.
   - `reference_only` — BASIS is now reference; live is already adjusted, no propagation needed.

2. After the change is propagated, **Documentation-KM** updates the matching `paperclip-prompts/diffs/<role>_basis_to_active.diff` and commits it. The commit message references the DL entry that authorized the change.

3. If the diff doesn't show the expected change, the propagation path is broken. The DL entry is then re-opened or flagged.

This rule does not say agents *must* match BASIS. The two-layer design *expects* the live prompt to differ from BASIS by at least the Paperclip operating contract section, and may legitimately differ in other ways (e.g. CTO's checklist conversion). The rule is about **knowing** the differences, not eliminating them.

---

## 5. Open follow-ups

- [ ] **CTO + OWNER:** When the `done`-before-commit prompt patch (proposed in `lessons-learned/2026-04-27_codex_done_before_commit.md` § 4) lands in `paperclip-prompts/cto.md`, the diff artifact `paperclip-prompts/diffs/cto_basis_to_active.diff` must be regenerated by Documentation-KM and the DL entry must name the propagation path.
- [ ] **DevOps (future, optional):** Consider a Paperclip side hook that auto-emits the diff between `paperclip-prompts/<role>.md` (BASIS, fenced text block) and `agents/<id>/instructions/AGENTS.md` (live, above the first `---`) after every revision event. Until then, Documentation-KM does it on heartbeat.
- [ ] **Wave 1+ hires** (DevOps, Pipeline-Operator, Development, Quality-Tech, Quality-Business, Controlling, Observability-SRE, LiveOps, R-and-D): repeat the activation-diff capture once each is hired. Wave 1 (DevOps + Pipeline-Operator) is already online; capture for those two is a follow-up Doc-KM task.

---

## 6. Versioning

| Version | Date | Author | Notes |
|---|---|---|---|
| v1.0 | 2026-04-27 | Documentation-KM (QUA-189) | Initial entry. CEO + Board Advisor pending review. Three Wave 0 diff side artifacts shipped under `paperclip-prompts/diffs/`. |
