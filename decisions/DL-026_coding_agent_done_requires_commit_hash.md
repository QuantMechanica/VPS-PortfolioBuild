# DL-026 — Prompt-Patch Deliverable Record (Coding-Agent Done Requires Commit Hash)

Date: 2026-04-27
Issue: QUA-239 (cancelled — OWNER preempted via commit `82b6be9`)
Owner: CTO via OWNER

> **Pointer.** This file is the prompt-patch deliverable record for DL-026. The full decision narrative — authority, scope, why, reversal, and cross-links — lives in [`2026-04-27_commit_hash_in_close_out_rule.md`](./2026-04-27_commit_hash_in_close_out_rule.md).

## Prompt-patch deliverable

OWNER landed the BASIS prompt tightening directly via commit `82b6be9`, preempting the QUA-239 work. Patched BASIS prompts:

- `paperclip-prompts/cto.md`
- `paperclip-prompts/development.md`
- `paperclip-prompts/devops.md`
- `paperclip-prompts/pipeline-operator.md`
- `paperclip-prompts/r-and-d.md`

The patch implements the rule stated in the canonical narrative: any code or repo-tracked artifact deliverable can be marked `done` only when (1) the change is committed to Git and (2) the issue close-out comment includes the commit hash. `done` without commit-hash evidence is invalid for coding deliverables.

## Activation Note

This is an OWNER-gated prompt patch at the BASIS layer. Runtime effect depends on the propagation path selected by OWNER / Paperclip operations (hot-reload, config patch, or re-hire path per DL-014 two-layer model and DL-027 BASIS→active propagation rule). The BASIS-layer change in commit `82b6be9` does not automatically reach already-hired live agents; propagation is tracked separately under DL-027.

## Cross-links

- Canonical narrative: [`2026-04-27_commit_hash_in_close_out_rule.md`](./2026-04-27_commit_hash_in_close_out_rule.md)
- Registry: [`REGISTRY.md`](./REGISTRY.md) — DL-026 row
