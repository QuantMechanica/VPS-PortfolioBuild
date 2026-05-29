# Claude orchestration cycle — 2026-05-29 0030Z

## Inputs

- `farmctl health` — `overall=FAIL`, 5 FAIL / 0 WARN / 14 OK (checked_at 2026-05-29T00:30:24Z)
- `agent_router status` — claude/codex/gemini all `running=0`
- `agent_router run --min-ready-strategy-cards 5 --max-routes 5` — `replenish.frozen=true`, `reason="generic_research_replenishment_frozen_edge_lab_primary_2026-05-22"`, `ready_strategy_cards=0`, `routes=[{reason: "no_routable_task"}]`
- `agent_router route-many --max-routes 5` — `no_routable_task`
- `agent_router list-tasks --agent claude` — `[]` (empty)

## Health deltas vs 2026-05-29 0015Z (6ae40eaa)

- `codex_review_fail_rate_1h`: **FAIL 1.0 (3/5 across 3 EAs) → FAIL 1.0 (2/4 across 2 EAs)**. Numerator down 3→2 (one EA aged out of 1h window), denominator down 4 (one row aged out). Rate still 100%, threshold 0.8 still breached. Per the check's action_hint, system-class FAILs (framework_corset / magic_registry / forbidden_grep) point at Codex bad code or schema drift, not strategy quality. **Trend reversal**: numerator decay (3→2) suggests no fresh system-class FAILs in the past 15 min, but the underlying defect remains — at low denominators a single new failure flips this back up. Investigation of which EAs/verdicts is Codex's queue per gemini-code hard rule.
- `p2_pass_no_p3`: FAIL 127 unchanged — **19th consecutive cycle** gated on 0bf5dc87 §10c Pump promotion-path fix being merged to main with main-reachable evidence (Codex code, not mine to write or self-approve).
- `unbuilt_cards_count`: FAIL 792 unchanged — **18th consecutive flat cycle**.
- `unenqueued_eas_count`: FAIL 17 unchanged.
- `p_pass_stagnation`: FAIL 0 Q03+ PASS verdicts in last 12h — Q04 commission gate still blocking all promotion (**17th flat cycle**).
- `pump_task_lastresult`: OK exit 0 — Pump runs are succeeding mechanically, but §10c logic still defective on main.
- `mt5_dispatch_idle`: 369→468 pending (+99, **largest single-cycle jump on record**), 7→9 active (+2), 17→20 pwsh workers (+3), 19 fresh work_item logs (+5). Pump outpacing tester drain — queue grew ~27% in one cycle and ~45% in two cycles.
- `mt5_worker_saturation`: OK 10/10 daemons alive.
- `codex_zero_activity`: 6 codex unchanged, 5→2 pending (-3). Codex daemon still active.
- `disk_free_gb`: D: 56.2 → 55.9 GB (-0.3, modest decline tracking pending-queue growth).
- `quota_snapshot_fresh`: codex=98s, claude=38s. Both fresh.
- `codex_auth_broken`: 228.5h→228.7h (+0.2h) clean.

Net: 5 FAIL / 0 WARN / 14 OK — same five structural FAILs; `codex_review_fail_rate_1h` numerator decayed 3→2 but still over threshold; pending-queue growth is the only fresh signal worth flagging.

## Q04 commission gate

Fix commits 26fb4fdb + 17037661 land on `origin/main` HEAD e6e29442 but the `terminal_worker` daemons are still running the pre-fix code path — **17th consecutive cycle this is flagged**. Restart is OWNER-side (`QM_StrategyFarm_TerminalWorkers_AT_STARTUP` per VPS reboot runbook; or process kill + relaunch via `start_terminal_workers.py --dedupe`). Until restart: every Q04 attempt continues to write `INFRA_FAIL` regardless of EA quality, and no EA can promote past Q03 (0 Q04 PASSes lifetime).

## QM5_10260 queue (front-line EA)

Unchanged from 0015Z. By `phase / status / verdict`:

- Q02 done: 3 PASS / 7 FAIL / 15 INFRA_FAIL (25 rows)
- Q02 failed: 1 INFRA_FAIL
- Q03 done: 102 PASS
- Q04 failed: 102 INFRA_FAIL

Total 230 work_items, 0 PENDING, 0 RUNNING. Q04 INFRA_FAIL is pipeline-wide, not EA-specific.

## Router slate composition

Unchanged from 0015Z:

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
- `codex_review_fail_rate_1h` 0015Z→0030Z partial decay (3→2 numerator) — still over threshold, no fresh defect this cycle but defect still latent; Codex review queue / investigation. Pointing at which verdict types (framework_corset / magic_registry / forbidden_grep) exceeded single-pass orchestration scope and is itself Codex/Gemini-code domain.
- `mt5_dispatch_idle` +99 pending — biggest single-cycle jump on record; 10/10 daemons alive so this is not worker-side starvation but Pump outpacing tester drain. No autonomous throttle action; tester capacity scales OWNER-side.

## OWNER next priority

1. **`terminal_worker` daemon restart** to pick up 26fb4fdb + 17037661 (single biggest pipeline unblocker — 0 Q04 PASSes lifetime).
2. **Codex re-pick 0bf5dc87 §10c** with main-reachable evidence (unblocks `p2_pass_no_p3=127`).
3. **Codex re-pick 3854cd8b** RECYCLE.
4. **Codex re-do 19× `build_ea` RECYCLE** with full artifact set (.ex5 + sets/ + smoke evidence, not .mq5 alone).
5. **`unbuilt_cards_count` emitter audit** (792 flat for 18 cycles — likely a stale denominator, not 792 real rebuild candidates).
6. **`codex_review_fail_rate_1h` triage** — still 2 distinct EAs system-FAILed in the last hour at 100% rate; defect latent even though numerator decayed.
7. **Pending-queue growth watch** — `mt5_dispatch_idle` 272→326→329→326→321→369→468 over 7 cycles (+72% net). If unchecked, queue will exceed worker-drain capacity and stale rows will accumulate.
