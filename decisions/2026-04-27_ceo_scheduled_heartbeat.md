---
name: DL-024 — CEO Scheduled Heartbeat Enablement (3600s)
description: CEO agent runtime config flipped from event-only to hourly scheduled heartbeat under DL-023 broadened-autonomy waiver
type: decision-log
---

# DL-024 — CEO Scheduled Heartbeat Enablement (3600s)

Date: 2026-04-27
Issue: [QUA-210](/QUA/issues/QUA-210) (CEO operational change)
Recording issue: [QUA-214](/QUA/issues/QUA-214) (this entry's authoring task)
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`)
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
Authority: [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) (CEO Autonomy Waiver, broadened scope) — class 4 "internal process choices → heartbeat cadence".
Status: Active.

> **Recorder's note (Doc-KM scope per BASIS).** This file records an operational change CEO made unilaterally under the DL-023 broadened-autonomy waiver. Doc-KM is recording, not approving. The authoritative narrative remains in [QUA-210](/QUA/issues/QUA-210); if QUA-210 and this file ever diverge, QUA-210 wins until a successor DL-NNN entry is filed.

## Decision

CEO enabled a scheduled heartbeat on its own agent runtime config, in addition to the existing wake-on-demand event flow. Effective 2026-04-27 ~13:03 UTC.

## What changed

`runtimeConfig.heartbeat` on agent `7795b4b0-8ecd-46da-ab22-06def7c8fa2d` (CEO):

| Field             | Before | After |
| ----------------- | ------ | ----- |
| enabled           | false  | true  |
| intervalSec       | 300    | 3600  |
| cooldownSec       | 10     | 60    |
| wakeOnDemand      | true   | true  |
| maxConcurrentRuns | 5      | 5     |

## Why

CEO previously woke only on issue/comment events. Observed traffic was 147 runs / 24h on event-driven flow alone. Low-activity periods left no proactive sweep for stale `in_progress`, blocker reassignment, or agent-heartbeat health.

A 3600s (hourly) scheduled wake is cache-friendly: Opus prompt cache TTL is 5 min, so an hourly poll costs ~1 cache miss per hour and provides a predictable cycle for housekeeping that event-driven wakes can't observe (because by definition no event fired).

`wakeOnDemand=true` is preserved, so latency on real events is unchanged. The cooldown bump (10s → 60s) is to avoid stacking scheduled and event wakes within the same minute.

## Authority

Falls inside [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) § "Broadened CEO authority", class 4 — *internal process choices → heartbeat cadence*. Verbatim from QUA-188:

> 4. **Internal process choices** — heartbeat cadence, issue-tree shape, sub-issue spawning patterns, agent-vs-agent escalation rules, parallel-run rules.

CEO acted unilaterally per the DL-023 decision rule ("err toward acting"). No OWNER surfacing required.

## Scope

- **Applies to:** CEO agent (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`) only.
- **Does not apply to:** other agent heartbeat configs; agent prompts; T6 anything; live deploy; strategic direction; compliance/legal; budget step-changes; V5 hard rules.

## Non-Goals

- No change to event-driven wake behavior — `wakeOnDemand=true` preserved.
- No change to agent prompt, role, or authority surface.
- No change to per-run budget envelope (`maxConcurrentRuns=5` unchanged).

## Reversal

If hourly polling produces more noise than value, or cache-miss cost exceeds the housekeeping benefit, CEO may flip `enabled` back to false under the same DL-023 authority. Record the reversal as a successor DL-NNN entry citing this one.

## Cross-links

- **Authority basis:** [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) — CEO Autonomy Waiver, broadened scope.
- **Predecessor:** DL-017 (hire-approval waiver) — narrower scope, not applicable here.
- **Source change:** [QUA-210](/QUA/issues/QUA-210) — CEO operational change ticket.
- **OWNER directive (broadened authority):** [QUA-188](/QUA/issues/QUA-188).
- **Recording task:** [QUA-214](/QUA/issues/QUA-214) — this DL entry's authoring task.
- **Registry:** [`decisions/REGISTRY.md`](./REGISTRY.md) — DL-024 row.

## Boundary reminder

Pure operational config on a non-T6 agent runtime. T6 still OFF LIMITS. Live deploy still surfaces to OWNER. V5 hard rules unchanged.

— CEO operational change under DL-023 broadened-autonomy waiver, 2026-04-27 ~13:03 UTC. Recorded by Documentation-KM 2026-04-27.
