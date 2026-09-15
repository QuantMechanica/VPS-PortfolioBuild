# Slice report — `b1_book_guard_decision` (2026-09-15)

Directive: OWNER "CONTINUOUS BOOK EVOLUTION" §3, §4, §68B. Decision id: `OWNER-DEC-CBE-20260915`.
Audits read: `candidate_universe.md`, `rule_inventory_code.md`, `pipeline_factory_state.md` (drift table),
`portfolio_engine_existing.md`.

## What this slice does

1. **OWNER decision record** `decisions/2026-09-15_owner_continuous_book_evolution.md` (id `OWNER-DEC-CBE-20260915`):
   transcribes every decided item of §68B as a numbered decision with directive section, what it supersedes (named prior
   decision/DL/rule + enforcement path from `rule_inventory_code.md`), implementation status (this slice vs. later slice),
   and what stays unchanged; preserves the RED boundaries (§64/§71) and the qualification predicate; carries the
   observed-drift annex.
2. **Superseded the fixed 25-candidate book-build trigger** (§4): the fixed `>= 25` becomes a DIAGNOSTIC, never a blocker;
   book build/evaluation is allowed for any NON-EMPTY valid qualified pool; the qualification predicate is UNCHANGED and
   unqualified pairs still fail closed; OWNER-order checks kept.
3. **Recorded the empty `candidate_qualifications` table drift** in the decision record's observed-drift annex (no code
   change), plus the 26/28/29 count drift and the corrected `gate_manifest.v4.json` `draft_note`.

## Files changed

- `tools/strategy_farm/book_build_guard.py`
  - `MIN_QUALIFIED_PAIRS = 25` retained ONLY as a diagnostic `reference_pool_size` constant (re-documented; still imported
    by read models). Added `MIN_VALID_POOL = 1` and `TRIGGER_POLICY = "any_valid_pool (OWNER-DEC-CBE-20260915)"`.
  - `GuardResult` gains backward-compatible fields `reference_pool_size` (default = `MIN_QUALIFIED_PAIRS`) and
    `trigger_policy` (default = `TRIGGER_POLICY`). All existing keys (`allowed`, `qualified_pairs`, `distinct_eas`,
    `strategy_families`, `order_artifact`, `reasons`) are unchanged, so `dataclasses.asdict` consumers
    (`operator_surfaces`, mission control, heartbeat, morning brief) keep working.
  - `check_book_build_allowed`: the `qualified_pairs < MIN_QUALIFIED_PAIRS` refusal is replaced by an empty-pool refusal
    (`qualified_pairs < MIN_VALID_POOL` → reason `qualified_pool_empty`), suppressed when `qualified_pool_unavailable` is
    already recorded. Returns the two new diagnostic fields. The OWNER-order requirement and the
    `_qualified_pair_rows` predicate (contiguous-valid-through-terminal-gate) are untouched.
- `tools/strategy_farm/config/gate_manifest.v4.json`
  - `draft_note` (line ~5): rewritten from the stale "PROPOSAL ONLY … DEFAULT_MANIFEST stays gate_manifest.v3.json" to an
    ACTIVE/superseded note (old text quoted inside for history). Fixes drift D3.
  - `book_trigger` (lines ~373-390): the `qualified_candidates_ge_25` condition keeps its legacy token name but its
    `detail` now states DIAGNOSTIC semantics (non-empty >= 1 required; 25 = reference only); `on_unmet` and `supersedes`
    rewritten to record `OWNER-DEC-CBE-20260915`. The `owner_order_artifact_present` condition is unchanged. Added
    `'trigger_policy': 'any_valid_pool (OWNER-DEC-CBE-20260915)'` semantics into the book_build_guard output (not a new
    manifest key — see "Why the manifest token name was kept" below).
- `tools/strategy_farm/tests/test_book_build_guard.py`
  - Replaced `test_below_25_refuses_even_with_owner_order` (asserted the now-removed `< 25` refusal) with
    `test_small_valid_pool_with_owner_order_is_allowed` (pool of 3 + order → allowed).
  - Added `test_empty_pool_refused_even_with_owner_order` (pool 0 → `qualified_pool_empty`), 
    `test_unqualified_pairs_are_never_counted` (frontier-Q13 pair never counted), and
    `test_25_appears_only_as_diagnostic_never_blocks` (25 = `reference_pool_size` only, `trigger_policy` set, no `< 25`
    reason).
- `decisions/2026-09-15_owner_continuous_book_evolution.md` (new).
- `docs/ops/evidence/2026-09-15_continuous_book_evolution/design/b1_book_guard_decision_report.md` (this file).

## Contracts changed

- **`book_build_guard.GuardResult`** — additive fields only (`reference_pool_size`, `trigger_policy`), defaulted, so
  positional and keyword constructors elsewhere keep working; JSON output is a superset of the old keys.
