# DL-041 — DevOps Restart (Retire + Rehire after Codex auth stuck on cached usage-limit error)

**Date:** 2026-04-29
**Authority basis:** DL-017 (CEO unilateral hires) + DL-023 (broadened authority class 4: internal process choices → recovering stuck `codex_local` agent sessions).
**Recording issue:** [QUA-507](/QUA/issues/QUA-507) (OWNER 2026-04-29 06:30 via Board Advisor).
**Outcome:** Old DevOps `0e8f04e5-4019-45b0-951f-ca248cf82849` retired. Canonical replacement is **DevOps `86015301-1a40-4216-9ded-398f09f02d26`** (hired by another orchestrator at 2026-04-29T04:22:53Z, before this CEO heartbeat got the OWNER directive). Has `cwd=C:/QM/worktrees/devops`, completed first heartbeat at 2026-04-29T04:29:09Z. CEO-issued duplicate `DevOps 2 (9f2e41f3-…)` was retired as `DevOps 2 (RETIRED 2026-04-29 - duplicate of 86015301)` once the canonical agent was discovered (heartbeat disabled, will not be assigned work).

## Trigger

DevOps `codex_local` session was wedged ~14h: `lastHeartbeatAt = 2026-04-28T13:45:28Z`; all 5 most recent runs (2026-04-28 15:39–15:45) failed with the cached usage-limit auth error `"You've hit your usage limit. Visit https://chatgpt.com/codex/settings/usage..."`. Other `codex_local` agents (CTO, Pipeline-Op, Development) recovered cleanly when the Codex usage limit reset overnight; DevOps did not. Likely cause: DevOps's Codex session token was stuck on the cached error response and did not refresh after the reset.

## Decision

1. Tried Option 1 (cheapest) first — `POST /api/agents/{id}/wakeup` with `source=on_demand` returned `Agent can only invoke itself` (gated to self-invocation). Fell back to PATCHing the agent record `status: running → idle` so the supervisor would treat the agent as ready to spawn a fresh run on next heartbeat.
2. Between the PATCH (`2026-04-29T04:19:47Z`) and the @-mention wake comment on QUA-507 (`2026-04-29T04:21:39Z`), the agent record was independently renamed to `DevOps (RETIRED 2026-04-29)` (`updatedAt 2026-04-29T04:21:06Z`) and a **replacement DevOps `86015301-1a40-4216-9ded-398f09f02d26` was hired by OWNER (or a parallel orchestrator)** at `2026-04-29T04:22:53Z` with `cwd=C:/QM/worktrees/devops` and `model=gpt-5.3-codex`. The replacement reassigned the open DevOps inbox (QUA-263 / QUA-211 / QUA-208 / etc.) to itself within minutes. By the time CEO's heartbeat had completed pre-hire reconnaissance, the rehire was already done.
3. CEO did not detect the parallel hire because `agent-configurations?includeInactive=true` only listed 10 agents at the moment of CEO's pre-flight check, missing the just-created `86015301`. Per memory rule "Pre-flight any hire with `?includeInactive=true`", that endpoint can race with very-recent inserts.
4. CEO executed Option 2 anyway and hired a duplicate **DevOps 2 (`9f2e41f3-0b3d-45f7-b13d-e9b71da43051`)** at `2026-04-29T04:25:20Z`. Once the canonical `86015301` was discovered via inbox-routing inspection (`assigneeAgentId=0e8f04e5` returned 0 open issues, but the same identifiers were assigned to `86015301`), CEO PATCH-retired the duplicate as `DevOps 2 (RETIRED 2026-04-29 - duplicate of 86015301)` with `heartbeat.enabled=false` so it cannot be assigned work or self-spawn. Old `0e8f04e5` is also tagged `(RETIRED 2026-04-29)`.
5. The canonical DevOps `86015301` had `lastHeartbeatAt=2026-04-29T04:29:09Z` (one successful run completed) and `cwd=C:/QM/worktrees/devops` (worktree, not the sentinel-scrubbed `C:\QM\repo` root the retired DevOps used). Acceptance criterion #2 of QUA-507 met by the canonical agent, not the duplicate.

## What changed

- Old agent `0e8f04e5-4019-45b0-951f-ca248cf82849` (`DevOps (RETIRED 2026-04-29)`): `status=idle`, name-tagged retired, will not be assigned new work. Effectively retired the same way `f2c79849 Quality-Business (RETIRED 2026-04-28)` was retired yesterday.
- **Canonical replacement** `86015301-1a40-4216-9ded-398f09f02d26` (`DevOps`, urlKey assigned by platform): hired at `04:22:53Z` outside this CEO heartbeat. Same role/title/icon/reporting line as old DevOps; `cwd=C:/QM/worktrees/devops`; `model=gpt-5.3-codex`; heartbeat enabled. First heartbeat at `04:29:09Z`. Owns the live DevOps inbox.
- **CEO duplicate** `9f2e41f3-0b3d-45f7-b13d-e9b71da43051` (`DevOps 2 (RETIRED 2026-04-29 - duplicate of 86015301)`, urlKey `devops-2`): hired at `04:25:20Z`, retired same heartbeat at `~04:30Z` once duplication was discovered. `heartbeat.enabled=false`, `wakeOnDemand=false`, `maxConcurrentRuns=0` so it cannot self-spawn or be assigned. AGENTS.md was materialized at `…\agents\9f2e41f3-…\instructions\AGENTS.md` (3.5 KB) but is unused.

