---
dl: DL-034
date: 2026-04-28
title: CEO heartbeat cadence change 3600s → 1800s (30 min) — under DL-023 authority, supersedes DL-024 rate
authority_basis: DL-023 (CEO broadened-autonomy waiver, class 4 — internal process choices → heartbeat cadence)
recording_issue: QUA-301
source_change: live on agent `7795b4b0-8ecd-46da-ab22-06def7c8fa2d` (CEO) — PATCH applied this heartbeat
predecessor: DL-024 (3600s enablement) — DL-034 supersedes the rate, not the model
status: active
---

# DL-034 — CEO Heartbeat 30 min (1800s)

Date: 2026-04-28
Issue: [QUA-297](/QUA/issues/QUA-297) (OWNER 2026-04-28 audit — operational changes triggered)
Recording issue: [QUA-301](/QUA/issues/QUA-301) (this entry's authoring task)
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`)
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
Authority: [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) (CEO Autonomy Waiver, broadened scope) — class 4 "internal process choices → heartbeat cadence".
Predecessor: [DL-024](./2026-04-27_ceo_scheduled_heartbeat.md) (CEO scheduled heartbeat enablement at 3600s).
Status: Active.

> **Recorder's note (Doc-KM scope per BASIS).** This file records an operational change CEO made unilaterally under the DL-023 broadened-autonomy waiver. Doc-KM is recording, not approving. The authoritative narrative remains in [QUA-297](/QUA/issues/QUA-297) (OWNER audit) and [QUA-301](/QUA/issues/QUA-301) (recording omnibus); if those threads diverge from this file, the Paperclip threads win until a successor DL-NNN entry is filed.

> **DL-NNN-collision note.** QUA-301 preallocated this entry as **DL-033**. While QUA-301 was being staged, `agents/docs-km` had already committed DL-033 for the OWNER addendum on no-strategy-prioritization + canonical lifecycle (recording task QUA-272, commit `f434e6b`). Per registry convention "skipped numbers are intentional gaps; do not reuse" and the "max(existing) + 1" allocation rule, this DL therefore lands as **DL-034**. The two sibling entries from QUA-301 bump in lockstep: load-balancing → DL-035, EA Review Gate → DL-036. The work product itself is unchanged.

## Decision

CEO halved its scheduled heartbeat interval on its own agent runtime config: `runtimeConfig.heartbeat.intervalSec` 3600 → 1800. Effective 2026-04-28 (this heartbeat, PATCH already applied on agent `7795b4b0-8ecd-46da-ab22-06def7c8fa2d` at the time QUA-301 was filed).

## What changed

`runtimeConfig.heartbeat` on agent `7795b4b0-8ecd-46da-ab22-06def7c8fa2d` (CEO):

| Field             | Before (DL-024) | After (DL-034) |
| ----------------- | --------------- | -------------- |
| enabled           | true            | true           |
| intervalSec       | 3600            | 1800           |
| cooldownSec       | 60              | 60             |
| wakeOnDemand      | true            | true           |
| maxConcurrentRuns | 5               | 5              |

Only `intervalSec` changes. Wake-on-demand path, cooldown, and per-run concurrency envelope are unchanged.

## Why

OWNER audit on 2026-04-28 (QUA-297) found that the hourly cadence enabled under DL-024 was too slow for active dispatching mode. Concrete observations from the overnight cycle:

- **Wave 2 hire trigger ran ~3.5 h late** — the trigger condition fired during a quiet hour but the next CEO sweep was over an hour away, so the dispatch ack was delayed by half a sleep cycle.
- **SRC03 source survey ratification** sat in the queue past its expected pickup window (similarly ~3.5 h).
- DL-024's hourly poll was tuned for housekeeping during low-activity windows. With Wave 2 hiring, source-queue ordering, and per-batch T3 approvals (DL-032) in flight, CEO is now in **active dispatching mode**, where 1 h is too coarse.

A 1800s (30 min) scheduled wake remains cache-friendly relative to event-driven traffic — Opus prompt cache TTL is 5 min, so 30 min still means one cache miss per scheduled wake, but the dispatcher latency floor halves. `wakeOnDemand=true` is preserved, so latency on real events is unchanged.

## Authority

Falls inside [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) § "Broadened CEO authority", class 4 — *internal process choices → heartbeat cadence*. Verbatim from the waiver:

> 4. **Internal process choices** — heartbeat cadence, issue-tree shape, sub-issue spawning patterns, agent-vs-agent escalation rules, parallel-run rules.

DL-024 already established this as in-class. DL-034 only changes the rate; the authority basis is identical.

## Scope

- **Applies to:** CEO agent (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`) only.
- **Does not apply to:** other agent heartbeat configs; agent prompts; T6 anything; live deploy; strategic direction; compliance/legal; budget step-changes; V5 hard rules.

## Non-Goals

- No change to event-driven wake behaviour — `wakeOnDemand=true` preserved.
- No change to agent prompt, role, or authority surface.
- No change to per-run budget envelope (`maxConcurrentRuns=5` unchanged).
- No change to other agents' heartbeats — DL-034 is CEO-only.

## Reversal

Revisit when V5 portfolio is live (Phase 5+). Once the active dispatching pressure eases (Wave 2 hires settle, source-queue ordering stabilises, portfolio is in steady-state run mode), CEO may revert to 3600s under the same DL-023 authority. Record any reversal as a successor DL-NNN entry citing this one.

## Cross-links

- **Authority basis:** [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) — CEO Autonomy Waiver, broadened scope.
- **Predecessor:** [DL-024](./2026-04-27_ceo_scheduled_heartbeat.md) — DL-034 supersedes the rate (3600 → 1800), not the model (scheduled + wake-on-demand).
- **Source / driver:** [QUA-297](/QUA/issues/QUA-297) — OWNER 2026-04-28 audit that surfaced the slow-dispatcher symptom.
- **Recording task:** [QUA-301](/QUA/issues/QUA-301) — this DL entry's authoring task (the recording omnibus for DL-034 / DL-035 / DL-036).
- **OWNER directive (broadened authority):** [QUA-188](/QUA/issues/QUA-188).
- **Registry:** [`decisions/REGISTRY.md`](./REGISTRY.md) — DL-034 row.
- **DL-027 propagation classification:** `reference_only` — no agent prompt body change.

## Boundary reminder

Pure operational config on a non-T6 agent runtime. T6 still OFF LIMITS. Live deploy still surfaces to OWNER. V5 hard rules unchanged.

— CEO operational change under DL-023 broadened-autonomy waiver, applied 2026-04-28 ahead of QUA-301 recording. Recorded by Documentation-KM 2026-04-28.