- **`book_build_guard` book-build trigger semantics** — from `qualified_pairs >= 25` to `qualified_pairs >= 1`
  (non-empty). Regression-tested (§70: "Q15 no longer hard-blocked solely by `<25`"; "invalid/unqualified candidates still
  fail closed").
- **`gate_manifest.v4.json` `book_trigger`** — text/semantics of the `qualified_candidates_ge_25` condition, `on_unmet`,
  `supersedes`, and the `draft_note`. The strict Python validator (`gate_manifest.py:782-797`) and the JSON schema
  (`schemas/gate_manifest.v4.schema.json`) still pass because the structural key set and condition token names are
  preserved.

### Why the manifest token name `qualified_candidates_ge_25` was kept (not renamed)

Renaming the condition would ripple beyond this slice's scope: the token is pinned by the strict validator
(`gate_manifest.py:794`), the JSON schema const (`schemas/gate_manifest.v4.schema.json:151`), the READ_INERT draft
(`config/gate_manifest.v4.draft.json:81`, which `test_gate_manifest.py::test_v4_json_schema_validates_draft…` validates
against the schema), and the `path25_red_team.py` contract check (`:241`). Renaming would break those and require touching
the historical draft. Instead the token is retained as a legacy machine identifier and neutralized in text (detail =
diagnostic, on_unmet = empty-pool only), with the authoritative behaviour living in `book_build_guard.py`. A future
Phase-D "Way to 25" decommission slice may rename the token across schema + draft + validator + `path25_red_team` if
desired; recorded in the decision record (decision 1, LATER SLICE).

## Callers comparing `qualified_count`/`MIN_QUALIFIED_PAIRS` to 25 (grep sweep)

Changed in this slice (allowed by scope: book_build_guard / gate_manifest / farmctl-side guard):
- `tools/strategy_farm/book_build_guard.py` — the trigger itself (changed).
- `tools/strategy_farm/config/gate_manifest.v4.json` — `book_trigger` (changed).
- `tools/strategy_farm/gate_manifest.py:794` and `schemas/gate_manifest.v4.schema.json:151` — validator/schema pin the
  condition TOKEN name; token kept, so NO change needed (verified: manifest still loads, schema test still passes).

Left untouched (Phase D read-model / decommission slice, per task instruction):
- `tools/strategy_farm/mission_control_v2_data.py`, `render_cockpit_v2.py:995` (`/25`), `path_to_25.py:29`
  (`TARGET_QUALIFIED_PAIRS = 25`), `operator_surfaces.py:298,397` (`minimum_qualified_pairs`), `rebaseline_census.py`,
  `morning_brief.py:1307,1616` (`/25`), `heartbeat_snapshot.py:460,483` (`/25`).
- `tools/strategy_farm/path25_red_team.py:241,244,257,554,557,562,580` — the "Way to 25" red-team tool (reads
  `MIN_QUALIFIED_PAIRS == 25`, checks the `qualified_candidates_ge_25` token, treats phase-3 rows `< 25` as a hard
  failure). NOT in the task's untouched list, but it is the milestone-red-team tool that belongs to the Phase-D "remove
  Way to 25" decommission; left untouched here and still green because `MIN_QUALIFIED_PAIRS` stays `25` and the token
  name is preserved. Flagged for Phase D.
- `tools/strategy_farm/config/gate_manifest.v4.draft.json:81` — READ_INERT historical draft; left as history.
- `tools/strategy_farm/session_tools/{fleet_monitor,hourly_watch_0909,tick_status}.py` — session diagnostics; untouched.

## Tests added + result

Added/updated in `tools/strategy_farm/tests/test_book_build_guard.py`:
`test_small_valid_pool_with_owner_order_is_allowed` (a), `test_empty_pool_refused_even_with_owner_order` (b),
`test_unqualified_pairs_are_never_counted` (c), `test_25_appears_only_as_diagnostic_never_blocks` (d).

Command (from worktree root):
`python -X utf8 -m pytest tools/strategy_farm/tests/test_book_build_guard.py tools/strategy_farm/tests/test_gate_manifest.py tools/strategy_farm/tests/test_book_path_refusal_cli.py tools/strategy_farm/tests/test_portfolio_periodic_report.py -q`

Result:

```
48 passed, 2 skipped in 3.07s
```

(The 2 skips are `test_gate_manifest.py`'s jsonschema-gated tests — `jsonschema` is not installed in this env;
`importorskip`.)

## Pre-existing failures NOT caused by this slice (verified by `git stash`)

`test_operator_surfaces_rebaseline.py::test_mixed_contract_frontiers_bands_guard_and_no_legacy_html` and three
`test_path25_red_team.py` tests fail with `RuntimeError: sealed count decision sha256 mismatch` in
`path_to_25.py:575` (expected `d47501ca…` vs actual `2df61c55…` for
`decisions/2026-08-27_owner_count_definition_option_a.md`). Verified with `git stash` (changes removed): the same tests
fail identically WITHOUT this slice's changes — this is a pre-existing seal drift in this stale worktree branch, in
`path_to_25.py` (a Phase-D file this slice must not touch) and against a dated decision (ROT — must not re-seal). Not
addressed here.

## Rollback

- `git revert` the commit touching `tools/strategy_farm/book_build_guard.py`,
  `tools/strategy_farm/config/gate_manifest.v4.json`, `tools/strategy_farm/tests/test_book_build_guard.py`. No runtime
  feature flag and no DB/state migration; reverting restores `MIN_QUALIFIED_PAIRS = 25` as the hard trigger and the
  original `book_trigger` / `draft_note` text. The decision record and this report are documentation (safe to keep or
  revert independently).

## Items I could NOT do (with reason)

- **Rename the `qualified_candidates_ge_25` token** — deliberately not done; blast radius (validator + schema + READ_INERT
  draft + `path25_red_team` + its schema-validation test) exceeds this slice and belongs to the Phase-D "Way to 25"
  decommission. Semantics were changed via text + the authoritative `book_build_guard.py` behaviour instead.
- **decisions/REGISTRY.md entry** — not added, to avoid a merge conflict with parallel slices; the orchestrator should add
  the `OWNER-DEC-CBE-20260915` registry row when integrating.
- **Read-model surfaces / `path25_red_team` decommission** (§3/§60) — out of scope (Phase D); listed above for the Phase-D
  slice.
