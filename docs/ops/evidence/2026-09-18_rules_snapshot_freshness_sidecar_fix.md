# FTMO rule-snapshot freshness rebind no longer drifts the hash-pinned rulepack

Router task: `41d46b03-1a3b-4993-8b4e-72ab6fe666ba`
Agent: claude
Date: 2026-09-18

## Defect

`tools/strategy_farm/ftmo/rules_snapshot.py::refresh` (via `rebind_rulepack`)
unconditionally rewrote the `rule_snapshot_binding.rebound_at_utc` field into
the hash-pinned rulepack `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json`
on every invocation, even when the bound snapshot pointer (path/sha256/retrieved_at_utc)
had not changed. This file is a governed, hash-pinned artifact: downstream
consumers (`tools/strategy_farm/ftmo/trial_setpath.py::load_binding`,
`tools/strategy_farm/portfolio/ftmo_book3_standalone_evaluator.py`) pin its
exact bytes and canonical-JSON hash against
`tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json`. A routine
freshness check therefore drifted `rulepack_file_hash_drift` in the canonical
checkout on the 2026-09-18 00:04Z run — `git diff` after `rules_snapshot.py
refresh` showed only `.rule_snapshot_binding.rebound_at_utc` changed. Fable
reverted the resulting working-tree edit 2026-09-18 ~02:35Z (evidence per the
router task payload).

## Fix

`tools/strategy_farm/ftmo/rules_snapshot.py`:

- `rebind_rulepack` now compares the snapshot pointer already bound in the
  rulepack's `official_sources` entries against the pointer it would write.
  When they match (no governed re-pin needed), the function returns the
  current binding for reporting purposes but makes **no write** to the
  rulepack — the pinned file stays byte-identical, and its existing
  `rebound_at_utc` is preserved rather than advanced.
- Every call (no-op or real re-pin) now also writes an observability sidecar
  at `D:/QM/reports/state/ftmo_rules_freshness.json`
  (`FRESHNESS_STATE_PATH`, override via `freshness_state_path=`) recording
  `last_checked_utc`, whether this check rebound the file, and the resulting
  binding — so freshness-check history remains visible without living inside
  a hash-pinned artifact.
- A real re-pin (the bound snapshot pointer actually differs, e.g. a new
  dated snapshot lands) still rewrites the rulepack's `official_sources`
  pointers, top-level `as_of`, and `rule_snapshot_binding` exactly as before
  — that is the governed re-pin case, which already requires re-signing the
  downstream hash pin in `ftmo_m13_standard_demo.v1.json` on review.
- `refresh()` threads the new `freshness_state_path` parameter through to
  `rebind_rulepack`.

`tools/strategy_farm/tests/test_ftmo_rules_snapshot.py`:

- Existing `test_rebind_updates_pointer_not_gate_thresholds` now passes an
  isolated `freshness_state_path` (tmp_path) so tests never touch the real
  `D:/QM/reports/state/` sidecar.
- New `test_rebind_is_noop_on_pinned_rulepack_when_snapshot_unchanged`
  constructs a rulepack already bound to the current snapshot (mirroring the
  live `FTMO_2S_100K_STANDARD_V2.json` shape) and asserts:
  - the rulepack's bytes are unchanged after `rebind_rulepack`,
  - `rebound_at_utc` in the returned binding is not silently advanced,
  - the sidecar still records the check (`rebound_this_check: false`).

## Verification

- `python -m pytest tools/strategy_farm/tests/test_ftmo_rules_snapshot.py -q`
  → 8 passed (was 6 before this change; 2 new/modified).
- `python -m pytest tools/strategy_farm/tests/test_ftmo_trial_setpath.py
  tools/strategy_farm/tests/test_ftmo_binding_pin_line_endings.py -q` → 29/31
  and 2/2 pass respectively; the 2 failures in `test_ftmo_trial_setpath.py`
  (`wrong_rulepack` on `load_binding`) are pre-existing and reproduce
  identically with this change fully reverted (verified via a temporary
  stash-and-rerun) — an unrelated, already-open drift between the live
  rulepack's `as_of` and the pinned binding contract, out of scope for this
  ticket.
- Live-shape idempotency check: copied the real
  `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json`
  to a scratch path (never touching the canonical hash-pinned file) and ran
  `rebind_rulepack` against it twice with the real latest snapshot
  (`docs/ops/evidence/2026-09-15_ftmo_official_rules_snapshot.json`): both
  calls left the copy byte-identical and both returned
  `rebound_at_utc: "2026-09-15T14:00:00Z"` (the value already committed in
  the live file), confirming the fix reproduces the exact regression
  scenario correctly on real content. Scratch files were deleted after the
  check; the canonical rulepack was never modified.

## Risk / scope

- No change to any go-criterion, gate threshold, or FTMO rule content —
  `rebind_rulepack`'s pointer-rewrite path (the actual re-pin branch) is
  otherwise unchanged.
- No live rulepack, binding contract, or hash pin was modified by this fix
  or its verification.
- Pre-existing `wrong_rulepack` failures in `test_ftmo_trial_setpath.py` are
  a separate, already-open defect (binding contract vs. live rulepack
  `as_of`/hash drift) and are called out above rather than silently masked.

## Recommended next step

Route the pre-existing `test_ftmo_trial_setpath.py` `wrong_rulepack` /
`rulepack_file_hash_drift` failures (independent of this fix) as a follow-up
ops_issue so the M13 Standard demo binding contract gets re-pinned against
the current rulepack content under governed review.
