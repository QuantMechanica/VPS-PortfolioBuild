# Claude Orchestration Cycle — 2026-05-29T0645Z

## Status
ACTED — Fixed `farmctl pipeline` crash; confirmed Q04 daemon restart working.

## Health
- Overall: FAIL (4 checks failing)
- `p2_pass_no_p3` FAIL: 127 P2-PASS work_items without P3 promotion (§10c pump bug, push blocked by HTTP 401)
- `unbuilt_cards_count` FAIL: 792 approved cards without .ex5/auto-build task
- `unenqueued_eas_count` FAIL: 16 reviewed built EAs with no P2 work_items
- `p_pass_stagnation` FAIL: 0 P3+ PASS verdicts in last 12h (front line at Q04, no PASS yet)
- All other checks: OK
- D: free: 52.4 GB, mt5 workers: 10/10 alive, dispatch: 387 pending, 6 active, 13 pwsh workers

## Queue
- Q02: 3111 done, 656 failed, 249 pending, 1 active
- Q03: 4591 done, 191 failed, 133 pending, 5 active
- Q04: 7 done (strategy FAIL, post-daemon-restart), 3934 failed (pre-fix INFRA_FAIL), 2 pending
- P2 (legacy): 442 done, 4 failed
- Replenishment frozen (Edge Lab primary, per 2026-05-22 rule); 0 ready approved cards

## Router
- `run`: no routes (no routable tasks)
- `route-many`: no routes
- Claude IN_PROGRESS tasks: none
- Gemini tasks: 4 already closed to APPROVED/RECYCLE at 06:49-06:50Z (prior cycle or auto-process); 2 remain in REVIEW (aac25e1f "When Do I Trade" — awaiting Gemini; f5043456 sandbox-verifier — 5 stale releases, Gemini can't read MP4)

## Key Action — farmctl pipeline crash fix

**Root cause:** `farmctl.py:1093` in `pipeline_view()` did `(payload.get("build_result") or {}).get("smoke_result")`. When `build_result` is a string (as in some legacy task rows), the truthy string bypassed the `or {}` fallback and `.get()` threw `AttributeError: 'str' object has no attribute 'get'`.

**Fix:** Guarded with `isinstance` check — `(payload.get("build_result") if isinstance(payload.get("build_result"), dict) else {}).get("smoke_result")`.

**Effect:** `farmctl pipeline` now returns 440 EAs cleanly. Fix applies to this worktree only; Codex should port to `main`.

## Q04 Daemon Restart — CONFIRMED

Q04 was producing INFRA_FAIL items until ~06:32Z. From 06:37Z onward, work items complete with proper strategy verdicts (e.g., QM5_10569 EURJPY FAIL, QM5_10513 USDJPY FAIL, QM5_10559 EURUSD FAIL). Daemon restart happened between 06:32Z and 06:37Z — the OWNER-controlled restart from last cycle is confirmed effective.

**Current Q04 FAIL pattern:** `trades=0, pf_net=None, exit_code=1` across all 3 folds for all 3 active EAs (QM5_10513/10559/10569). Infrastructure is fine; these are strategy quality failures (no trades generated in OOS windows). Expected behavior.

## QM5_10260 Queue State

QM5_10260 (cieslak-fomc-cycle-idx, NDX.DWX M30) has 51 Q04 INFRA_FAIL items from 2026-05-28T18:04Z — all pre-daemon-restart. It also has Q03 PASS on both NDX.DWX and WS30.DWX. **No pending Q04 items.** The pump needs to create new Q04 work items from these Q03 PASSes — this should happen automatically once the pump cycles. No manual intervention needed unless pump does not re-enqueue within 2 cycles.

## Risks / Blockers
- 3934 Q04 INFRA_FAIL items (pre-fix) still not re-queued; pump is creating new Q04 items from Q03 PASS gradually (2 pending observed at 06:47Z)
- `farmctl pipeline` fix is in claude-orchestration-1 worktree only (not on main); Codex should merge
- Gemini sandbox-verifier task (f5043456) has 5 stale releases — Gemini cannot read MP4 files in its sandbox; task will keep recycling unless task is restructured or approach changes
- §10c pump bug (p2_pass_no_p3=127) blocked on OWNER PAT refresh + push to main

## Next
- Monitor Q04 PASS rate — first Q04 PASS will be the milestone
- OWNER: bulk re-queue of pre-fix INFRA_FAIL Q04 items if pump is too slow (or farmctl enqueue-backtest)
- Codex: port farmctl pipeline fix from this worktree to main
- Gemini sandbox MP4 issue: consider closing f5043456 as RECYCLE with explanation if no progress
