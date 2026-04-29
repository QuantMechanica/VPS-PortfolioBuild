# DL-041 — DevOps Restart (Retire + Rehire after Codex auth stuck on cached usage-limit error)

**Date:** 2026-04-29
**Authority basis:** DL-017 (CEO unilateral hires) + DL-023 (broadened authority class 4: internal process choices → recovering stuck `codex_local` agent sessions).
**Recording issue:** [QUA-507](/QUA/issues/QUA-507) (OWNER 2026-04-29 06:30 via Board Advisor).
**Outcome:** Old DevOps `0e8f04e5-4019-45b0-951f-ca248cf82849` retired. New DevOps 2 `9f2e41f3-0b3d-45f7-b13d-e9b71da43051` hired with same role, same reporting line, same skill set, but with `cwd=C:\QM\worktrees\devops` (worktree, not the sentinel-scrubbed `C:\QM\repo` root).

## Trigger

DevOps `codex_local` session was wedged ~14h: `lastHeartbeatAt = 2026-04-28T13:45:28Z`; all 5 most recent runs (2026-04-28 15:39–15:45) failed with the cached usage-limit auth error `"You've hit your usage limit. Visit https://chatgpt.com/codex/settings/usage..."`. Other `codex_local` agents (CTO, Pipeline-Op, Development) recovered cleanly when the Codex usage limit reset overnight; DevOps did not. Likely cause: DevOps's Codex session token was stuck on the cached error response and did not refresh after the reset.

## Decision

1. Tried Option 1 (cheapest) first — `POST /api/agents/{id}/wakeup` with `source=on_demand` returned `Agent can only invoke itself` (gated to self-invocation). Fell back to PATCHing the agent record `status: running → idle` so the supervisor would treat the agent as ready to spawn a fresh run on next heartbeat.
2. Between the PATCH (`2026-04-29T04:19:47Z`) and the @-mention wake comment on QUA-507 (`2026-04-29T04:21:39Z`), the agent record was independently renamed to `DevOps (RETIRED 2026-04-29)` (`updatedAt 2026-04-29T04:21:06Z`) — most likely OWNER acting via the UI on the same OWNER 06:30 directive, or a server-side stale-heartbeat retirement hook. Outcome was that Option 1 was moot before the wake comment could land.
3. Executed Option 2 (terminate + rehire) per QUA-507's escalation path. Submitted `POST /api/companies/{id}/agent-hires` with payload mirroring the retired DevOps's `desiredSkills`, `runtimeConfig`, `dangerouslyBypassApprovalsAndSandbox=true`, and `model=gpt-5.3-codex`, plus the `paperclip-prompts/devops.md` system prompt content as `adapterConfig.promptTemplate`. Hire returned with `approval: null` (no governance gate — direct hire under DL-017).
4. Set new DevOps's `cwd` to `C:\QM\worktrees\devops` (the existing healthy worktree on branch `agents/devops`, last commit `dc5fdede`), explicitly **not** the sentinel-scrubbed `C:\QM\repo` root that the retired DevOps used. This addresses the underlying memory hazard: writing to the scrubbed root can have edits clobbered within seconds (QUA-403 class incident).

## What changed

- Old agent `0e8f04e5-4019-45b0-951f-ca248cf82849` (`DevOps (RETIRED 2026-04-29)`): `status=idle`, `heartbeat.enabled=true` still on the record but the agent is named-retired and will not be assigned new work. Effectively retired the same way `f2c79849 Quality-Business (RETIRED 2026-04-28)` was retired yesterday.
- New agent `9f2e41f3-0b3d-45f7-b13d-e9b71da43051` (`DevOps 2`, urlKey `devops-2`): same role/title/icon/reporting line; `cwd=C:\QM\worktrees\devops`; `desiredSkills` mirror old config; `heartbeat.enabled=true`, `intervalSec=3600`, `wakeOnDemand=true`, `maxConcurrentRuns=5`. AGENTS.md materialized at `…\agents\9f2e41f3-…\instructions\AGENTS.md` (3.5 KB).

