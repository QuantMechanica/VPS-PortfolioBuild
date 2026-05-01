# DL-047 — Phase 2 Heartbeat Rebalance (72h Throttle)

> Renumbered 2026-05-01 from DL-034 to DL-047. Original commit `31ffb43d` collided with the prior DL-034 (`2026-04-28_ceo_heartbeat_30min.md`, recorded under QUA-301 on 2026-04-28). Per registry rule "skipped numbers are intentional gaps; do not reuse" + Doc-KM's QUA-645 cited-authority-drift note, this entry materialises at DL-047 (max(existing)+1 after DL-046 Meta-work purge). Doc-KM's DL-045 (QT/QB Wave 2 backfill) is a sibling under QUA-639 D4. The two roster-cleanup and metadata-hygiene siblings of this entry renumber alongside as DL-048 and DL-049 respectively.

- **Date:** 2026-05-01
- **Author:** CEO (`7795b4b0-...`)
- **Approver:** OWNER directive (QUA-639 wake comment 2026-05-01T07:14:48Z, "Get this going now, it has highest priorization!")
- **Authority basis:** DL-023 (broadened CEO authority, internal process choices) + DL-024 precedent (CEO scheduled heartbeat enablement) + DL-034 (CEO heartbeat rate 3600s→1800s, the closer-in-time precedent for CEO unilateral heartbeat-cadence directives under DL-023 class 4).
- **Status:** ACTIVE 2026-05-01 → 2026-05-04 (72h window). Snap-back date: 2026-05-04 07:00 UTC.
- **Related:** QUA-639, `docs/ops/CEO_DIRECTIVE_PHASE2_CLOSE_2026-05-01.md`, `docs/ops/PHASE2_FRAMEWORK_CLOSEOUT_AUDIT_2026-05-01.md`.

## Decision

Throttle non-critical infra / `QUA-###` housekeeping cycles for 72 hours and re-target Wave 0/1 heartbeats onto Phase 2 close (Step 25) and Phase 3 EA pipeline progress (1003/1004 compile/test/baseline-backtest).

## Why

- Last `framework:` commit is `210e541` from 2026-04-27 — 4 days of zero framework progress.
- The most recent ~50 commits are `infra:` / `QUA-###:` housekeeping (transition payloads, payload validators, scheduler hardening, install-preview flags, runtime-health watchdogs).
- Phase 2 cannot close and Phase 3 cannot progress while the heartbeat budget lands on enforcer hardening.
- Quality-Tech has been hired (`c1f90ba8-...`, 2026-04-28) and is idle relative to Step 25. The bottleneck is heartbeat allocation, not capacity.

## Scope of throttle (per agent)

| Agent | Default mode | Throttle-window mode (now → 2026-05-04) |
|---|---|---|
| **CTO** (`241ccf3c-...`) | infra + framework + EA review | **Framework + 1003/1004 compile/test only.** Pause infra/QUA-### work unless on the critical path of Step 25 or 1003/1004 first backtest. ea_id_registry status tidy (1003/1004 → `draft` until first `.ex5`) folded into the Step 25 review pass. |
| **Development** (`ebefc3a6-...`) | EA build per Strategy Card | **EA 1003/1004 compile + smoke + fix-on-FAIL only.** No new EA scaffolding. |
| **Documentation-KM** (`8c85f83f-...`) | process docs + lessons-learned | **Lessons-learned + ADR authoring only.** No new process-doc churn. Authors the QT/QB early-hire backfill DL and the Step 25 acceptance ADR after QT verdict lands. |
| **Pipeline-Operator** (`46fc11e5-...`) | baseline backtests | **Hold for 1003/1004 baseline backtests.** Trigger immediately on Step 25 PASS. |
| **Quality-Tech** (`c1f90ba8-...`) | (no recurring assignments) | **Step 25 framework review** (designs own review interior per Specification Density Principle). |
| **Research** (`7aef7a17-...`) | source extraction / Strategy Cards | **Continue source-queue per DL-029**, but defer new Strategy Card landings until QT bandwidth frees post-Step-25. |
| **DevOps** (`86015301-...`) | infra + factory maintenance | **Factory state-of-readiness only.** No new infra-issue creation that does not sit on the critical path for D1 or D5 of QUA-639. |

## What is paused

- New `infra:` / `QUA-###` issue creation that does not sit on the critical path for QUA-639 D1 (Step 25) or D5 (metadata hygiene).
- New process-doc churn (Doc-KM holds in lessons-learned + ADR-authoring mode).
- Net-new EA scaffolding beyond 1003/1004.
- Strategy-Card landings that would queue more work behind QT.

## What is NOT paused

- Live runtime-incident response (PC1-00 surface, hot-poll triage, stale-lock recovery).
- T6-isolation enforcement (always on, never throttled).
- Pre-existing `in_progress` issues — finish what is started, do not start net-new.
- Heartbeat-cadence safety: agents continue to wake on assignment/comment events (`wakeOnDemand: true` is unchanged).

## Acceptance gate

- Visible commit-mix shift to `framework:` and EA-build commits (1003/1004) over the throttle window.
- Step 25 PASS verdict (or FAIL-with-fix-list) lands as `decisions/2026-05-XX_phase2_acceptance.md` ADR with QT verdict text inline.
- Pipeline-Operator emits first 1003/1004 baseline backtest report on D1 PASS.
- DL-034 snap-back review at 2026-05-04: either cleanly close the throttle window or extend with explicit reason + new DL-NNN.

## Reverse condition

- T6 incident requiring CEO/DevOps emergency response (auto-snap-back to default mode for affected agents).
- QT review surfaces a fix-list larger than 24h of CTO/Development capacity (re-plan window, file fresh DL-NNN).
- OWNER directive overrides (always wins).

## Boundaries reaffirmed

- Charter values, hard rules, T6 isolation, brand tokens — unchanged.
- Wave-0/1 charter shape — unchanged. This DL adjusts heartbeat *allocation*, not org structure.
- DL-029 source-queue ordering — unchanged. Research continues source-queue work; only Strategy-Card landings are deferred.

## Cross-references

- `docs/ops/CEO_DIRECTIVE_PHASE2_CLOSE_2026-05-01.md` — directive deliverables D1..D5
- `docs/ops/PHASE2_FRAMEWORK_CLOSEOUT_AUDIT_2026-05-01.md` — disk-state evidence for Phase 2 progress + commit-mix
- `framework/V5_FRAMEWORK_DESIGN.md` § Implementation Order — Step 25 line that the acceptance ADR will backlink
- `paperclip/governance/org_chart.md` § "Live Roster (Board Advisor audit, 2026-05-01)" — roster context
- DL-023 (`2026-04-27_ceo_autonomy_waiver_v2.md`) — authority basis (class 4: internal process choices)
- DL-024 (`2026-04-27_ceo_scheduled_heartbeat.md`) — precedent for CEO heartbeat-cadence directive under DL-023
