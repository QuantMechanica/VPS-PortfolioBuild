# DL-062 — Single Wake Source

**Date:** 2026-05-09
**Author:** Board Advisor (draft, awaiting OWNER ratification)
**Status:** DRAFT
**Authority:** OWNER directive 2026-05-09 (token-burn audit + Mission Baseline) + DL-046 (no keepalive-evidence churn)

## Problem

QuantMechanica V5 currently has **multiple uncoordinated wake sources** that can fire an agent's runtime or post comments to issues on its behalf:

1. **Paperclip native heartbeat** (`runtimeConfig.heartbeat.enabled` + `wakeOnDemand`) — the canonical source.
2. **Wake-on-comment** (commenting on an issue assigned to an agent invokes its runtime).
3. **Continuation-runaway** (`retryOfRunId` chains in `heartbeat.ts` — partially patched in commit `0adeb49b` per QUA-1031).
4. **Windows scheduled tasks** invoking PowerShell wake-shims that call the Paperclip API on a fixed cadence (30+ such tasks observed 2026-05-09; 6 firing for closed/cancelled QUA issues — see `docs/ops/scheduled_tasks_cull_list_2026-05-09.md`).
5. **Self-perpetuating comment loops** where an agent's previous comment contains a "Required next-action" / "Next action preserved" line that wakes it on its own re-read.

These sources interact in unintended ways. The HoP+CTO keepalive loop on QUA-712 (2026-05-09 ~12:00–14:15Z) burned ~2h of Codex+Claude subscription tokens by combining sources 2 + 4 + 5. None of the agents involved had `heartbeat.enabled=true`.

## Decision

**Only the Paperclip native heartbeat subsystem may wake an agent's runtime.**

No external mechanism may invoke an agent's adapter, post comments on its behalf, or trigger Paperclip API mutations attributed to it.

## What this allows (✅)

- Paperclip runtime heartbeat per `runtimeConfig.heartbeat.*`
- Wake-on-comment when a different actor (human OWNER, another agent through CEO-routed dispatch, or `local-board`) leaves a comment on an issue the agent is assigned to
- Manual OWNER intervention (Board UI, Studio, direct API call as `local-board`)
- Scheduled jobs that perform **read-only** operations and write to the **filesystem only** (e.g., `QM_PipelineHealth_Watchdog`, `QM_DashboardRender_Hourly`, `QM_PublicSnapshot_Export_Hourly`, `QM_DailyStatusMail`)

## What this forbids (❌)

- Windows scheduled tasks that POST/PATCH to the Paperclip API on behalf of an agent
- PowerShell scripts that mutate issues, post comments, or invoke agent runtimes (the so-called "wake-shims")
- Comment bodies that contain self-perpetuating instruction lines ("Required next-action", "Next action preserved", "scoped wake remains") — these create source #5 even without external scheduling
- Agent skills that loop-post the previous comment's directive forward instead of acting on it

## Enforcement

1. **Audit (one-time, this DL ratification):** disable the 6 closed-issue scheduled tasks per cull list. Owner: DevOps.
2. **API-layer content-hash dedup (CTO):** reject `POST /comments` if body hash matches the previous comment from the same author on the same issue within 5 minutes. Hard rule, not soft warning. See `docs/ops/2026-05-09_watchdog_extensions_spec.md` for related work.
3. **Watchdog Detector C** (`docs/ops/2026-05-09_watchdog_extensions_spec.md` § Detector C) catches repeated-content storms even if the API dedup is bypassed.
4. **Closeout-checklist amendment (Doc-KM):** when a QUA issue closes, reviewer must `Disable-ScheduledTask` for any `QM_QUA<N>_*` Windows tasks created for it. Add to `processes/issue-closeout-checklist.md` (or wherever closeout lives).
5. **Skill audit (CoS):** sweep all `paperclip-prompts/*.md` and skill files for the forbidden phrase patterns; remove or rewrite. (2026-05-09 grep found zero matches in current AGENTS.md/skills — the loop pattern was emergent at runtime, confirming source #5 is the load-bearing failure.)

## Acceptance gates

- DL-062 ratified (OWNER sign-off)
- 6 cull-list tasks disabled; evidence in `docs/ops/scheduled_tasks_cull_list_2026-05-09.md`
- API dedup patch landed in `app/server/`; commit hash recorded here
- Watchdog Detector C live; QUA-1160 comments demonstrate it firing
- Closeout-checklist amended; commit hash recorded here

## Authority chain

- Authority: OWNER directive 2026-05-09 + DL-023 (CEO autonomy) + DL-046 (no keepalive-evidence churn) + DL-061 (Endausbaustufe-Modus — every workstream continuous parallel, can't have agents looping on closed work)
- Companion: `docs/ops/scheduled_tasks_cull_list_2026-05-09.md`, `docs/ops/2026-05-09_watchdog_extensions_spec.md`

## Notes

- DL-062 is the wake-side of the same problem DL-046 attacked from the comment-content side. DL-046 said "no keepalive churn"; DL-062 closes the wake-source pathways that make churn possible.
- This DL is intentionally narrow: it does not change agent heartbeat policy or how Paperclip itself schedules. It only forbids out-of-band mechanisms.
