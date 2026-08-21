# APPROVED-limbo reconcile + REVIEW-build settlement — 2026-08-21

**Operator:** Claude (board-advisor worktree) · **Scope:** agent-router `agent_tasks` lane
**State DB:** `D:\QM\strategy_farm\state\farm_state.sqlite`

## Status

- Step 2 (enqueue genuinely-droppable handoffs): **0 enqueued** — none of the 11 are
  cleanly handoff-ready via an authorized canonical path (root cause below).
- Step 3 (`reconcile-exits --state APPROVED --apply`): **applied, 267 moved**
  (207 APPROVED→PASSED, 60 APPROVED→PIPELINE). RECYCLE (556) **not** reconciled.
- Step 4 (10 `build_ea` still in REVIEW): **8 settled** (7 RECYCLE, 1 BLOCKED),
  2 left in REVIEW (need a review dispatch).

## Root cause the 11 never entered the pipeline

The agent-router `build_ea` lane (`agent_tasks`) is a **different table** from the
farmctl pipeline lane (`tasks` / `work_items`). A fresh Q02 for a never-tested EA is
seeded by the canonical never-tested sweeper
`tools/strategy_farm/sweep_enqueue_built_eas.py` (Part 1), which **only enqueues EAs
whose `framework/registry/ea_id_registry.csv` status == `active`**. Neither
`farmctl enqueue-backtest --review-task-id …` (needs a `tasks`-table `ea_review`
APPROVE_FOR_BACKTEST predecessor these EAs never had), nor `--ea … --phase Q02`
(cascade-only; Q02 is not a cascade phase), nor `seed-fresh-q02` (needs a terminal
source work_item) can seed these. There is **no farmctl subcommand to flip
`pending→active`**, and hand-editing `ea_id_registry.csv` is explicitly forbidden
(`farmctl.py:10769` "never hand-edit or append …"). Registry activation is therefore a
governed, admission-adjacent step (Claude's call), not an operator action available to
this worker. Canonical-sweep dry-run over the 6 ea_id rows: `enqueued=0`,
skip reasons `registry_status=pending:4`, `registry_status=None:1`, `no_ex5:1`.

## The 11 — diagnosis (one line each)

| task | ea | dir / mq5 / ex5 / sets | magic rows | reg status | work_items | finding |
|---|---|---|---|---|---|---|
| abfb4871 (claude) | QM5_11533 | yes/yes/yes/1 | active (1) | **pending** | 0 | Fully built + magic-allocated + CODEX_APPROVED; **only blocker = registry not `active`.** NOT a droppable enqueue — needs governed activation. |
| e26b6273 (claude) | QM5_11563 | yes/yes/yes/3 | active (3) | **pending** | 0 | Same: built + CODEX_APPROVED; blocked on `pending→active`. |
| 5ea0928f (claude) | QM5_11539 | yes/yes/yes/2 | active (2) | **pending** | 0 | Same: built + CODEX_APPROVED; blocked on `pending→active`. |
| 985081a7 (claude) | QM5_11537 | yes/yes/yes/2 | active (2) | **pending** | 0 | Same: built + CODEX_APPROVED; blocked on `pending→active`. |
| eeb21d12 (gemini) | QM5_1354 | yes/yes/yes/8 | active (8) | **NO ROW** | 0 | Built + magic-allocated + CLAUDE REVIEW PASS, but **no `ea_id_registry` row at all** → needs governed registration + activation. |
| 111e7bc2 (gemini) | QM5_30001 | yes/yes/**no**/0 | active (3) | active | 0 | **Genuinely blocked = build REFUSAL** (bollinger grid/martingale, Edge-Lab charter). No ex5/setfiles by design. Must never enter pipeline. |
| b8c2e67c (gemini) | QM5_21514 | — | — | — | 4 | Not a fresh handoff — EA already in funnel: Q02 PASS→Q04 PASS/INFRA→**Q05 FAIL**. No action. |
| 9ad6d9c0 (gemini) | 23× Brent→XTI | — | — | — | (batch) | Multi-EA XBRUSD→XTIUSD reroute, already enqueued + processed (27 XTIUSD Q02 PASS per verdict). Not a single build. No action. |
| 141b8518 (gemini) | QM5_20177 | — | — | — | 7 | Guarded Q02 canary `af79d508` was enqueued **and ran** (Q02 ZERO_TRADES); prior 6 rows DRAFT_DEFECT. Already in funnel. No action. |
| c162c123 (gemini) | 8-EA repair | — | — | — | mixed | Batch repair, not a single build. 7/8 in funnel (10648 Q04 FAIL, 10649 Q04 pending, 10973 Q02 PASS, 11897 Q04 FAIL, …); **QM5_1355 has 0 work_items** (built, ex5 present, but **no `ea_id_registry` row**) → same activation gap. |
| 661a36b1 (gemini) | QM5_21001 | — | — | — | 11 | Q15 optimization challenger, already deep in funnel (Q15 CHALLENGER_SPAWNED, reached Q06 FAIL). No action. |

**The 5 no-ea_id rows** are, in order: a single-EA finish task already in-funnel (21514),
a 23-EA batch reroute already processed, a requalify task whose canary already ran, an
8-EA repair batch (mostly in-funnel; 1355 outstanding), and a Q15 challenger already in-
funnel. None is a dropped single-EA build handoff.

## Step 2 — enqueued

Nothing. Every ea_id row is either (a) built but blocked on governed registry activation
(11533/11563/11539/11537 = `pending`; 1354 and 1355 = no registry row), or (b) a build
refusal (30001). I did **not** hand-edit the registry and did **not** force activation
(admission is Claude's call; ROT-adjacent). Canonical sweep was run **dry-run only**
(`--ea QM5_11533,…,QM5_30001`, no `--apply`) as the diagnostic; it mutated no DB state
(its report JSON `D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json` was
rewritten with an `apply:false`, `--ea`-scoped snapshot — the hourly task regenerates it).

## Step 3 — reconcile applied

`python tools/strategy_farm/agent_router.py reconcile-exits --state APPROVED --apply`
→ `moved_count: 267`, `APPROVED→PASSED: 207`, `APPROVED→PIPELINE: 60`, `left_in_place: {}`.
APPROVED pool now 0. RECYCLE (556) not in scope, not touched.

**Residual (PIPELINE label ahead of reality):** the blanket relabel moved all 60 build_ea
to PIPELINE, including the 6 that carry **zero work_items and are not running**: QM5_11533,
QM5_11563, QM5_11539, QM5_11537, QM5_1354 (activation-blocked) and QM5_30001 (refusal).
Their PIPELINE state becomes truthful only once Claude activates them (pending→active +
sweep); 30001 should be BLOCKED. This is documented here rather than silently laundered.

## Step 4 — 10 REVIEW build_ea settled

Completed reviews existed for the 8 gemini builds (Claude review closed 2026-08-17T20:22,
evidence `docs/ops/evidence/2026-08-17_point_1_11_e3_enforced_19_rows_held_9_reviews_closed.md`);
their `review_ea` tasks closed RECYCLE/BLOCKED but the `build_ea` tasks were orphaned in
REVIEW. Propagated the review outcome onto each build task:

| build task | ea | → state | review verdict (evidence) |
|---|---|---|---|
| 1da33eb5 | QM5_33006 | RECYCLE | 39c6a58d: pending stops fill through blackouts; rework |
| 5b130e06 | QM5_33007 | RECYCLE | 85fd5256: news suppresses Friday/strategy exits, card contracts unimplemented |
| 4b97cf9e | QM5_33008 | RECYCLE | da921b20: RVI formula and trailing-R diverge from card |
| f9a8b8f7 | QM5_34001 | RECYCLE | 73eb18d9: 44 strict-build failures, card-undefined Kalman state, invented ATR TP |
| d5a96505 | QM5_34003 | RECYCLE | 91dfb3c7: 42 set-header failures, misspelled trade callback |
| e48c6a6c | QM5_34004 | RECYCLE | 33203a5c: build uncommitted (0 tracked files), invented Step-MA/ATR fallbacks |
| a0f709cd | QM5_34005 | RECYCLE | feb8cb93: build uncommitted (0 tracked files), card-undefined parabolic trail |
| 82a3b44b | QM5_34007 | **BLOCKED** | 4309d167: FAIL upheld, not repairable — 10s/5s signals not tester-representable; HF FX lacks commission evidence |

These 7 RECYCLE rows are the **only** additions to the RECYCLE pool (556→563). They were
not rebuilt and `reconcile-exits --state RECYCLE` was never run — the original 556 are
untouched.

**Left in REVIEW (2 codex tasks — need a review dispatch, no current completed review):**
- 977c8c04 / QM5_1673 (sperandeo-tvii-trendline-failure-h4): only completed review is a
  **stale RECYCLE from 2026-07-19** (found "only .mq5, no .ex5") that predates the
  2026-08-17 rebuild; EA now has ex5 + 14 setfiles + BUILD PASS (commit a0bb4bf42).
  Needs a fresh review of the rebuilt binary.
- 5d5cc9f6 / QM5_41002 (spread-gate repair): no review; build self-reports
  REPAIR_BUILD_PASS (commit 48793e687) but a claim hit
  `governed allocator dirty_registry_abort` (magic rows for slots 0..2 absent). Needs a
  review dispatch and likely a magic-registry repair first.

## Open items / recommended next steps

1. **Activation decision for the pending-built cohort** (Claude): 11533/11563/11539/11537
   are fully built + magic-active + review-clean, blocked only on `ea_id_registry`
   `pending→active`; 1354 and 1355 lack a registry row entirely. They sit in a 36-EA
   `pending` cohort. If Claude activates them (governed path), the canonical sweep will
   enqueue them and their PIPELINE label becomes truthful.
2. **QM5_30001** should be moved to a terminal BLOCKED (refused build; currently PIPELINE).
3. **Dispatch reviews** for QM5_1673 (fresh, post-rebuild) and QM5_41002 (after magic-
   registry repair).
4. Do NOT `reconcile-exits --state RECYCLE` until Codex task 57faa292 hardens the build
   gates (six code-gen defect classes).

## Refused / not done

- Did **not** hand-edit `ea_id_registry.csv` or force `pending→active` (governed,
  admission-adjacent, Claude's call; no canonical operator command exists).
- Did **not** approve any build (Claude's call).
- Did **not** touch the 556 RECYCLE rows, run RECYCLE reconcile, start the factory,
  launch backtests, or touch T_Live.
