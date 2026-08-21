# OWNER is the assignee of the `video_analysis` lane

**Date:** 2026-08-21 · **Author:** Claude (Orchestrator) · **Authority:** OWNER instruction
2026-08-21 ("verdrahte mich als Assignee der video analysis lane")
**Class:** routing infrastructure, verdict-neutral · **Status:** implemented, tested, live

## Why

The routing contract named agy as the video seat from the start — *"video analysis (the one
task only it can do)"*. For this build that is false, and has been since at least 2026-07-12:

- agy has **no native video tool** (self-reported across three clean headless runs).
- The VPS IP is **bot-blocked on YouTube**. Re-confirmed today: fetching a video page from
  this host returns only YouTube's footer, no title, no channel, no duration.

The consequence was not slowness but **invisibility**. A ticket requiring `video_analysis`
was skipped by `required.issubset(capabilities)` without comment, and a skipped ticket looks
exactly like ordinary backlog in every surface. Two OWNER video tickets had already landed on
codex once (2026-07-07) for the same reason.

## What changed

`tools/strategy_farm/agent_router.py`:

1. **`video_analysis` removed from the `gemini` lane.** The rest of gemini's set
   (`code`/`tests`/`repo_edit`) is untouched — that is a separate open OWNER decision after
   the 2026-08-21 agy build wave (49 of 50 reviews negative).
2. **New `owner` lane** in `DEFAULT_AGENT_REGISTRY`: `enabled: False`, `max_parallel: 0`,
   `cost_rank: 99`, capabilities `["video_analysis", "research", "strategy", "review",
   "summary"]`. `AGENT_EXTRA_REQUIRED_CAPABILITIES["owner"] = {"video_analysis"}` and
   `AGENT_TASK_TYPE_LANES["owner"] = ()` put the lane under the existing registry-contract
   test, so a future drift that drops `video_analysis` fails a test instead of going quiet.
3. **`HUMAN_LANES` + a visible hold.** `_human_lane_holder()` names the human lane that alone
   can satisfy a task's requirements; `_record_human_lane_hold()` writes a
   `router_human_lane_hold` marker into the payload and emits a
   `routing_awaiting_human_lane` event; `route_once` reports
   `awaiting_human_lane:<lane>` **ahead of** the generic `no_available_agent`, so an unstaffed
   human lane never reads as "the AI seats are busy".

### The two properties this had to preserve

- **No head-block.** The hold is recorded inside the candidate loop with `continue`;
  `route_once` keeps evaluating lower-priority tasks and still returns `assigned` if anything
  else is routable. The hold is only *reported* when nothing at all could be routed.
- **Queue age and priority untouched.** Like `_record_capability_warning`, the hold updates
  `payload_json` only — never `updated_at`, never `priority`. Repeat ticks are idempotent
  (identical hold returns early), so there is no event spam.

### Why the hold is deliberately narrow

`owner` declares `research`/`strategy`/`review`/`summary` as well, so a normal
`research_strategy` ticket that merely carries the video skill resolves against the lane as a
whole instead of tripping the structural-unroutable path. That breadth creates a trap: without
a guard, *every* ordinary review ticket would be "held for OWNER" whenever the AI seats are
simply at capacity. `_human_lane_holder` therefore only holds when the task actually requires
a capability the human lane **owns** (`AGENT_EXTRA_REQUIRED_CAPABILITIES`). There is a test
for exactly this.

## Tests

`tools/strategy_farm/tests/test_agent_router.py` — **29 passed**.

- `test_video_task_is_held_for_the_owner_human_lane` (new): a `research_strategy` task with
  `required_skills=["video_analysis"]` is NOT assigned, stays `TODO`, gets
  `router_human_lane_hold` + the `routing_awaiting_human_lane` event, decision reason is
  exactly `awaiting_human_lane:owner`; asserts `owner` is declared-but-unstaffed and that
  `video_analysis` is gone from `gemini`.
- `test_ordinary_task_is_not_held_for_the_human_lane` (new): with every AI seat disabled, a
  `review_strategy` task reports the normal reason and carries **no** hold marker.
- `test_missing_governed_capability_fails_loud_and_persists_warning` (updated): now strips
  `video_analysis` from **both** `gemini` and `owner` live rows, so the structural
  `ROUTER_CAPABILITY_UNROUTABLE` contract stays covered for full-drift.
- `test_default_and_live_registry_cover_each_lane_contract` (unchanged, now also covers
  `owner` because it iterates `AGENT_TASK_TYPE_LANES`).

## Live verification

```
python tools/strategy_farm/agent_router.py init
  -> synced: codex, claude, gemini, owner ; contract.ok = true
live agent_registry:
  gemini  enabled=1 max_par=2 [code, tests, repo_edit, research, strategy, source_discovery]
  owner   enabled=0 max_par=0 [video_analysis, research, strategy, review, summary]

enqueue research_strategy --priority 72 --skills video_analysis   -> 4b52f1b2 (TODO)
python tools/strategy_farm/agent_router.py route-many --max-routes 3
  -> {"assigned_agent": null, "reason": "awaiting_human_lane:owner", "task_id": "4b52f1b2..."}
```

Task `4b52f1b2` is the real `OWNER-VID-XAG` ticket (three XAGUSD videos, screening scope). It
supersedes `d2bc5e78`, BLOCKED since 2026-07-06, whose own revisit condition fired when
QM5_13018/XAGUSD took a **Q04 FAIL on 2026-07-19**.

## Rollback

Revert the commit and run `python tools/strategy_farm/agent_router.py init` from the canonical
checkout `C:/QM/repo` (the only authorised registry writer since `9c8f5ab8e`). The live row is
rewritten from `DEFAULT_AGENT_REGISTRY` on every sync, so no manual DB surgery is needed. The
`owner` row would remain in the table but with no lane contract referencing it; delete it only
if a rollback is meant to be permanent.

**Blast radius:** routing only. No gate, verdict, work_item or pipeline behaviour is touched.
The one behavioural change for existing traffic is that a `video_analysis` ticket now reports
`awaiting_human_lane:owner` instead of being silently skipped.

## Docs updated

- `CLAUDE.md` — agy is no longer the video seat; new OWNER lane entry; the commissioning rule
  now routes video to OWNER.
- Vault `02 Org/AI Agent Routing and Role Contracts.md` — registry table + a section on the
  `owner` lane and why declared-but-disabled is the point.
- Vault `12 ToDo/AI ToDos/OWNER Videoanalysen.md` + `OWNER.md` — task id `4b52f1b2` recorded.

## Note on unrelated red tests

`test_execution_contract_lint.py` (4 failures: `calendar_news_expired` vs
`calendar_news_coverage_mismatch` / `calendar_news_source_hash_mismatch`) and
`test_registry_rekey_12784.py` (pinned `.ex5` SHA no longer matches the rebuilt binary) fail
independently of this change — neither imports `agent_router`. They belong to the same class
as `test_real_a02_compile_manifest_loads_when_present`: tests pinned to live artifacts that
other lanes legitimately mutate. `test_execution_contract_lint` additionally showed **2
failures in a broad selection and 4 when run alone**, i.e. it is order-dependent. Flagged, not
fixed here.
