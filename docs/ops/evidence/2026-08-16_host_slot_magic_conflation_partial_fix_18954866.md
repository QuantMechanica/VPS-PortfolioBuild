# Host-slot magic conflation (18954866): partial fix landed, task already BLOCKED by sibling

- Router task: `18954866-6166-4529-8ec6-8485ef25c023` (claude, priority 85)
- Follow-ups to: `docs/ops/evidence/2026-08-16_host_slot_magic_conflation_q04_evidence.md`
  (original root-cause) and `docs/ops/evidence/2026-08-16_host_slot_magic_conflation_independent_verification.md`
  (sibling's independent re-derivation, same task id, landed `3ae67db6d`).
- Code commit: `8a51652a3` on `agents/board-advisor`.

## What changed

Implemented **fix_shape item 2 only** from the original root-cause doc:
`QM_MagicChecked(ea, slot, expected_symbol)` now fails closed when the
registry's symbol for `(ea_id, symbol_slot)` differs from `expected_symbol`,
instead of silently returning a foreign symbol's magic.

- `framework/include/QM/QM_Errors.mqh`: added `EA_MAGIC_RESOLUTION_FAILED`.
- `framework/scripts/update_magic_resolver.py` (the canonical generator —
  `QM_MagicResolver.mqh` is a derived artifact, "do NOT hand-edit"): added
  `QM_MagicRegisteredSymbol(ea_id, slot)` and the fail-closed branch inside
  `QM_MagicChecked()`, placed before the existing
  `QM_MagicCollisionWithForeignOpenPositions` check so a foreign-symbol slot
  never reaches a live-tradable magic.
- Regenerated `framework/include/QM/QM_MagicResolver.mqh`: 16,071 rows kept,
  0 dropped, registry SHA unchanged (logic-only diff, confirmed via
  `--dry-run` before and after).
- New tests: `framework/scripts/tests/test_magic_resolver_symbol_fail_closed.py`
  — asserts the generated template contains the new function/branch in the
  correct order, plus a pure-Python reference mirror of the lookup+compare
  algorithm exercising: mismatch rejects, match accepts, unregistered slot is
  left to the existing `QM_MagicRegistered()` gate (not double-flagged), and
  an empty `expected_symbol` (legacy callers) is a no-op. All 9
  resolver-generator tests pass, plus the 19 pre-existing
  basket/runtime-execution-contract/reconcile tests that exercise adjacent
  magic-resolution paths (`test_basket_order_helper_static.py`,
  `test_runtime_execution_contract_static.py`,
  `test_magic_resolver_reconcile_newlines.py`) — no regressions.

## Urgent repair folded into this commit

The routine `build: pump auto-commit` (`2d00fd67e`) swept the already-written
`QM_MagicResolver.mqh` into `HEAD` (it matches a watched factory-artifact
path) before this commit landed, while `QM_Errors.mqh` was still uncommitted
in the working tree. That left `HEAD` briefly in a state where
`QM_MagicResolver.mqh` referenced `EA_MAGIC_RESOLUTION_FAILED` without it
being defined anywhere — every EA build including the resolver (effectively
the whole fleet) would have failed to compile. Verified directly: `git show
HEAD:framework/include/QM/QM_Errors.mqh | grep EA_MAGIC_RESOLUTION_FAILED`
returned nothing before this commit. Landing the constant + generator source
immediately closed that window; no evidence a build actually ran against the
broken intermediate state (checked: no compile_ea failures logged in that
~15s window).

## What was NOT done (explicitly deferred, not silently dropped)

1. **`QM_Entry.mqh:251` host-slot semantics** (fix_shape item 1): when
   `explicit_magic==0` and `req.symbol_slot==0`, the entry path still resolves
   via `QM_MagicChecked(ea_id, 0, _Symbol)` rather than the suggested
   `g_qm_fw_magic`. With this cycle's fix, an EA hitting a foreign-symbol slot
   0 now **rejects** (`EA_MAGIC_RESOLUTION_FAILED`) instead of silently
   trading under the wrong magic — a real safety improvement — but it does
   not make the EA trade correctly under its own magic. That requires tracing
   where `g_qm_fw_magic` is populated and confirming it's correct in every
   call context, which is a larger, riskier change than a single cycle should
   self-verify without a compile+bound-backtest regression pass.
2. **The mechanical rebuild sweep** across the up-to-708/797-pair detector
   upper bound: unchanged, unstarted. Per the original doc's own staging plan
   (stage A = `QM5_11424`, stage B = mechanical sweep) and the sibling's
   verification doc's disposition, this blast-radius work is Codex's default
   lane per `CLAUDE.md`'s capability split (repo-edit/pipeline-wiring at EA-
   fleet scale), not something to self-authorize here.
3. **`QM5_11424` GBPUSD real-fold rerun** and **`ENTRY_ACCEPTED`==`INIT`==
   `KILL_SWITCH_INIT` magic confirmation in the logger** — both explicitly
   listed as `verification_required` in the original task — need an actual
   compile + bound backtest through the T1-T10 factory, not available to this
   single-pass cycle.

## Router state

Task `18954866` was already moved to `BLOCKED` (`updated_at
2026-08-16T12:08:32Z`) by the sibling session that landed `3ae67db6d`,
before this commit was made. This doc is filed for continuity so whoever
unblocks the task next (recommended: Codex, per the sibling's disposition)
has the validation-layer fix already landed and doesn't duplicate it — only
items 1-3 above remain open. No `update-task` call made here; the task left
`IN_PROGRESS` under a sibling before this session's edit completed, so it is
no longer this session's to close.
