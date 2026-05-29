# Claude orchestration cycle — 2026-05-29 0000Z

## Inputs

- `farmctl health` — `overall=FAIL`, 4 FAIL / 0 WARN / 15 OK (checked_at 2026-05-29T00:00:19Z)
- `agent_router status` — claude/codex/gemini all `running=0`
- `agent_router run --min-ready-strategy-cards 5 --max-routes 5` — `replenish.frozen=true`, `reason="generic_research_replenishment_frozen_edge_lab_primary_2026-05-22"`, `ready_strategy_cards=0`, `routes=[{reason: "no_routable_task"}]`
- `agent_router route-many --max-routes 5` — `no_routable_task`
- `agent_router list-tasks --agent claude` — `[]` (empty)

## Health deltas vs 2026-05-28 2345Z (5e738694)

- `codex_review_fail_rate_1h`: **WARN 0.5 (1/4) → OK 1.0 (1/1, low-volume carve-out)**. Numerator unchanged at 1 (QM5_10490 still the lone system-class FAIL), denominator collapsed 4→1 as the Codex RECYCLE sweep tail finished aging out of the 1h window. Bare rate is technically 1.0 but the `low volume` exemption flips the check OK. Threshold 0.8 not engaged. Not a fresh defect — pure denominator-decay continuation; the 2330Z numerator uptick has fully reverted to baseline.
- `p2_pass_no_p3`: FAIL 127 unchanged — **17th consecutive cycle** gated on 0bf5dc87 §10c Pump promotion-path fix being merged to main with main-reachable evidence (Codex code, not mine to write or self-approve).
- `unbuilt_cards_count`: FAIL 792 unchanged — **16th consecutive flat cycle**.
- `unenqueued_eas_count`: FAIL 17 unchanged.
- `p_pass_stagnation`: FAIL 0 Q03+ PASS verdicts in last 12h — Q04 commission gate still blocking all promotion (**15th flat cycle**).
- `pump_task_lastresult`: OK exit 0 — Pump runs are succeeding mechanically, but §10c logic still defective on main.
- `mt5_dispatch_idle`: 326→321 pending (-5, essentially flat), 6 active unchanged, 15→11 pwsh workers (-4), 16 fresh work_item logs. Tester drain slightly outpacing pump.
- `mt5_worker_saturation`: OK 10/10 daemons alive.
- `codex_zero_activity`: 4→3 codex (-1), 2→3 pending (+1). Codex daemon still active.
- `disk_free_gb`: D: 56.3 GB unchanged.
- `quota_snapshot_fresh`: codex=94s, claude=34s. Both fresh.
- `codex_auth_broken`: 228.0h→228.2h (+0.2h) clean.

Net: 4 FAIL / 0 WARN / 15 OK — same four structural FAILs, WARN cleared as the rate-1h check fell back into low-volume OK territory.

## Q04 commission gate

Fix commits 26fb4fdb + 17037661 land on `origin/main` HEAD e6e29442 but the `terminal_worker` daemons are still running the pre-fix code path — **15th consecutive cycle this is flagged**. Restart is OWNER-side (`QM_StrategyFarm_TerminalWorkers_AT_STARTUP` per VPS reboot runbook; or process kill + relaunch via `start_terminal_workers.py --dedupe`). Until restart: every Q04 attempt continues to write `INFRA_FAIL` regardless of EA quality, and no EA can promote past Q03 (0 Q04 PASSes lifetime).

## QM5_10260 queue (front-line EA)

Unchanged from 2345Z. By `phase / status / verdict`:

- Q02 done: 3 PASS / 7 FAIL / 15 INFRA_FAIL (25 rows)
- Q02 failed: 1 INFRA_FAIL
- Q03 done: 102 PASS
- Q04 failed: 102 INFRA_FAIL

Total 230 work_items, 0 PENDING, 0 RUNNING. Q04 INFRA_FAIL is pipeline-wide, not EA-specific.

## Router slate composition

Unchanged from 2345Z:

- 19× `build_ea` RECYCLE, unassigned — QM5_11895–11916 false-PASS sweep (Codex's queue per gemini-code hard rule)
- 8× `build_ea` PIPELINE, unassigned
- 1× `build_ea` PIPELINE, codex
- 2× `build_ea` PASSED, codex
- 6× `research_strategy` REVIEW, gemini
- 2× `ops_issue` PASSED, codex
- 2× `ops_issue` RECYCLE, codex — 0bf5dc87 §10c Pump fix + 3854cd8b

No claude-assigned rows in any state. `list-tasks --agent claude` returns `[]`.

## Autonomous remediation taken

None. Every open item routes to Codex or OWNER:

- 0bf5dc87 §10c Pump fix → Codex code I don't write or self-approve. Must redo with main-reachable evidence (prior evidence trapped in `codex-orchestration-1` worktree 173 commits behind `origin/main` on legacy P-pipeline).
- 3854cd8b RECYCLE → Codex's pickup.
- 19× `build_ea` RECYCLE → Codex's queue per gemini-code hard rule (Codex review mandatory before acceptance).
- Q04 commission gate → OWNER-side `terminal_worker` restart.
- `unbuilt_cards_count` emitter audit (792 flat) → OWNER/Codex.
- `codex_review_fail_rate_1h` → low-volume carve-out flipped check back to OK; 2330Z numerator uptick fully reverted. No action needed.

## OWNER next priority

1. **`terminal_worker` daemon restart** to pick up 26fb4fdb + 17037661 (single biggest pipeline unblocker — 0 Q04 PASSes lifetime).
2. **Codex re-pick 0bf5dc87 §10c** with main-reachable evidence (unblocks `p2_pass_no_p3=127`).
3. **Codex re-pick 3854cd8b** RECYCLE.
4. **Codex re-do 19× `build_ea` RECYCLE** with full artifact set (.ex5 + sets/ + smoke evidence, not .mq5 alone).
5. **`unbuilt_cards_count` emitter audit** (792 flat for 16 cycles — likely a stale denominator, not 792 real rebuild candidates).
