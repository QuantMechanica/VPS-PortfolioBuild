---
issue: QUA-779
date: 2026-05-08
author: CEO (with CoS DL-056 escalation)
class: OWNER-class incident escalation
---

# QUA-779 — Root cause: Anthropic org monthly usage limit (4 of 10 agents)

## TL;DR

Four agents (Quality-Tech, Documentation-KM, Quality-Business, Research) entered
`status=error` because every Claude run since 2026-05-07 ~09:22Z is failing with:

> `Claude run failed: subtype=success: You've hit your org's monthly usage limit`

This is **not** an adapter bug, prompt bug, instruction bug, or worktree bug. It
is the Anthropic billing-org level monthly cap. Only OWNER can resolve.

CoS detection fired correctly per DL-056 §1 (agent roster hygiene) and §2
(token-burn watch). DL-056 protocol followed.

## Evidence

Source: `GET /api/companies/.../heartbeat-runs?limit=200` at 2026-05-07T22:11Z.

| Agent | Failed runs in last 200 | First fail (UTC) | Last fail (UTC) |
|---|---|---|---|
| Quality-Tech (`c1f90ba8`) | 17 | 2026-05-07T10:46:18Z | 2026-05-07T20:24:56Z |
| Documentation-KM (`8c85f83f`) | 12 | 2026-05-07T09:22:21Z | 2026-05-07T21:11:56Z |
| Quality-Business (`0ab3d743`) | 12 | 2026-05-07T11:18:23Z | 2026-05-07T20:38:26Z |
| Research (`7aef7a17`) | 8 | 2026-05-07T10:54:18Z | 2026-05-07T18:53:54Z |
| **Total** | **49 / 200 ≈ 24.5%** | | |

Every failed run has identical `error` field:
`Claude run failed: subtype=success: You've hit your org's monthly usage limit`
and `exitCode=1`.

The heartbeat scheduler keeps re-enqueueing — server.log shows
`heartbeat timer tick enqueued runs {"checked":10,"enqueued":3,"skipped":0}`
every ~30s. Each retry consumes a small amount of org quota (request setup) and
locks an agent into a tight failed-retry loop with no useful output.

## Why some agents are fine

Healthy agents share the same `claude_local` adapter and the same model class
(`claude-sonnet-4-6` for CoS / `claude-opus-4-7` for CEO), which suggests the
limit is **not** per-agent — it is org-wide. The four currently-broken agents
likely tipped the org over the cap because they ran longer reasoning sessions
(higher `effort`, more `maxTurns`, deeper instructionsBundleMode) over the
month. Once a request hits the cap mid-day, every subsequent request from the
same org returns the same error until quota resets or is raised.

CoS itself is also Sonnet but its watch-role workload is small per heartbeat;
it is currently below the per-request marginal cost that triggers the cap.

## What CEO can and cannot do

CEO (this issue's assignee) can:
- Document the diagnosis (this file)
- Stop the failed-retry waste by **pausing** affected agents — but agent
  pause/unpause is OWNER-class per memory `feedback_agent_pause_unpause_owner_only.md`
  and DL-017. PATCH `pausedAt` silently no-ops; POST `/pause` returns 403.
- Therefore the only thing CEO can do *operationally* is escalate.

CEO cannot:
- Touch Anthropic billing
- Raise the org monthly cap
- Pause agents to stop the retry loop
- Bypass the cap by switching model (Opus has its own quota; Sonnet broke first
  here only because the failing workloads happen to be Sonnet-bound)

## Recommendations to OWNER (decision needed)

Three mitigation options. They are **not** mutually exclusive.

### Option A — Top up the Anthropic monthly cap
Raise the org-level monthly limit at console.anthropic.com (Settings → Limits).
Quickest path back to 10/10 healthy. No DL needed; this is normal operating
budget management. CEO recommends this as the immediate action.

### Option B — Pause the four error agents until quota window resets
Stop the failed-retry waste while waiting for the monthly window. Saves a small
amount of marginal token spend (request setup) but doesn't fix the cap. OWNER
must execute the pause (CEO cannot). Useful if Option A is delayed.

Pause commands (run as OWNER from a board-token shell):
```
curl -X POST http://127.0.0.1:3100/api/agents/c1f90ba8-d637-46d9-8895-ead705bb4933/pause
curl -X POST http://127.0.0.1:3100/api/agents/8c85f83f-db7e-4414-8b85-aa558987a13e/pause
curl -X POST http://127.0.0.1:3100/api/agents/0ab3d743-e3fb-44e5-8d35-c05d0d78715d/pause
curl -X POST http://127.0.0.1:3100/api/agents/7aef7a17-d010-4f6e-a198-4a8dc5deb40d/pause
```

### Option C — Throttle high-effort sessions long-term
Once Option A unblocks, the same condition will recur next month if usage trend
is unchanged. CoS should add a per-agent token-burn forecast at DL-056 §2 and
recommend `effort: medium` or lower `maxTurnsPerRun` for Quality-Tech and
Quality-Business (the two highest burners). Tracked in CoS rolling tracker, not
in this issue.

## CoS escalation note

DL-056 §2 says "forecast within 4 days = escalate this heartbeat". CoS
escalated *after* the cap was hit, not before. That is a forecast miss — the
13-hour failed-retry storm should have been caught at the first 3-4 failures
clustering. CEO will raise this with CoS as a DL-056 §2 calibration issue
(not a fault — first month of operation, no priors). Out of scope for QUA-779.

## Files referenced

- `decisions/DL-056_chief_of_staff_os_controller_hire.md` — escalation protocol authority
- Memory: `feedback_agent_pause_unpause_owner_only.md` — OWNER-class pause gate
- Memory: `feedback_agent_unpause_owner_only.md` — OWNER-class unpause gate
- Memory: `reference_paperclip_local_trusted_api.md` — loopback trust mode (does not override OWNER-class gate)

## Status disposition

QUA-779 → **blocked**, unblock owner = OWNER, unblock action = decide A/B/C and
execute (top-up / pause / both). CEO will track via request_confirmation card on
this issue.
