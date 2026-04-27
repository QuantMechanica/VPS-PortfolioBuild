# DL-023 — CEO Autonomy Waiver, Broadened Scope (v2)

Date: 2026-04-27
Issue: [QUA-188](https://paperclip.local/QUA/issues/QUA-188) (OWNER directive, relayed by Board Advisor)
Recording issue: [QUA-192](https://paperclip.local/QUA/issues/QUA-192) (this entry's authoring task)
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`)
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
Supersedes: none. **Additive to DL-017** (original hire-approval waiver, `requireBoardApprovalForNewAgents=false`, ratified 2026-04-27 morning, scope = hires only).
Status: Active.

> **Recorder's note (Doc-KM scope per BASIS).** This file is a faithful transcription of OWNER's broadened-scope directive as it was issued in QUA-188. Doc-KM is recording, not interpreting. The authoritative narrative remains in QUA-188; if QUA-188 and this file ever diverge, QUA-188 wins until a successor DL-NNN entry is filed.

## Decision

OWNER broadens CEO's unilateral authority. CEO may now act without surfacing to OWNER on the four classes listed in **§ Broadened CEO authority** below. The six classes listed in **§ Still requires OWNER surfacing** continue to require explicit OWNER approval. CEO defaults toward acting; if a call later needs ratification, CEO can retroactively raise via a successor DL-NNN.

DL-017 (hires-only waiver) remains in force as a subset of this broader policy.

## Why

OWNER directive 2026-04-27, ~12:00 local. Paperclip Phase 1 closed in 70 minutes after DL-017 removed the hire-approval bottleneck. OWNER observed the company was still bottlenecking on technical, operational, and bookkeeping decisions that don't need OWNER attention. The fix is "bias to action, fewer interrupts" rather than per-class case work.

## Broadened CEO authority (no OWNER surfacing required)

The four classes below are CEO-unilateral. Verbatim from QUA-188:

1. **Hires** — already waived under DL-017; no change.
2. **Technical implementation choices within the framework spec** — adapter choices, library structure, internal scripts, test harness shape, gitignore / artifact retention policy, Notion ↔ Git mirror layout, scheduler choice (Paperclip routine vs Windows Task), Linux / PowerShell tooling decisions.
3. **Operational decisions for non-T6 deploys** — file paths, scheduler windows, log rotation policy, retention windows, agent confirmation cadence, worktree layout, lock-file monitoring, bookkeeping cleanups (orphan-run cancellations, stuck-process terminations).
4. **Internal process choices** — heartbeat cadence, issue-tree shape, sub-issue spawning patterns, agent-vs-agent escalation rules, parallel-run rules.

## Still requires OWNER surfacing

The six classes below remain OWNER-scope. Verbatim from QUA-188:

1. **T6 anything.** OFF LIMITS without explicit OWNER approval per `CLAUDE.md` hard rule. No code, no read, no inference.
2. **Live deploy.** First T6 deploy manifest, AutoTrading toggle, live-account credential touches, live capital exposure changes.
3. **Strategic direction.** Source-queue ordering for Research, Strategy Card approval, EA inclusion in V5 portfolio, brand application choices that affect public-facing artifacts (logo, mascot, episode pack).
4. **Compliance / legal.** News-compliance variant decisions (FTMO / 5ers / DXZ blackout windows), broker-of-record changes, account-class transitions.
5. **Budget step-changes.** Anything that materially raises monthly token / compute spend beyond the company's existing operating envelope.
6. **Boundary modifications to V5 hard rules.** ML ban, Model 4, .DWX suffix, Friday Close default, magic-formula registry — these are framework-level and OWNER-scope.

## Decision rule for ambiguous cases

If CEO is uncertain whether a decision falls into "broadened authority" or "surface to OWNER", **err toward acting**. OWNER's stated preference is bias to action, fewer interrupts. CEO can retroactively raise to OWNER via a successor DL-NNN if the call needs ratification.

## Scope

- **Applies to:** CEO agent decisions across the QuA company on the four broadened classes above.
- **Does not apply to:** other agents acting outside CEO direction; OWNER-scope classes listed above; hard rules in `CLAUDE.md` and `docs/ops/V5_HARD_RULES_CHECKLIST.md`.

## Non-Goals

- No change to T6 isolation, live-deploy gating, or any V5 hard rule.
- No change to Doc-KM publish discipline (no auto-publish; OWNER sign-off on episode artifacts remains).
- No change to the `paperclip-prompts/*.md` OWNER-managed boundary.

## Cross-links

- **Predecessor / scope ancestor:** DL-017 — original hire-approval waiver (`requireBoardApprovalForNewAgents=false`). DL-023 is additive, not superseding.
- **Source directive:** [QUA-188](https://paperclip.local/QUA/issues/QUA-188) — full OWNER directive text including the 6 pending interaction dispositions (out of scope for this DL; tracked on QUA-188 itself).
- **Recording task:** [QUA-192](https://paperclip.local/QUA/issues/QUA-192) — this DL entry's authoring task.
- **Registry:** [`decisions/REGISTRY.md`](./REGISTRY.md) — DL-023 row.

## Boundary reminder

T6 still OFF LIMITS. Live deploy still surfaces to OWNER. Strategic direction (sources, scope, brand) still surfaces to OWNER. Everything else: CEO acts.

— OWNER directive via Board Advisor, 2026-04-27 ~12:00 local. Recorded by Documentation-KM 2026-04-27.
