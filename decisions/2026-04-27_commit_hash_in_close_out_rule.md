---
name: DL-026 — Commit-Hash-In-Close-Out Rule
description: Coding-deliverable `done` requires the commit hash in the close-out comment; CEO `git status --porcelain` cross-check is the verification mechanism. Recorded under DL-023 broadened-authority waiver.
type: decision-log
---

# DL-026 — Commit-Hash-In-Close-Out Rule for Coding-Agent `done` Deliverables

Date: 2026-04-27
Issue: [QUA-234](/QUA/issues/QUA-234) (CEO ratification task)
Recording issue: [QUA-238](/QUA/issues/QUA-238) (this entry's authoring task)
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`)
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
Authority: [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) (CEO Autonomy Waiver, broadened scope) — class 4 "internal process choices → agent-vs-agent escalation rules".
Status: Active.

> **Recorder's note (Doc-KM scope per BASIS).** This file records a process rule CEO ratified on QUA-234 under the DL-023 broadened-autonomy waiver. Doc-KM is recording, not approving. The authoritative narrative remains in [QUA-234](/QUA/issues/QUA-234) and the originating lesson [`lessons-learned/2026-04-27_codex_done_before_commit.md`](../lessons-learned/2026-04-27_codex_done_before_commit.md) (commit `6e4c614`); if those and this file ever diverge, QUA-234 wins until a successor DL-NNN entry is filed.

## Decision

> **Any `done` status on a coding deliverable MUST include the commit hash in the close-out comment.**

Verbatim from CEO direction on [QUA-180](/QUA/issues/QUA-180), ratified on [QUA-234](/QUA/issues/QUA-234) under DL-023 authority.

## What changed

- **Process registry expectation.** A `done` close-out comment on any coding deliverable now requires a commit hash referencing the artifact landing on `main` (or the active working branch). A close-out comment that names only an on-disk path is not sufficient.
- **Verification mechanism.** CEO runs `git status --porcelain` before promoting any downstream gate or marking parent issues `done`. Untracked or modified files that should have been part of a `done` deliverable surface here and trigger a P0 fix-forward (the QUA-180 pattern). Until a Paperclip pre-`done` hook exists, this human-in-the-loop CEO check is the enforcement surface.
- **Granularity.** Per-step OR batched commits are both acceptable. The rule is about evidence, not granularity — what matters is that the commit hash appears in the close-out comment of every coding-deliverable issue marked `done`.

## Why

Three converging reasons:

1. **Hard Rule reinforcement — "no fantasy numbers."** The CTO Hard Rule list (in `paperclip-prompts/cto.md` and the CTO `AGENTS.md`) requires every claim to cite a report, log, or state entry. A filesystem path is not a commit. Anyone running `git log` on a `done` deliverable should see the artifact; without that, the `done` status is a fantasy number.

2. **PC1-00 Drive-sync recovery surface.** Until the worktree-isolation + index-lock-monitor mitigation landed (QUA-181 at 11:42 local on 2026-04-27), uncommitted artifacts had **zero recovery** if Drive sync re-engaged. The V4 mass-delete incident (`lessons-learned/2026-04-20_mass_delete_incident.md`) is the precedent: 9 of 13 system prompts and large parts of `.git/` were Drive-Trashed in 13 seconds. Belt-and-braces — PC1-00 mitigation handles the architectural risk, the commit-hash rule handles the discipline risk. Two independent failure modes need two independent guards.

3. **Recurrence of V4 L-D-08 pattern (Codex doc/code drift).** Steps 1..17 of the V5 framework Implementation Order were marked `done` with artifacts on disk but uncommitted (15+ files untracked at peak per the 2026-04-27 incident). The V4 L-D-08 lesson predicted this exact failure mode at every coding agent's first-day work. CEO's pre-promote `git status --porcelain` cross-check caught it before downstream gates promoted on a false assumption; codifying the rule prevents the next recurrence.

## Authority

Falls inside [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) § "Broadened CEO authority", class 4 — *internal process choices → agent-vs-agent escalation rules*. Verbatim from QUA-188:

> 4. **Internal process choices** — heartbeat cadence, issue-tree shape, sub-issue spawning patterns, agent-vs-agent escalation rules, parallel-run rules.

CEO acted unilaterally per the DL-023 decision rule ("err toward acting"). No OWNER surfacing required. This DL records the ratification.

## Scope

- **Applies to:** all coding-deliverable agents whose output is a repo-tracked artifact — CTO, Documentation-KM, Pipeline-Operator, Development, and any future hire (e.g. Quality-Tech, LiveOps) producing files under `framework/`, `infra/`, `decisions/`, `lessons-learned/`, `processes/`, `docs/`, `checklists/`, `paperclip-prompts/` (where editable per role boundaries), or any other tracked path.
- **Per-step OR batched commits both fine.** A 15-file batched commit is acceptable; the hash on each `done` issue is the evidence required.
- **Does not apply to:** non-coding deliverables (issue-thread analysis, comment-only handoffs, planning artifacts that stay in Paperclip thread state). For those, the existing close-out conventions are unchanged.

## Non-Goals

- **No new V5 hard rule.** This is process discipline reinforcing the existing "no fantasy numbers" Hard Rule, not an addition to `CLAUDE.md` § Hard Boundaries or `docs/ops/V5_HARD_RULES_CHECKLIST.md`.
- **No change to the `done` definition beyond evidence.** The CTO `AGENTS.md` § "Done criteria" already required "code merged + smoke green + commit + comment summary"; this rule clarifies that the commit hash must appear in the close-out comment as the evidence anchor.
- **Does not edit prompts.** Tightening the wording in `paperclip-prompts/*.md` is a separate task ([QUA-239](/QUA/issues/QUA-239)) routed to CTO with OWNER gate. Documentation-KM does not edit `paperclip-prompts/*.md` (boundary respected per BASIS).

## Reversal

If a Paperclip pre-`done` hook is later implemented (e.g. an agent-side script that calls `git rev-parse HEAD` and posts the hash automatically, or a server-side check that rejects a `done` transition without a hash reference in the close-out comment), the rule may relax to "hook enforces, agents need not manually cite". Until then, human-in-the-loop CEO verification stands. Record the reversal as a successor DL-NNN entry citing this one.

## Cross-links

- **Authority basis:** [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) — CEO Autonomy Waiver, broadened scope (class 4: internal process choices → agent-vs-agent escalation rules).
- **Predecessor:** [DL-017](./REGISTRY.md) (CEO hire-approval waiver) — narrower scope, not applicable here; both are subsets of DL-023.
- **Ratification task:** [QUA-234](/QUA/issues/QUA-234) — `[learning-candidate] done-before-commit Codex-class drift - ratify commit-hash-in-close-out rule`.
- **Recording task:** [QUA-238](/QUA/issues/QUA-238) — this DL entry's authoring task.
- **Original P0 fix:** [QUA-180](/QUA/issues/QUA-180) — `[P0] Commit ALL untracked framework + decisions files; ship per-step commit hashes` (where the rule was first stated).
- **Originating workstream:** [QUA-149](/QUA/issues/QUA-149) (V5 framework Implementation Order, 25 steps) and the per-step children QUA-153..QUA-167 (where the drift occurred).
- **Originating lesson:** [`lessons-learned/2026-04-27_codex_done_before_commit.md`](../lessons-learned/2026-04-27_codex_done_before_commit.md) (commit `6e4c614`).
- **CTO prompt-patch sibling task (OWNER-gated):** [QUA-239](/QUA/issues/QUA-239) — `[DL-026 prompt patch] Tighten coding-agent prompts to require commit-hash-in-close-out` (cancelled — OWNER preempted via commit `82b6be9`).
- **Prompt-patch deliverable record:** [`DL-026_coding_agent_done_requires_commit_hash.md`](./DL-026_coding_agent_done_requires_commit_hash.md) — stub recording the five BASIS prompts patched by OWNER (commit `82b6be9`) and the activation-propagation caveat.
- **Registry:** [`decisions/REGISTRY.md`](./REGISTRY.md) — DL-026 row.

## Boundary reminder

Process discipline reinforcing an existing Hard Rule. T6 still OFF LIMITS. Live deploy still surfaces to OWNER. Strategic direction still surfaces to OWNER. V5 hard rules unchanged. `paperclip-prompts/*.md` is OWNER-managed; the prompt-language patch is QUA-239's scope, not this DL's.

— CEO ratification under DL-023 broadened-autonomy waiver, 2026-04-27. Recorded by Documentation-KM 2026-04-27.
