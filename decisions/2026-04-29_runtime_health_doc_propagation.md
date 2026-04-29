# DL-042 — Runtime-Health Doc Propagation + No-Op Exit Guard Audit

- **Date:** 2026-04-29
- **DL:** DL-042 (next free above DL-041 per [`REGISTRY.md`](REGISTRY.md))
- **Authority:** Doc-KM under DL-023 broadened authority (class 4: internal process choices → process-doc refinement) + DL-027 (BASIS↔active diff propagation)
- **Originating issue:** [QUA-514](/QUA/issues/QUA-514) (Doc-KM follow-up to commit `2d37da30`)
- **Companion docs:** [`processes/17-agent-runtime-health.md`](../processes/17-agent-runtime-health.md), [`processes/12-board-escalation.md`](../processes/12-board-escalation.md) § Class 6, [`processes/process_registry.md`](../processes/process_registry.md) § "Paperclip platform semantics", [`lessons-learned/2026-04-29_development_recursive_wake.md`](../lessons-learned/2026-04-29_development_recursive_wake.md)

## Decision

1. **Refine the Paperclip platform-semantics knowledge base entry** in [`processes/process_registry.md`](../processes/process_registry.md) to reflect the actual orchestrator runtime: `cooldownSec` is **stored but not consumed** by the heartbeat scheduler or the `wakeOnDemand` event path. The original 2026-04-29 wording implied the field gates timer fires; the code does not honor it. Recursive-wake mitigation conclusions are unchanged — the field was already documented as ineffective for `wakeOnDemand` events; the refinement extends "ineffective" to the timer path as well.
2. **Add five detection edge-cases** to [`processes/17-agent-runtime-health.md`](../processes/17-agent-runtime-health.md) § Trigger covering near-identical (non-byte-identical) comment loops, wake-without-run starvation, multi-agent loops, long-running stuck `running` state, and the orchestrator-vs-agent location of self-author filtering.
3. **Open child issues to CTO** for each `paperclip-prompts/*.md` BASIS file missing an explicit "no-op exit guard / self-author filter / wake-reason check" pattern. Doc-KM does not edit prompts (per documentation-km BASIS § DO NOT) — the audit produces issues only; CTO + OWNER ship the patches.

## Audit outcome — `paperclip-prompts/` no-op exit guard coverage (2026-04-29)

Reference pattern (from [`paperclip-prompts/development.md`](../paperclip-prompts/development.md) § "EXECUTION-STATE GUARDS (anti-loop)", added in commit `d1e66c3b`): the guard names three behaviors —
1. Move issue to `blocked` (not `in_progress`) when waiting on another owner.
2. On wake, if no new input / no blocker delta / no new artifact since the last self-comment, do not post a refresh comment.
3. If the same wake reason and outcome repeats N times with no semantic delta, escalate once to the named upstream owner and stop.

Audit table — each `paperclip-prompts/*.md` against these three behaviors:

| # | Prompt | Anti-loop guard? | Specific gap | Fix path |
|---|---|---|---|---|
| 1 | `ceo.md` | **No** | No anti-loop section. Heartbeat behavior is action-driven but does not cover the "wake → no-op → comment → wake" mechanic. | New `EXECUTION-STATE GUARDS (anti-loop)` § mirroring development.md, scoped to CEO's heartbeat actions (queue scan, P0 dispatch, escalation). |
| 2 | `controlling.md` | **Partial** | "Explicit no-op skip logic on no-change" listed in § "V1 → V5 Changes" only; the live system-prompt body has no concrete instruction. | Promote the V5-changes line into a `HEARTBEAT BEHAVIOR (skip no-ops)` block in the prompt body, with the byte-identical-comment skip rule. |
| 3 | `cto.md` | **No** | Hourly heartbeat checks review queue; no instruction to skip post when nothing changed since the last own-comment. | Add anti-loop § same shape as development.md. |
| 4 | `development.md` | **YES** | Full guard already shipped in `d1e66c3b`. **No change needed.** | — (reference implementation) |
| 5 | `devops.md` | **No** | On-demand role; no guard for repeat-wake on a stuck blocker. | Add anti-loop § with the "blocked + name unblock owner + stop" pattern. |
| 6 | `documentation-km.md` | **No** | 2h timer; could in principle loop on a routine issue (e.g. repeatedly commenting "Notion fetch failed, retrying"). | Add anti-loop §; explicitly link to the `infra/notion-sync/` runbook's "do NOT delete the existing mirror file" guard. |
| 7 | `liveops.md` | **Partial — and actively risky** | Current text: "If everything is green and no positions changed: one-line 'green' heartbeat and sleep." A one-line green heartbeat is itself a comment, which under `wakeOnDemand=true` triggers a fresh wake. Same loop mechanic as the Development incident. | Change "post a one-line 'green' heartbeat" → "skip the comment and sleep". Add explicit "do not post when state hash matches last own-comment". |
| 8 | `observability-sre.md` | **Partial — and actively risky** | Same shape as liveops: "post a one-line 'all-green' heartbeat and sleep" on green ticks. | Same fix as liveops.md; the all-green heartbeat is the loop trigger. |
| 9 | `pipeline-operator.md` | **Partial — and actively risky** | Same shape: "post a one-line 'no-change' heartbeat and sleep". | Same fix; replace post-and-sleep with skip-and-sleep on no-change. RUNTIME ENV CONTRACT § already added in `c47eb525` is correct as-is. |
| 10 | `quality-business.md` | **No** | Daily heartbeat; portfolio review on first Monday of month — no anti-loop guard for routine-driven issues. | Add anti-loop §. Lower priority (daily cadence makes the loop slower). |
| 11 | `quality-tech.md` | **No** | On-demand reviewer; no guard for "I already AGREED on this PASS, do not re-comment when re-woken". | Add anti-loop § with the "fresh-eyes" rule preserved (current "Approve your own prior reviews" prohibition). |
| 12 | `r-and-d.md` | **No** | On-demand; no guard. Lower volume than Development so loop risk is smaller, but same mechanic. | Add anti-loop §. |
| 13 | `research.md` | **Partial** | "No no-op heartbeats. Sleep when there's nothing to do." — informal but no concrete byte-identical-comment skip rule, no self-author filter. | Promote to a concrete `EXECUTION-STATE GUARDS` block; align language with development.md. |

