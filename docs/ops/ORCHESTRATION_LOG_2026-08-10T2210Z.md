# Claude Orchestration Cycle Log — 2026-08-10T2210Z

**Session:** agents/claude-orchestration-3

## Tasks worked

`list-tasks --agent claude --state IN_PROGRESS` at cycle start (21:05Z) returned 3
tasks: QM5_1626 (hopwood-bermaui-stoch-h4, build_ea, routed 20:36:32Z, capacity-spilled
from Codex), QM5_1355 (williams-vix-fix-fx-h4, review_ea, routed 20:46:28Z),
QM5_1354 (woodie-cci-dual-h1, review_ea, routed 20:41:27Z). Three more tasks arrived
mid-cycle as capacity freed up (claude's shared pool is fed by all 3 concurrent
orchestration slots' `route-many` calls, not just this session's): QM5_1630
(demark-td-sequential-combo-overlay-h4, review_ea, 21:16:59Z), QM5_1628
(carney-5-0-pattern-h4, review_ea, 21:16:59Z), QM5_20073 (pip-hunter-heiken-ashi-r1-recovery,
build_ea, 21:31:47Z). Two further build_ea tasks (QM5_20074, QM5_20075) arrived after
that; deferred to the next cycle — see "Stopped short of empty queue" below.

No `agent_task:<task_id>` lease implementation actually exists in the fleet (verified:
`tools/strategy_farm/run_agent_orchestration_task.py:114`'s "30-minute spawn lease"
text has no backing code anywhere in `tools/strategy_farm/`). Improvised a file lock at
`D:/QM/strategy_farm/locks/agent_task_<task_id>.lock` for this session's own 6 tasks
(claimed before work, released after); this protects against this session re-entering
but not against a sibling slot racing the same task — see the QM5_1626 finding below,
which is exactly that race.

### QM5_1626 — built against canonical `C:/QM/repo`, then found duplicated by a sibling slot

Built cleanly per SOP ([[project_qm_build_ea_magic_precheck_block_2026-08-10]]):
mirrored the compiled QM5_1258 sibling's framework wiring, hand-rolled the card's
WilderMA(7)→HMA(7) double-smoothing kernel over the raw Stochastic %K series (no
`QM_*` helper smooths a derived indicator series, only raw price — same limitation as
the Bermaui-RSI/CCI siblings), self-allocated 4 magic rows (16260000-3,
EURUSD/GBPUSD/NDX/XAUUSD.DWX), resolver regen 0 dropped, build_check PASS, compile
PASS, validate_spec_doc PASS, validate_build_guardrails PASS, 4 setfiles generated.
Smoke blocked by active RAMP-10-SOAK Custom-history isolation (infra, not a defect).
Committed `155d8fe76`/`7b4373240`/`f8ae0ad66` on `agents/board-advisor`.

On closing out the router task, found `claude-orchestration-2` had **independently
built the same task** and already called `update-task` — but committed to its own
worktree (`C:/QM/worktrees/claude-orchestration-2`, branch `agents/claude-orchestration-2`,
commit `aac51b3a8`), which is operationally invisible to the pipeline (T1-T10 backtest
workers only read `C:/QM/repo/framework/EAs/...`). Root cause: CLAUDE.md's general
Worktree Discipline ("never commit directly against the canonical checkout") conflicts
with the `build_ea`-specific SOP, which requires the canonical checkout precisely
because that's where the compiler/terminal-workers/registries live. Corrected the
router record's `artifact_path`/`verdict` to point at the canonical (pipeline-reachable)
build and flagged the worktree commit as a duplicate that should not be merged. Full
writeup + a standing-risk recommendation (route capacity-spilled `build_ea` to a single
slot, or implement a real per-task lock, or document the canonical-checkout exception
explicitly): `docs/ops/evidence/2026-08-10_build_ea_worktree_vs_canonical_race_QM5_1626.md`.

### QM5_1355, QM5_1354 — already completed by a concurrent sibling session

By the time this cycle reached them, both were already `REVIEW`
(`claude-orchestration-1`/`-2`, commits `9a9a3b306`/`9cf1bff0b`). Left untouched per the
"REVIEW tasks are not yours" rule; released this session's re-acquired leases without
re-closing.

### QM5_1630, QM5_1628 — reviewed, both NEEDS_FIX

Independent review + mechanical re-verification against their approved cards (neither
had been touched by a sibling session). Both share three identical preflight-blocking
gaps — no `ea_id_registry.csv` row, no `SPEC.md`, empty `sets/` (zero setfiles) — the
same three Codex's independent review flagged for sibling QM5_1627
(`docs/ops/evidence/2026-08-10_qm5_1627_codex_gemini_review.json`). This is a
**systemic gap in the current Gemini/agy build path**, not three isolated one-offs —
worth escalating to whoever owns `tools/strategy_farm/prompts/codex_build_ea.md`'s
Gemini-side equivalent, not just fixing per-EA.

- **QM5_1630**: additionally, TD-Sequential/Combo accumulator state (`g_seq_*`/
  `g_combo_*`) resets to zero in `OnInit` with no historical rebuild — every restart
  cold-starts the ~22-H4-bar accumulation this signal depends on; and its time-stop
  uses a non-restart-safe manual bar counter (contrast with its own batch-mate
  QM5_1628, which correctly derives time-stop from `POSITION_TIME` + `iBarShift`).
