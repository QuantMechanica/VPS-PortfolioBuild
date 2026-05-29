# Claude Orchestration Cycle — 2026-05-29 2332Z (true UTC)

## Health snapshot

| Check | Status | Value | Detail |
|---|---|---|---|
| unbuilt_cards_count | **FAIL** | 661 | Unchanged; pump emits ≤2 auto-build tasks/cycle; structural backlog |
| cards_ready_stagnation | WARN | 1 | 1 actionable source; next resume-mining cycle should flip back to active |
| source_pool_drained | WARN | 9 | 9 pending sources (threshold 10) |
| disk_free_gb | WARN | 18.7 GiB | STABLE (unchanged vs prior cycle); 0.1 GiB above hard floor; rotate D: logs >30d NOW |
| mt5_worker_saturation | OK | 10/10 | All terminal worker daemons alive |
| mt5_dispatch_idle | OK | 317 | 317 pending, 4 active, 19 pwsh workers |
| p_pass_stagnation | OK | 74 | 74 Q03+ PASS last 6h (throughput OK) |
| p2_pass_no_p3 | OK | 0 | 0 pending promotion |
| codex_auth_broken | OK | 0 | No 401 errors; auth age 11.5h |
| **Overall** | **DEGRADED** | 1 FAIL / 3 WARN / 16 OK | |

## Router

- `run --min-ready-strategy-cards 5 --max-routes 5` → **no_routable_task** (replenish frozen)
- `route-many --max-routes 5` → **no_routable_task**
- Replenish: **FROZEN** (`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`), 1017 ready cards, 2674 approved, 83 pipeline EAs

## Claude tasks

- **IN_PROGRESS**: 0 — nothing to work on this cycle

## Build pipeline

- 9 PIPELINE + 19 RECYCLE + 2 PASSED build_ea (unassigned) + 1 Codex PIPELINE build_ea

## QM5_10260 queue

- **CONFIRMED ELIMINATED**: 0 work_items for ea_id=10260 (43rd+ consecutive cycle clean)

## Codex 9a8a422f

- Status: IN_PROGRESS; PAT still blocks git push — headless credential prompt disabled

## APPROVED unassigned ops_issues (3)

| ID | Priority | Status | Note |
|---|---|---|---|
| 0618055e | p20 | Waiting | Routes after 9a8a422f completes (§10c P3 promoter profit-check) |
| af9d128a | p15 | **STALE** | Superseded by Q08 fix 5e574572/b8c4bcd2; **OWNER: close** |
| 43ca200e | p10 | Waiting | **OWNER: close after 9a8a422f PASSED** |

## Gemini research_strategy

- 6 APPROVED, gemini running=0; pump still blocked

## OWNER actions required

1. **DISK FREE CRITICAL** — D: 18.7 GiB; 0.1 GiB above hard floor; rotate D: logs >30d; ACT NOW
2. **PAT REFRESH CRITICAL** — unblocks 9a8a422f + 0618055e
3. **CLOSE af9d128a** — STALE; Q08 already fixed via 5e574572/b8c4bcd2
4. **CLOSE 43ca200e** — after 9a8a422f PASSED
5. **Pump Gemini tasks** — 6 APPROVED research_strategy awaiting dispatch
6. **QM5_10440 NDX Q08 retry** — outstanding from prior cycles
7. **Q04 commission calibration** — f308fe3f (backtests still gross-of-costs)
