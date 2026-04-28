---
name: DL-027 — BASIS→active diff propagation rule
description: Every revision of a paperclip-prompts/<role>.md BASIS file must name a propagation path; Documentation-KM regenerates the matching diff side-artifact post-revision
type: decision-log
---

# DL-027 — BASIS→active diff propagation rule (+ Wave 1 catch-up)

> **Numbering note.** QUA-237 instructed "DL-027". When this entry was filed, DL-027 was already registered to a separate concurrent decision (`DL-027_coding_agent_done_requires_commit_hash.md`, QUA-239). Per the registry's `max(existing) + 1` convention and the "skipped numbers are intentional gaps; do not reuse" rule, this entry took DL-027. No content change; only the slot number differs from the issue text.

Date: 2026-04-27
Authority basis: **CEO acting under [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md)** (internal process choice — class 4 of the broadened-authority list).
Originating learning-candidate: [QUA-235](/QUA/issues/QUA-235)
Recording / authoring task: [QUA-237](/QUA/issues/QUA-237)
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`)
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
Status: Active.

> **Recorder's note (Doc-KM scope per BASIS).** This file operationalizes the rule already articulated in `lessons-learned/2026-04-27_prompt_basis_activation_diff.md` § 4 ("Going-forward rule"). DL-027 records the rule with an explicit authority basis and registry slot so future BASIS revisions can cite it. No edits to BASIS or live AGENTS.md content are made by this DL — capture-only.

## Decision

The two-layer hire model (DL-014) makes BASIS in `paperclip-prompts/<role>.md` the OWNER-managed input to hire, and the live `instructions/AGENTS.md` the served running prompt. Without an explicit propagation rule, BASIS edits look authoritative but may not propagate to the running agent.

DL-027 establishes:

1. **Propagation path declaration.** Every revision of `paperclip-prompts/<role>.md` (BASIS) MUST name a propagation path in the DL entry that authorizes the change. The author picks one of:

   | Path | Meaning |
   |---|---|
   | `hot_reload` | Paperclip re-reads the BASIS file at next heartbeat; no re-hire needed. |
   | `re_hire` | Agent must be re-hired for the new BASIS to land in `instructions/AGENTS.md`. |
   | `config_patch` | `instructions/AGENTS.md` is hand-patched to match BASIS. |
   | `reference_only` | BASIS is now reference; live is already adjusted, no propagation needed. |

   No revision lands without one of those four labels in the authorizing DL entry.

2. **Diff side-artifact regeneration.** After the change is propagated, **Documentation-KM** regenerates `paperclip-prompts/diffs/<role>_basis_to_active.diff` and commits it. The commit message references the authorizing DL (e.g. `docs: regenerate <role> basis-active diff (DL-NNN)`).

3. **Verification gate.** If the regenerated diff doesn't show the expected change, the propagation path is broken. The authorizing DL is then re-opened or flagged on the recording issue.

The rule does NOT require BASIS and live to match — the two-layer design *expects* divergence (operating contract appended at activation, plus role-specific adaptations). The rule is about **knowing** the differences, not eliminating them.

## Why

Lifted directly from `lessons-learned/2026-04-27_prompt_basis_activation_diff.md` (QUA-189). The lesson identified the silent-drift risk; this DL closes the loop by making the rule enforceable: every BASIS revision is traceable to a DL that names how (and whether) the change reaches the running agent, plus a refreshed diff artifact that shows what actually landed.

CEO authority basis: DL-023 § "Class 4 — internal process choices that don't change V5 hard rules". Choosing how Documentation-KM captures BASIS-active drift is an internal process decision; CEO is acting unilaterally under that broadened authority.

## What changed (Wave 1 catch-up)

Diff side-artifacts captured under QUA-237 for the two Wave 1 hires that were already online when DL-027 was filed:

| Role | Agent ID (live) | Diff artifact |
|---|---|---|
| DevOps | `0e8f04e5-4019-45b0-951f-ca248cf82849` | [`paperclip-prompts/diffs/devops_basis_to_active.diff`](../paperclip-prompts/diffs/devops_basis_to_active.diff) |
| Pipeline-Operator | `46fc11e5-7fc2-43f4-9a34-bde29e5dee3b` | [`paperclip-prompts/diffs/pipeline-operator_basis_to_active.diff`](../paperclip-prompts/diffs/pipeline-operator_basis_to_active.diff) |

Notes from the catch-up capture:

- **DevOps duplicate.** Two agent directories exist on disk: `0e8f04e5...` and `12c5c03f-12d6-4593-bb5d-bfa3bc951602`. Only `0e8f04e5...` is returned by `GET /api/companies/{id}/agents` as the active DevOps agent; the other is a legacy duplicate. The diff was captured against the active one. Cleanup of the duplicate is out of scope for QUA-237 and tracked elsewhere.
- **Pipeline-Operator hire-time anomaly.** The live `instructions/AGENTS.md` for `46fc11e5...` is byte-identical to the entire `paperclip-prompts/pipeline-operator.md` BASIS file — including the metadata header, the literal `\`\`\`text` fence markers, the V1→V5 Changes table, and the First Issues on Spawn list. No Paperclip operating contract was appended at activation. This is documented in the diff side-artifact. DL-027 is capture-only and does not fix this; OWNER + CEO can decide whether to re-hire (`re_hire`) or hand-patch (`config_patch`) under a follow-up DL.

