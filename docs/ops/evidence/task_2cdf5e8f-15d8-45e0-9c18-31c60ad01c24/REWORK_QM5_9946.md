# REWORK QM5_9946 bandy-supertrend-flip-trend — card-fidelity repair

Task `2cdf5e8f-15d8-45e0-9c18-31c60ad01c24` (routed to claude, directive
`OWNER-DEC-CLAUDE-CAPACITY-REBALANCE-20260926`). Source review:
`docs/ops/evidence/2026-09-26_family_fix_review_ea/REVIEW_QM5_9946.md`
(REVIEW_FAIL, findings #1/#2/#5 STILL_OPEN + PERF advisory).

## Baseline note (worktree currency)

This worktree's branch (`agents/claude-orchestration-2`) predates the EA's
introduction on `main` entirely, so `framework/EAs/QM5_9946_bandy-supertrend-flip-trend/`
did not exist locally. The task payload's cited line anchors (L133 band ATR,
L271–L275 time stop) only line up with the **symbol-input-fixed** source
(commit `f9ac2ad3d0` / `c07c9129c7`, "build(QM5_9946): symbols as inputs
(0ef4d60e stage 1)" — the hardening the 2026-09-26 review already verified
clean and independent of this task). The plain `origin/main` copy of this EA
predates that hardening and has different line numbers. I imported the file
set from `f9ac2ad3d0` as the correct base (verified by matching the payload's
line anchors exactly) and applied this task's fixes on top of it, in this
worktree only. No files under `C:/QM/repo` were touched.