- **QM5_1628**: additionally, the structural stop-loss anchors to the D-pivot (the
  entry price) instead of the card-specified C-pivot — same defect *class* as this
  session's own QM5_1355 finding two cycles ago (wrong-bar/wrong-pivot SL anchor,
  producing a materially tighter stop than the approved design) — and the card's
  independent +1.5×ATR breakeven trigger is simply absent from the implementation
  (conflated with the TP1 partial-close trigger, which fires at a different price).

Both left in `REVIEW` per the mandatory-Codex-pass hard rule, not self-approved.
Writeups: `docs/ops/evidence/2026-08-10_qm5_{1630,1628}_..._claude_review.md`.

### QM5_20073 — built against canonical `C:/QM/repo`

Pip-Hunter Heiken-Ashi recovery build (HA color-streak + EMA200 bias + RSI50-cross
entry, HA-flip/RSI-recross exit, ATR×2.0 SL, RR2.0 TP). `ea_id_registry.csv` row
pre-existed (2026-07-23); self-allocated 6 magic rows (200730000-5,
EURUSD/GBPUSD/USDJPY/AUDUSD/EURJPY/XAUUSD.DWX), resolver regen 0 dropped,
validate_spec_doc PASS, build_check PASS, compile PASS, 6 setfiles generated
(RISK_FIXED=1000/RISK_PERCENT=0 verified). Smoke blocked by the same RAMP-10-SOAK
Custom-history isolation as QM5_1626 (infra, not a defect). Committed `9342c12c8`/
`02fd5a923` on `agents/board-advisor`. No duplicate-build collision found this time
(checked `git log` for the EA dir before starting).

## Stopped short of an empty queue

Two more build_ea tasks (QM5_20074 trendline-horizontal-sr-retest, QM5_20075
camarilla-inner-pivot-fade, both routed 21:56:17Z) arrived after QM5_20073 closed out.
Deliberately not picked up this cycle: five-hour quota usage had climbed from 12% to
23% over this cycle's ~65 minutes (two full EA builds + two deep reviews + one
cross-session forensics writeup), and the claude task queue is fed by all 3 concurrent
orchestration slots' `route-many` calls — draining it to zero single-handedly isn't
this session's sole responsibility, and standing guidance
([[feedback_5x_plan_era_2026-08-03]]) is to pace volume against remaining budget, not
sacrifice depth for throughput. Left for a subsequent cycle (this slot's or a sibling's).

## Health check (post-cycle, 22:09Z)

`overall: FAIL` — 4 FAIL / 3 WARN / 12 OK. Standing, not new this cycle:
- `codex_auth_broken` (FAIL) — VPS `codex login` stale ~80h, only OWNER can fix
  ([[project_qm_codex_auth_broken_2026-08-10]]); this is *why* so much `build_ea` work
  capacity-spilled to claude this cycle (codex circuit-breaker active, 0 codex activity).
- `unbuilt_cards_count` (FAIL, 813) / `unenqueued_eas_count` (FAIL, 60) — downstream of
  the codex outage, both climbing while codex stays down.
- `pump_task_lastresult` (FAIL, exit 267009) — matches the "pump orphan lock
  self-clearing" pattern noted in the prior cycle's log; not chased further this cycle.
- `source_pool_drained` (WARN, 7 pending) — standing, [[project_qm_source_harvest_2026-07-24]].
- 10/10 terminal workers alive, disk 131GB free, no active-row-age violations.

QM5_10260 Q08: confirmed unchanged, still `FAIL_HARD` (last real evidence 2026-07-25,
`Q04 done`; no Q08 PASS since) — standing, deterministic-evidence gate, not re-litigated.

## Evidence

- `docs/ops/evidence/2026-08-10_build_ea_worktree_vs_canonical_race_QM5_1626.md`
- `docs/ops/evidence/2026-08-10_qm5_1630_demark_td_sequential_combo_overlay_h4_claude_review.md`
- `docs/ops/evidence/2026-08-10_qm5_1628_carney_5_0_pattern_h4_claude_review.md`
- Commits: `155d8fe76`/`7b4373240`/`f8ae0ad66` (QM5_1626), `32d6daf53` (1626 race
  evidence), `6d4ba4cab` (1630/1628 reviews), `9342c12c8`/`02fd5a923` (QM5_20073) — all
  on `agents/board-advisor`.

## Risks / blockers

- codex_auth_broken remains the dominant systemic issue this cycle — OWNER action
  required, tracked.
- Worktree-vs-canonical-checkout SOP conflict for `build_ea` (QM5_1626 finding) is a
  standing risk that will recur on every future capacity-spill until an owner decision
  lands (see the three options in that evidence doc).
- Gemini/agy build path systematically omits ea_id_registry row + SPEC.md + setfiles
  (3-for-3 this cycle: QM5_1627/1630/1628) — worth a fix at the source rather than
  continuing to catch it per-EA in review.

## Recommended next step

OWNER: refresh `codex login` on the VPS to clear the dominant blocker. Otherwise: next
cycle picks up QM5_20074/20075 build_ea; Codex (once restored) should action the
QM5_1626 worktree-vs-canonical standing-risk decision and the Gemini build-path gap.