## Implications

- **CTO (technical-role BASIS edits).** When CTO revises a `paperclip-prompts/*.md` BASIS for a technical role (CTO, DevOps, Development, R-and-D, Quality-Tech, Pipeline-Operator), the authorizing DL names the propagation path. Documentation-KM regenerates the diff post-propagation.
- **CEO + OWNER (non-technical-role BASIS edits).** Same rule for non-technical roles (CEO, Documentation-KM, Quality-Business, Controlling, Observability-SRE, LiveOps, Research).
- **Documentation-KM scope is unchanged.** Doc-KM does not edit BASIS or live AGENTS.md content (CTO/CEO/OWNER territory per BASIS). Doc-KM owns the *diff artifact* and the loop's recording, not the prompt's content.
- **Wave 2+ hires.** When a new role is hired, the activation diff is captured at hire-time as the role's first `paperclip-prompts/diffs/<role>_basis_to_active.diff`. Same rule applies thereafter.

## Sources

- [`lessons-learned/2026-04-27_prompt_basis_activation_diff.md`](../lessons-learned/2026-04-27_prompt_basis_activation_diff.md) — full reasoning, captured Wave 0 diffs, going-forward rule (§ 4).
- [DL-014](./REGISTRY.md) — two-layer hire pattern (Paperclip system prompt + V5 first-issue brief). Documented in `lessons-learned/2026-04-26_paperclip_wave0_bootstrap.md`.
- [QUA-235](/QUA/issues/QUA-235) — originating learning-candidate flagged the rule for promotion to a DL entry.
- [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) — CEO autonomy waiver, broadened scope; provides the authority basis under class 4 (internal process choices).

## Cross-links

- **QUA-235 ↔ DL-027.** Forward link: QUA-235 → DL-027 (recorded via QUA-237). Reverse link: this file cites QUA-235 as the originating learning-candidate.
- **QUA-237 ↔ DL-027.** Forward link: QUA-237 → DL-027 (this file). Reverse link: QUA-237 closeout comment references this file's commit SHA plus the two Wave 1 diff commit SHAs.
- **DL-014 ↔ DL-027.** DL-027 operationalizes the propagation question that DL-014's two-layer model raised but did not answer.
- **DL-023 ↔ DL-027.** DL-023 is the authority basis for CEO unilaterally adopting this internal process rule.
- **`lessons-learned/2026-04-27_prompt_basis_activation_diff.md` ↔ DL-027.** The lesson is the *reasoning*; DL-027 is the *rule*. Future revisions of the rule update DL-027; the lesson stays as the historical record of why it was needed.
- **Registry:** [`decisions/REGISTRY.md`](./REGISTRY.md) — DL-027 row.

— CEO under DL-023, recorded by Documentation-KM 2026-04-27.
