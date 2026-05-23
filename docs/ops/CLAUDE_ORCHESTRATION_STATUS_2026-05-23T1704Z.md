# Claude Orchestration Status 2026-05-23T17:04Z

Status: IDLE — no IN_PROGRESS claude tasks; blockers unchanged from prior cycles

## Router outcome

- `agent_router.py status` — 2 Gemini tasks IN_PROGRESS, 3 TODO (unroutable at Gemini
  capacity 2/2), 0 Claude tasks.
- `agent_router.py run --min-ready-strategy-cards 5 --max-routes 5` — research
  replenishment still frozen (`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`);
  0 ready approved cards (2192 approved, all blocked — schema blocker persists). One TODO
  task cannot route (`no_available_agent`); all TODO tasks require `source_discovery +
  video-analysis` (Gemini-only skills).
- `agent_router.py list-tasks --agent claude` — empty; no tasks to process this cycle.

## Health snapshot

`farmctl health` overall: **FAIL** (2 FAILs, 1 WARN)

| Check | Status | Detail |
|---|---|---|
| `codex_review_fail_rate_1h` | **FAIL** | 2/14 system-class FAILs across 2 EAs |
| `p_pass_stagnation` | **FAIL** | 0 Q03+ PASS verdicts in 12h |
| `unenqueued_eas_count` | WARN | 10 EAs without Q02 work_items |
| `mt5_worker_saturation` | OK | 10/10 workers alive (T1–T10) |
| `mt5_dispatch_idle` | OK | 1 pending (low queue) |
| `disk_free_gb` | OK | 154.4 GB free |
| `codex_zero_activity` | OK | 3 codex tasks, 0 pending |
| `source_pool_drained` | OK | 12 pending sources |

## QM5_10260 queue state

No work_items in DB (queue empty), no agent_tasks. EA is idle — the cieslak-fomc-cycle-idx
per-tick EMA perf rework that Codex was APPROVED to fix has not yet produced a re-enqueue.
Until that rework lands and an `enqueue-backtest` runs, QM5_10260 will continue producing 0
Q02 attempts. Not a strategy rejection — a perf/infra gap.

## Active backtests this cycle

| EA | Phase | Active items | Pending items |
|---|---|---|---|
| QM5_10019 | Q02 | 2 | 0 |
| QM5_10020 | Q02 | 2 | 0 |
| QM5_10021 | Q02 | 1 | 1 |

All three are at Q02. No EAs have advanced past Q02 in this cycle, consistent with
`p_pass_stagnation` FAIL.

## Deltas since 1645Z cycle

- **Approved cards**: 2175 → 2192 (+17). Gemini is generating cards from the "EA - FTMO -
  Trading Course" Dropbox extraction. All remain blocked (schema blocker on `agents/board-advisor`
  not merged to main).
- **`unenqueued_eas_count`**: 9 → 10 (one more EA built without Q02 work items).
- **`mt5_dispatch_idle`**: 2 pending → 1 pending (one backtest dispatched since 1645Z).
- **QM5_10005 INFRA_FAIL**: 4 new failures (ex5_missing). Cause confirmed:
  `C:\QM\repo\framework\EAs\QM5_10005_ff-profigenics-channel\QM5_10005_ff-profigenics-channel.ex5`
  does not exist. Build blocked by KillSwitch naming defect (same root as QM5_10000 batch).

## Standing blockers (no change required from Claude this cycle)

| Blocker | Owner | Description |
|---|---|---|
| KillSwitch naming defect | Codex | `g_qm_ks_initialized` double-defined in `QM_KillSwitchKS.mqh + QM_KillSwitch.mqh`; blocks QM5_10000, QM5_10005 + others; Codex must rename in KS file |
| Schema blocker unmerged | OWNER | Fix on `agents/board-advisor` (357f93bf); 2192 approved cards blocked; OWNER must merge to unblock |
| QM5_10260 perf rework | Codex | Per-tick EMA optimization not yet done; EA has 0 work_items, stuck; needs Codex rework + re-enqueue |
| Edge Lab INFRA_FAIL | Codex | QM5_10717 + QM5_10718 INFRA_FAIL Q02 on EURUSD.DWX; no agent task assigned yet |
| Gemini at capacity | System | 2/2 slots used; 3 TODO video-extraction tasks queued; will unblock when current tasks complete |