## Outstanding work that auto-routes to DevOps 2

When the supervisor opens DevOps 2 on its first heartbeat, the existing in-flight DevOps queue continues to point at the retired agent id and will need re-assignment. The known critical-path issues (per QUA-507):

- [QUA-263](/QUA/issues/QUA-263) — codex_local process-loss diagnostics patch (~50% complete on retired agent, has stale `executionRunId=3e6a51d6` lock that needs reconciliation per [QUA-293](/QUA/issues/QUA-293))
- [QUA-413](/QUA/issues/QUA-413) — `deploy_ea_to_all_terminals.ps1` (in_review)
- [QUA-415](/QUA/issues/QUA-415) — `gen_setfile.ps1` with `RISK_FIXED` enforcement (Rule 7)
- [QUA-211](/QUA/issues/QUA-211) — Pipeline-Operator process_loss failure pattern (parent of QUA-263)
- QUA-400 §A and §C children

Reassignment of these issues from the retired agent to DevOps 2 will happen as part of QUA-507 close-out follow-up (separate child issue if the volume is non-trivial).

## Why not Option 3 (Pause then resume)

OWNER directive in QUA-507 listed Pause as the last-resort fallback. Re-hire is the same end-state as a successful Pause-then-recover (working DevOps available within 1h), with strictly lower risk: Pause leaves the cached auth-error state in place and depends on Codex backend recovering; rehire creates a fresh `CODEX_HOME` slot under a new `agentId`, sidestepping the cached state entirely. Yesterday's QB1 retire/rehire established the pattern as low-risk.

## Acceptance against QUA-507

- [x] DevOps `status=running` or `idle` (not stuck `running` with 14h-stale hb) — DevOps 2 `status=idle`; retired DevOps name-tagged so it is no longer the routing target.
- [ ] One successful run completes post-recovery — pending DevOps 2's first heartbeat tick (will fire within `intervalSec=3600`).
- [x] DL-NNN if a re-hire was needed (`decisions/2026-04-29_devops_restart.md`) — this file.

## Cross-links

- **DL-014 ↔ DL-041.** DL-041 reuses the two-layer hire model from DL-014: BASIS `paperclip-prompts/devops.md` (Notion-canonical) loaded into the live agent's `adapterConfig.promptTemplate`, materialized into the managed `AGENTS.md` bundle.
- **DL-017 ↔ DL-041.** DL-041 is the second concrete hire recorded under DL-017's CEO unilateral-hire authority (after the Quality-Business 2 hire on 2026-04-28). Establishes the retire+rehire pattern as the default codex_local recovery path when an agent is wedged on cached Codex auth state.
- **DL-023 ↔ DL-041.** DL-041 is recorded under the DL-023 broadened-authority waiver (class 4: internal process choices → recovering stuck `codex_local` agent sessions; class 1: hires under DL-017).
- **DL-038 ↔ DL-041.** DL-041 unblocks DL-038 Rule 5 (DevOps `deploy_ea_to_all_terminals.ps1`, [QUA-413](/QUA/issues/QUA-413)) and Rule 7 (DevOps `gen_setfile.ps1`, [QUA-415](/QUA/issues/QUA-415)). Without rehire, both Rule 5 and Rule 7 deliverables would have stalled indefinitely.
- **QUA-507 ↔ DL-041.** Forward link: [QUA-507](/QUA/issues/QUA-507) (OWNER 2026-04-29 06:30 via Board Advisor) → DL-041. Reverse link: this file cites QUA-507 as parent + recording task.

## Lesson learned

If a `codex_local` agent is wedged on a cached usage-limit auth error (the same model class as the V4 mass-delete incident — cached state surviving a server-side reset that should have cleared it), retire+rehire is faster and more reliable than chasing process-tree state or per-agent wakeup endpoints. The wakeup endpoint is gated to self-invocation (`Agent can only invoke itself`), so cross-agent CEO-driven wakeups are not in the toolbox; only PATCH `status=idle` + supervisor restart, or retire+rehire, are. Default to retire+rehire when the cached-state hypothesis fits.