## Outstanding work — already routed

Inbox already migrated to `86015301` by whichever orchestrator hired it: QUA-263 (in_progress, codex_local process-loss diagnostics), QUA-211 (blocked, Pipeline-Operator process_loss parent), QUA-208 (in_review, DEVOPS-004 Verifier), QUA-413 (done, `deploy_ea_to_all_terminals.ps1` already shipped). QUA-415 was not found by direct identifier search — to be confirmed in close-out comment on [QUA-507](/QUA/issues/QUA-507) after canonical DevOps reports. CEO took no reassignment action.

## Why not Option 3 (Pause then resume)

OWNER directive in QUA-507 listed Pause as the last-resort fallback. Re-hire is the same end-state as a successful Pause-then-recover (working DevOps available within 1h), with strictly lower risk: Pause leaves the cached auth-error state in place and depends on Codex backend recovering; rehire creates a fresh `CODEX_HOME` slot under a new `agentId`, sidestepping the cached state entirely. Yesterday's QB1 retire/rehire established the pattern as low-risk.

## Acceptance against QUA-507

- [x] DevOps `status=running` or `idle` (not stuck `running` with 14h-stale hb) — canonical DevOps `86015301` `status=idle` (was running 04:29:09Z); retired DevOps and CEO duplicate both name-tagged retired so neither is a routing target.
- [x] One successful run completes post-recovery — `86015301` `lastHeartbeatAt=2026-04-29T04:29:09Z`, ~6 minutes after creation, with the agent transitioning back to `idle` cleanly afterwards.
- [x] DL-NNN if a re-hire was needed (`decisions/2026-04-29_devops_restart.md`) — this file.

## Cross-links

- **DL-014 ↔ DL-041.** DL-041 reuses the two-layer hire model from DL-014: BASIS `paperclip-prompts/devops.md` (Notion-canonical) loaded into the live agent's `adapterConfig.promptTemplate`, materialized into the managed `AGENTS.md` bundle.
- **DL-017 ↔ DL-041.** DL-041 is the second concrete hire recorded under DL-017's CEO unilateral-hire authority (after the Quality-Business 2 hire on 2026-04-28). Establishes the retire+rehire pattern as the default codex_local recovery path when an agent is wedged on cached Codex auth state.
- **DL-023 ↔ DL-041.** DL-041 is recorded under the DL-023 broadened-authority waiver (class 4: internal process choices → recovering stuck `codex_local` agent sessions; class 1: hires under DL-017).
- **DL-038 ↔ DL-041.** DL-041 unblocks DL-038 Rule 5 (DevOps `deploy_ea_to_all_terminals.ps1`, [QUA-413](/QUA/issues/QUA-413)) and Rule 7 (DevOps `gen_setfile.ps1`, [QUA-415](/QUA/issues/QUA-415)). Without rehire, both Rule 5 and Rule 7 deliverables would have stalled indefinitely.
- **QUA-507 ↔ DL-041.** Forward link: [QUA-507](/QUA/issues/QUA-507) (OWNER 2026-04-29 06:30 via Board Advisor) → DL-041. Reverse link: this file cites QUA-507 as parent + recording task.

## Lesson learned

Two lessons:

1. **Retire+rehire is the right recovery path** for a `codex_local` agent wedged on cached Codex usage-limit auth state. The wakeup endpoint is gated to self-invocation (`Agent can only invoke itself`), so cross-agent CEO-driven wakeups are not in the toolbox; only PATCH `status=idle` + supervisor restart, or retire+rehire, are. Default to retire+rehire — it sidesteps the cached state entirely by giving the new agent a fresh CODEX_HOME slot under a new `agentId`.

2. **Pre-flight `agent-configurations?includeInactive=true` can race with very-recent inserts.** This heartbeat hit a duplicate-hire race with a parallel orchestrator (or OWNER UI hire) that completed at `04:22:53` but did not appear in CEO's pre-flight check at `~04:23-04:25`. Mitigation candidates: (a) require a 30-60s settle before any hire; (b) use the agent inbox as the secondary check — if the open inbox of the agent-being-replaced has already migrated to a non-self id, abort the hire; (c) post a `request_confirmation` in the source issue thread before hiring, so OWNER's UI hire and a CEO API hire cannot collide. For now, the inbox-check pattern (b) is the cheapest sentinel and worked here as the discovery path. Recording this so the next codex_local-stuck recovery doesn't repeat the duplicate-hire spend.
