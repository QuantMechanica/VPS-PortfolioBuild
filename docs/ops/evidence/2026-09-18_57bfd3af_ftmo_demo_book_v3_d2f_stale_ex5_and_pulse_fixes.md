# Router ops_issue 57bfd3af: QM5_21505/QM5_13054 stale-EX5 recompile authority, roster-driven EXPECTED_MAGICS, journal-corroborated attached_dark

Date: 2026-09-18
Router task: `57bfd3af-c659-40c8-819c-9f40b85f194d`
Branch: `agents/board-advisor`
Source: `docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2f/{PACKAGE.md,GAPS.md}`

## Status

Three required items, three different depths of completion, all evidence-backed:

1. **Governed recompile authority: DONE (compile itself DEFERRED, held).** New
   append-only source-repair authorities registered for QM5_21505 and
   QM5_13054; the resident-worker COMPILE_EA rows are enqueued and held.
2. **`EXPECTED_MAGICS` roster-driven: DONE and tested.**
3. **`observe_placements` journal cross-check: DONE and tested.**

No terminal, chart, or AutoTrading state was touched. No Q02/Q10 gate row was
created, requalified, or reused. No pipeline verdict is asserted.

## 1. Governed recompile authority

Both `QM5_21505_xag-weekly-lowvol-momentum` and `QM5_13054_brent-tom-mom`
compile cleanly from their already-committed HEAD source (commit
`9359ecaf2b`, 2026-09-13) — no source edit was needed or made. Two new
evidence-bound entries were added to
`tools/strategy_farm/compile_work_items.py`'s `BACKLOG_SOURCE_REPAIR_REGISTRATIONS`,
each pinned to this router task's id, the exact current `.mq5` sha256, and a
receipt file:

- `router_ops_issue:57bfd3af-c659-40c8-819c-9f40b85f194d:QM5_21505` →
  `docs/ops/evidence/2026-09-18_qm5_21505_stale_binary_rebuild_authority.json`
- `router_ops_issue:57bfd3af-c659-40c8-819c-9f40b85f194d:QM5_13054` →
  `docs/ops/evidence/2026-09-18_qm5_13054_stale_binary_rebuild_authority.json`

Both registry entries were validated against `load_compile_fail_repair_authorities`-
style hash checks and the focused authority test suites
(`test_compile_fail_repair_registry.py`, `test_compile_backlog_authorities.py`)
before use.

Enqueued via `farmctl.py enqueue-compile <label> --source-repair-authority <auth>`:

| ea_id | work_item_id | state | hold |
|---|---|---|---|
| QM5_21505 | `4b3ecdc3-f5a0-45f7-b817-1cfebf343cbe` | pending | `COMPILE_EA_WORKER_ROLLOUT_PENDING` |
| QM5_13054 | `2ea6b0fd-a5e1-4111-a04a-3846f3017ca4` | pending | `COMPILE_EA_WORKER_ROLLOUT_PENDING` |