Separately: an equivalent fix already existed once, unmerged, on orphaned
branch `rework-slot-11` (commit `d383c8224d`, 2026-08-24, "rework(9946): fix
ATR and D1 hold semantics") — it never landed on the branch the 2026-09-26
review inspected, hence the findings were still open. This repair is
independently re-derived from the card and review text, and lands the same
semantic fix (now also carrying the later symbol-input hardening).

## Findings repaired

| # | Finding | Fix | Where |
|---|---|---|---|
| 1 | Time stop was wall-clock (`TimeCurrent()-opened >= strategy_max_hold_bars*PeriodSeconds(D1)` ≈ 60 calendar days ≈ 43 D1 trading bars) vs card's 60 **completed D1 bars** | Replaced with `iBarShift(_Symbol, PERIOD_D1, opened, false) >= strategy_max_hold_bars` — counts fully-closed D1 bars since the position's open time | `Strategy_ExitSignal()`, was L273–275 |
| 2 | Supertrend band fed on `ATR(strategy_supertrend_period=10)`; card Mechanics (`atr = ATR(14)`) + Build-EA Notes (`iATR(...,14,...)`) both specify ATR(14) for the band; only the cat-SL path used ATR(14) | Band ATR call now uses `strategy_atr_period` (=14, same period as the catastrophic stop) instead of `strategy_supertrend_period`. `strategy_supertrend_period` is retained only for the warmup-depth floor (`MathMax(period, atr_period)+20`), matching the card's literal Mechanics/Build-EA-Notes text as the reconciliation authority over the looser header attribution text | `Strategy_GetSupertrendStates()`, was L133 |
| 5 | SPEC.md corruption: (a) slug was a literal backspace control byte (0x08) followed by `andy-supertrend-flip-trend`, rendering as `andy-...` instead of `bandy-...`; (b) Risk Model table read `,000 per trade` instead of `$1,000 per trade` | (a) byte-level fix replacing the `\x08` with `b`; (b) text fix to `$1,000 per trade` | `SPEC.md` L4, L88 |
| PERF (non-blocking, fixed) | `Strategy_ExitSignal` ran the ~200-bar Supertrend reconstruction (`CopyRates` + ~200 pooled `QM_ATR` calls) on every tick, before the `QM_IsNewBar()` gate | Hoisted `QM_IsNewBar()` into `is_new_bar` and gated the exit check (`is_new_bar && Strategy_ExitSignal()`) the same way entries already were; card exits (opposite flip, D1-bar time stop) are only meaningful on completed D1 bars anyway, so this is a no-op for correctness and removes the per-tick reconstruction cost | `OnTick()` |

No entry/exit/risk logic beyond the above was touched. Symbols remain inputs
(`strategy_symbol_*`, unchanged from the prior hardening). No ML. `RISK_FIXED`
(backtest, =1000) / `RISK_PERCENT` (live) unchanged.

## Verification performed (read-only / static — no compile, no terminal64.exe)

- `python framework/scripts/lint_ea_symbol_literals.py --ea-root framework/EAs/QM5_9946_bandy-supertrend-flip-trend`
  (invoked read-only from the canonical script path against this worktree's
  EA dir) → `OK: no hardcoded .DWX symbol literals in EA sources`.
- Brace/paren balance check on the edited `.mq5`: 26/26 braces, 149/149 parens.
- Line-ending check: file is uniformly CRLF after edits (0 mixed-EOL lines) —
  no stray LF-only lines introduced by the edit tool.
- Manual card-vs-code trace of all three repaired findings against
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9946_bandy-supertrend-flip-trend.md`
  (Mechanics + Build-EA Notes sections).
- Byte-level hexdump confirmed the SPEC.md slug corruption was a single
  `0x08` backspace byte (not a missing-character typo) and confirmed no
  other control-byte corruption exists elsewhere in SPEC.md.

## Not done in this pass (governed steps outside this worktree's authority)

- **No compile.** Per standing instruction, `terminal64.exe`/MetaEditor is
  never started manually from this session. The committed `.ex5` in this
  worktree is carried over from the symbol-input-fix baseline and is **stale**
  relative to this source change (same caveat the 2026-09-26 review already
  flagged for the committed binary). A governed recompile under
  `compile_fail_repair` authority + binary resync is required before any
  Q02/pipeline handoff — that is the factory build lane's job, not this
  headless cycle's.
- Set files (`sets/*.set`) were not touched — no parameter defaults changed
  (`strategy_atr_period`/`strategy_max_hold_bars` defaults are unchanged;
  only how the code *uses* them changed).

## Router state transition attempted — blocked on governed-compile identity

Attempted `agent_router.py update-task 2cdf5e8f... --state REVIEW`:
refused with `gate_code=D6_BUILD_IDENTITY_MISSING` /
`reason=build_identity_json_missing_review_dispatch_refused`. For
`task_type=build_ea`, the router requires a governed `COMPILE_EA` receipt
binding the new `mq5_sha256` before a task can enter REVIEW.

Investigated the one queuing path the commit guard itself suggested
(`farmctl.py enqueue-compile --build-task-id 2cdf5e8f... QM5_9946_bandy-supertrend-flip-trend`):
refused with `build_task_binding.reason=BUILD_TASK_BINDING_NOT_FOUND` (no
pre-registered binding record exists for this task id). Separately, and more
importantly: this command's `ea_dir` resolves to
`C:\QM\repo\framework\EAs\QM5_9946_bandy-supertrend-flip-trend` — the
**canonical checkout**, not this worktree — so even a successful call would
not have compiled this worktree's fixed source; it operates on whatever is
currently on disk at `C:/QM/repo`. Per standing instruction (never write
under `C:/QM/repo`; `farmctl.py` runs against the canonical checkout only)
and because the binding lookup fails regardless, no further enqueue attempts
were made and no `--source-repair-authority` grant was invoked (that
mechanism is additionally scoped to repairing a *failed* predecessor
compile — `787088b3` was COMPILE_OK, not a failure, so it would not apply
even if a grant existed).

**Net: the source-level repair is complete, verified, and committed in this
worktree. It cannot be carried to REVIEW from this session** — that requires
the build lane's governed `COMPILE_EA` queue (over the committed
`agents/claude-orchestration-2` source) to produce a receipt binding this
commit's `mq5_sha256`, followed by a binary resync. Router state set to
`BLOCKED` with this evidence path so the compile dependency is visible to
the next routing cycle, rather than forcing a disallowed state transition.