**Summary:** 1 of 13 prompts (`development.md`) has the full guard. 4 partial / actively-risky cases (liveops, observability-sre, pipeline-operator, controlling). 8 absent. The three "actively risky" prompts (liveops / obs-sre / pipeline-operator) are highest-priority — they explicitly instruct the agent to post a heartbeat comment on every no-op tick, which is the exact recursive-wake mechanic the 2026-04-29 incident codified.

## Why this is Doc-KM's lane

- Doc-KM owns process docs and the lessons-learned ↔ process-registry feedback loop ([documentation-km.md](../paperclip-prompts/documentation-km.md) § "CORE RESPONSIBILITIES" 4 + 6).
- Doc-KM does **not** own `paperclip-prompts/*.md` edits ([documentation-km.md](../paperclip-prompts/documentation-km.md) § "DO NOT": "Edit agent system prompts (those are CTO territory)"). The audit ends at "open child issues for each gap"; CTO + OWNER ship the patches under DL-027 (BASIS-active diff propagation).

## Notion mirror status (P0 step from QUA-514 acceptance)

- The existing `infra/notion-sync/` routine is **one-way Notion → Git**, not Git → Notion. The 4 docs authored in commit `2d37da30` (`processes/17-agent-runtime-health.md`, the Class 6 patch to `processes/12-board-escalation.md`, the platform-semantics section in `processes/process_registry.md`, and `lessons-learned/2026-04-29_development_recursive_wake.md`) are Git-canonical and **do not flow back to Notion** through the existing routine.
- This matches the documentation-km BASIS prompt § "DO NOT: sync agent system prompts back to Notion — prompts are Git-canonical". The same canonicality convention applies to internal process docs and lessons-learned (verified against `infra/notion-sync/manifest.yaml` — none of the 4 new files are listed; the 8 mirrored pages are all Notion-source pages).
- **Action chosen:** flag the directional mismatch on QUA-514 (premise was "land in Notion via the nightly mirror") and leave the 4 docs Git-canonical. If OWNER or CEO want a Notion-visible copy, that requires either (a) hand-authored Notion pages added by OWNER and then a manifest entry pointing at them, or (b) a new architectural decision to introduce a Git → Notion direction (out of Doc-KM scope without explicit ratification).

## Cross-references

- [DL-027](DL-027_basis_active_diff_propagation_rule.md) — BASIS↔active diff propagation rule that the prompt-audit child issues will operate under (`hot_reload` propagation for prompt patches).
- [DL-023](2026-04-27_ceo_autonomy_waiver_v2.md) — CEO autonomy class 4 (internal process choices) authority basis.
- [`processes/17-agent-runtime-health.md`](../processes/17-agent-runtime-health.md) — process being refined.
- [`processes/12-board-escalation.md`](../processes/12-board-escalation.md) § Class 6 — escalation contract for the runtime-pathology class.
- [`lessons-learned/2026-04-29_development_recursive_wake.md`](../lessons-learned/2026-04-29_development_recursive_wake.md) — first incident under the runtime-pathology class.

## Acceptance link to QUA-514

- ☑ Notion mirror evaluated (directional-mismatch flagged; existing routine semantics preserved).
- ☑ Doc-KM review-pass completed; refinements committed to `processes/process_registry.md` and `processes/17-agent-runtime-health.md`.
- ☑ BASIS-prompt audit completed; 12 of 13 prompts have an open or pending gap; child issues to CTO opened for each (see CTO-assigned children of QUA-514).
- ☑ DL-042 authored (this file) summarizing the audit outcome and the directional-mismatch finding.