**The compile itself was intentionally not run this turn.** Four `terminal64.exe`
processes and seven resident `pythonw.exe` terminal-worker processes were live
at authorship time (active T1-T10 backtests). Per
`docs/ops/evidence/2026-09-10_qm5_20143_stale_ex5_recovery.md` precedent and the
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` guard, an ad-hoc compile while the factory
is running is refused; the correct governed action is to enqueue the held,
append-only row and let the resident worker pick it up once it has loaded this
turn's code (a worker restart was **not** performed — that is a separate,
out-of-scope action, and the operating rules forbid interrupting active T1-T10
backtests without an explicit OWNER instruction).

### New-identity / Q02 re-entry consequence (explicit, as required)

**Yes — the rebuilt `.ex5` for both EAs is a new identity.** Per the
2026-08-17 stale-EX5-voids-healthy-backtests doctrine (build-date is a
predicate of EA identity), once the held COMPILE_EA row completes:

- **Invalidated:** the current `Q10_NEWS / CONFIG_LOCKED` seal for each
  (EA, symbol) pair (`QM5_21505/XAGUSD.DWX` baseline `a345970c4c597963...`;
  `QM5_13054/XTIUSD.DWX` baseline `d834b193a77b1d10...`), and any Q02-Q09
  evidence recorded against the current `ex5_sha256` values
  (`395c4747832acbcdf8a68d8598e53abe5786bdc6c538767c400884cd82b2aea1` /
  `2e65488fccdbd985f78318861a223a305d820a4fce3d2ebdcafae6ce956fd96d`). Both
  EAs must re-enter at **Q02** under the new binary identity — this is
  independently confirmed by the OWNER-approved D2g6 decision doc itself
  (`docs/ftmo/FTMO_ALT_ROSTER_DEPLOYABLE2_2026-09-18.md` §4: "21505 and 13054
  need a recompile and, per the rebuilt-EX5-is-a-new-identity rule, a fresh
  seal from Q02 before they can run on a venue name").
- **Stays valid:** the magic registry rows (215050000 / 130540000, active,
  correct ea_id/slot — keyed by ea_id/slot, not by ex5 identity) and the
  `.mq5` source review / `strategy_host_symbol` input contract from commit
  `9359ecaf2b` (this authority compiles that exact, already-reviewed source
  unchanged).
- **This task does not perform the Q02 re-enqueue or the Q10_NEWS re-seal.**
  Those are separate governed actions outside a compile-only authority's
  scope, and — per `GAPS.md` G6 — the Q10 baseline-identity hash methodology
  (raw-byte vs. line-ending-normalized) is itself an open, ROT-adjacent policy
  question the two existing seals disagree on (one was taken CRLF, the other
  LF). Re-sealing before that question is settled would risk perpetuating the
  exact ambiguity that produced the drift; it is left for Fable/OWNER/Codex on
  the gate-evidence path once the compile completes.

Also noted independently: the FTMO demo book has since moved on to roster
**D2g6** (commit `99c0a1f6`, 2026-09-18, six clean sleeves, neither 21505 nor
13054 included), so this recompile no longer blocks today's deployment — it
restores both EAs to correct build standing for a future book.

## 2. `ftmo_trial_pulse.py`: `EXPECTED_MAGICS` is now roster-driven

`EXPECTED_MAGICS` was a hardcoded 8-magic literal bound to the incumbent M13
roster (GAPS G3): every book recomposition broke the "all magics seen" check
by construction, comparing `magics_seen` against a set that shares only 3
members with a new book. Replaced with `load_expected_magics()`, which loads
the active demo package roster (`docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2g6/roster.json`)
through the same validated `trial_setpath.load_roster()` used by
`trial_setpath`/`demo_install`, and falls back to the historical incumbent set
with a reported, non-fatal `WARN` if the roster cannot be loaded. Verified live:

    EXPECTED_MAGICS_SOURCE = docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2g6/roster.json
    EXPECTED_MAGICS = {104030002, 107000003, 107060001, 114220004, 132130000, 412190000}
    EXPECTED_MAGICS_LOAD_ERROR = None

The next recomposition needs only a `roster.json` swap, not a code edit.
Output now carries `expected_magics_source` / `expected_magics_load_error` for
transparency. Tests: `test_load_expected_magics_reads_the_active_package_roster`,
`..._falls_back_on_missing_roster`, `..._falls_back_on_malformed_roster`; the
one pre-existing hardcoded-`/8` assertion
(`test_kill_switch_runtime_proof_gaps_warn_on_prague_trading_day`) was made
roster-size-agnostic.

## 3. `demo_cycle.py`: `observe_placements` now cross-checks the terminal journal

Root cause found by direct reproduction against the live FTMO-Demo terminal
(`81A933A9AFC5DE3C23B15CAB19C63850`), not by re-reading GAPS.md's claim at
face value (which no longer reproduces — the current live `observe_placements`
correctly returns real per-ea_id counts, e.g. `10706: 68`, and
`attached_dark_count: 0` today is legitimately because only 3 trading days
have elapsed against a 5-day threshold, not because of a code defect in the
"all EVIDENCE_MISSING" shape GAPS.md described at ~02:40Z):

`QM5_21505`'s installed terminal binary is the untracked 2026-09-06 alias
rebuild (PACKAGE.md §3). It **is** placing real XAGUSD orders — confirmed
directly in the terminal's own `Logs\20260910.log`, `20260911.log` and
`20260918.log` (native journal, `'1514536732': market buy 0.01 XAGUSD ...`,
`deal #522384958 buy 0.01 XAGUSD at 65.324 done`, today) — but its own
`QM5_21505_ea-21505.log` never emits a `TM_OPEN`/`ENTRY_ACCEPTED` line, so
`observe_placements` reported it as `0`, indistinguishable from a genuinely
dark sleeve like `QM5_13054`. This is exactly the false-negative class GAPS G7
warned about ("establish where placements are actually observable... terminal
journal Trades lines").

Fix: `observe_placements` gained optional `journal_dir`/`roster` parameters.
When given, it also counts the terminal's native `Logs\*.log` "Trades" lines
(`observe_journal_placements`, new function) for each roster symbol that is
**unambiguous** — traded by exactly one `ea_id` in the current roster, since
the native journal carries no magic number and a shared symbol cannot be
safely attributed to one sleeve (`_unambiguous_symbol_ea_ids`, new function).
The two counts are merged with `max()`: a real EA-log count is never lowered,
and a `0` is only promoted when independent journal evidence exists for that
sleeve's own unique symbol. `observe_demo_terminal()` now passes both.

This does **not** touch the 5-trading-day threshold, the cycle-reset/roster-
hash semantics, or the material-change classification — those are unrelated,
more sensitive (gate-adjacent) questions left untouched. Verified against the
live terminal: `1537`/`21505` both trade `XAGUSD` in the currently *attached*
chart-profile roster, so that symbol is correctly treated as ambiguous and
skipped (no fix without further work distinguishes them today); `13054`'s
unique `USOIL.cash` symbol has zero journal evidence too, so it is correctly
still eligible to flip `attached_dark=True` once 5 trading days elapse —
proven directly by `test_attached_dark_fires_once_journal_corroborated_evidence_still_shows_zero`.

Tests added: `test_unambiguous_symbol_ea_ids_skips_shared_symbols`,
`test_observe_journal_placements_counts_trades_lines_for_unambiguous_symbol`,
`test_observe_journal_placements_skips_ambiguous_shared_symbol`,
`test_observe_journal_placements_missing_dir_is_evidence_missing`,
`test_observe_placements_promotes_zero_when_journal_shows_real_fills`,
`test_observe_placements_never_lowers_a_count_the_ea_log_already_proved`,
`test_observe_placements_without_journal_args_is_unchanged`,
`test_attached_dark_fires_once_journal_corroborated_evidence_still_shows_zero`.

## Verification

- `python -m pytest -q tools/strategy_farm/tests/test_ftmo_demo_cycle.py tools/strategy_farm/tests/test_ftmo_trial_pulse.py`
  → 50 passed.
- `python -m pytest -q tools/strategy_farm/tests/ -k ftmo` → 1138 passed, 4
  pre-existing failures unrelated to this change (`test_ftmo_demo_governor_contract.py`,
  `test_ftmo_no_purchase_guard.py`, `test_ftmo_trial_setfiles.py`,
  `test_live_uptime_watchdog_static.py` — none reference `demo_cycle`,
  `ftmo_trial_pulse`, `21505`, or `13054`; confirmed via a scoped git-stash
  bisection that `test_compile_fail_repair_registry.py`'s and
  `test_compile_backlog_authorities.py`'s two failures are likewise pre-existing
  and unrelated).
- `py_compile` clean on both edited modules.
- `farmctl.py health` run before and after; no new FAIL introduced by this
  change (see companion router update).
- No terminal was started manually; no AutoTrading or T_Live state was
  touched; no active T1-T10 backtest was interrupted.

Implementation: uncommitted on `agents/board-advisor` at task hand-off,
explicit pathspecs only:
`tools/strategy_farm/compile_work_items.py`,
`tools/strategy_farm/ftmo/demo_cycle.py`,
`tools/strategy_farm/ftmo_trial_pulse.py`,
`tools/strategy_farm/tests/test_ftmo_demo_cycle.py`,
`tools/strategy_farm/tests/test_ftmo_trial_pulse.py`,
`docs/ops/evidence/2026-09-18_qm5_21505_stale_binary_rebuild_authority.json`,
`docs/ops/evidence/2026-09-18_qm5_13054_stale_binary_rebuild_authority.json`,
`docs/ops/evidence/2026-09-18_57bfd3af_ftmo_demo_book_v3_d2f_stale_ex5_and_pulse_fixes.md`
(this file). Left uncommitted per the task's instruction to leave the
board-advisor artifact in REVIEW rather than advance history myself.

Verdict: `PARTIAL_GOVERNED_RECOMPILE_ENQUEUED_HELD_PLUS_TWO_FIXES_TESTED`
