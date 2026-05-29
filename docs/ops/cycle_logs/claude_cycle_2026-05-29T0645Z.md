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

## Q04 Daemon Restart — CONFIRMED (but FIFTH ROOT CAUSE still active)

Q04 was producing `status=failed/INFRA_FAIL` items until ~06:32Z. From 06:37Z onward, work items complete with `status=done` — daemon restart happened between 06:32Z and 06:37Z, confirmed effective.

**CORRECTION — these are still INFRA failures, not strategy verdicts.** All `done` items show `exit_code=1, trades=0, pf_net=null, summary_path=null` across all 3 folds (completing in ~2s). Root cause (FIFTH): `q04_walkforward.py:~153` passes `-CommissionPerLot 7.0` to `run_smoke.ps1`, which uses `[CmdletBinding()]` but does NOT declare that parameter → PowerShell aborts before MT5 starts → exit 1 → no trades.

OWNER decision (commit `b18a8b21` in C:/QM/repo): commission = **$7.00/lot round-trip** (spec authoritative). Full diagnosis: `docs/ops/Q04_FIFTH_ROOT_CAUSE_commission_mechanism_2026-05-29.md` (C:/QM/repo).

**Action taken:** created Codex ops_issue task `f308fe3f` (TODO → routed to codex) to wire the $7/lot commission into Q04 backtests (Option A: write Q04 tester groups file + declare -GroupsFile in run_smoke.ps1; remove -CommissionPerLot).

## QM5_10260 Queue State

QM5_10260 (cieslak-fomc-cycle-idx, NDX.DWX M30) has 51 Q04 INFRA_FAIL items from 2026-05-28T18:04Z — all pre-daemon-restart. It also has Q03 PASS on both NDX.DWX and WS30.DWX. **No pending Q04 items.** The pump needs to create new Q04 work items from these Q03 PASSes — this should happen automatically once the pump cycles. No manual intervention needed unless pump does not re-enqueue within 2 cycles.

## Risks / Blockers
- Q04 FIFTH ROOT CAUSE still active: all `done/FAIL trades=0` items are INFRA failures until Codex fixes commission wiring (task f308fe3f)
- 3934 pre-fix INFRA_FAIL Q04 items will need re-queue once commission wiring is fixed
- `farmctl pipeline` fix is in claude-orchestration-1 worktree only (not on main); Codex should merge
- Gemini sandbox-verifier task (f5043456) has 5 stale releases — Gemini cannot read MP4 files; will keep recycling
- §10c pump bug (p2_pass_no_p3=127) blocked on OWNER PAT refresh + push to main

## Next
- Codex: implement Q04 commission wiring (task f308fe3f) — this is the current pipeline critical path
- OWNER: once Q04 commission wired, bulk re-queue all INFRA_FAIL Q04 items to get real verdicts
- Codex: port farmctl pipeline fix from this worktree to main
- First Q04 PASS (with real commission-adjusted PF > 1.0 across all 3 folds) is the key milestone
