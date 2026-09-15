# Slice D2 — generators relabel + watch (report)

Slice key: `d2_generators_relabel_watch`
Decision: OWNER-DEC-CBE-20260915 (Continuous Book Evolution). Directive §3 (WAY TO 25
abolished as a business target), §4 (fixed 25-candidate trigger superseded), §60/§72
(operator surfaces + factory panel). Branch `agents/board-advisor`.

## Summary

The 25-counter is relabeled everywhere it was GENERATED as an OBJECTIVE into a
DIAGNOSTIC on the surfaces this slice owns; the Morning Briefing and Heartbeat headlines
are replaced with a Continuous Book Evolution headline sourced from the shared read-models
(EVIDENCE_MISSING when absent); the hourly factory watch gains a census-stall-in-drain
tripwire for the 15.09 false-OK case; and the pre-existing sealed-count sha256 mismatch is
fixed at its root (LF-blob hashing) with the historical pin proven to match. All JSON
output keys stay backward compatible (D1 / dashboards / session tools read them); only
labels/text changed, plus additive diagnostic keys.

## Files changed

- `tools/strategy_farm/path_to_25.py`
  - **Sha256 root-cause fix (item 4):** `_counting_definition` hashed the raw working-tree
    bytes; on a Windows checkout autocrlf rewrites the sealed decision to CRLF, so the
    hash was `2df61c55…` vs the pinned `d47501ca…`. Diagnosis (git + hashes): the git blob
    is LF (len 1090 → `d47501ca…`); the working tree is CRLF (len 1110 → `2df61c55…`).
    **The decision file was NOT amended after sealing** — content is byte-identical, only
    line endings differ. Fix: new `_lf_canonical_sha256()` hashes the LF-normalized
    canonical blob; the historical pin now matches regardless of checkout policy. The dated
    decision file was NOT edited.
  - Relabels: module + `path_to_25_metrics` docstrings, `counting_definition.footnote` and
    added diagnostic keys `count_semantics="DIAGNOSTIC"`, `reference_pool_size`,
    `reference_pool_size_superseded_utc` at the `counting_definition` level. The `trigger`
    dict shape and the counting PREDICATE are unchanged (backward compatible).
- `tools/strategy_farm/operator_surfaces.py`
  - `book_guard` now carries `reference_pool_size` + `trigger_policy` (from
    `book_build_guard`) alongside the retained legacy `minimum_qualified_pairs` key. HTML
    "Book guard" block reworded from `N / 25` to `N qualified pool · reference pool size 25
    (historical, superseded 2026-09-15) · trigger any_valid_pool …`.
- `tools/strategy_farm/path25_red_team.py`
  - `evidence.qualified_pool`: WARN→**INFO** always; summary no longer claims the pool is
    unqualified or that "no book trigger is licensed" (contradicted any-valid-pool). Adds
    `reference_pool_size` + `trigger_policy` evidence.
  - `evidence.no_phase3_bypass`: the `qualified < 25 ⇒ FAIL` count branch is **removed**;
    the fail-closed invariant is now solely the book-build guard (non-empty valid pool +
    OWNER order). `audit_database`/`build_audit` gained an `order_dir` kwarg (default
    `book_build_guard.DEFAULT_ORDER_DIR`) for testability.
  - `contract.book_trigger_authority` PASS text reworded to diagnostic (logic unchanged —
    still validates the manifest's OWNER-authority + fail-closed shape, which passes).
  - `INFO` added to the report `interpretation` map.
- `tools/strategy_farm/book_evolution_readmodels.py` **(new)** — shared read-only loaders +
  headline builder for the 5 read-models (`book_evolution_dxz`, `book_evolution_ftmo`,
  `ftmo_challenge_readiness`, `research_state`, `factory_bottleneck`). Fail-soft to
  `EVIDENCE_MISSING`; never opens the DB; never invents values. Each facet exposes both a
  self-labeling `text` and a prefix-free `detail`.
- `tools/strategy_farm/heartbeat_snapshot.py`
  - "## Weg zu 25" replaced by "## Kontinuierliche Buchentwicklung" (4 read-model facets)
    + "## Qualifizierungs-Diagnostik" (pool as diagnostic). The "Lückenlose Frontier"
    guard line reworded from `N / 25` to a diagnostic reference-pool phrasing.
- `tools/strategy_farm/morning_brief.py`
  - HTML `render_path_to_25_section`: section retitled "Kontinuierliche Buchentwicklung";
    the `/25` tile is now a diagnostic pool readout; new `_book_evolution_headline_html()`
    block. Text renderer: "WEG ZU 25" → "KONTINUIERLICHE BUCHENTWICKLUNG" headline +
    "QUALIFIZIERUNGS-DIAGNOSTIK" with reference-pool phrasing. Module docstring §3 updated.
- `tools/strategy_farm/session_tools/hourly_watch_0909.py`
  - Refactored into importable `census_stall_alert()` + `idle_factory_terminals()` pure
    functions with the script body under `if __name__ == "__main__"`. New ALERT fires when
    `census_done_60m == 0` AND `≥3` factory terminals idle AND `drain_window.json` has an
    open `pre_drain`/`tracker` waiting `≥10 min`; it names the blocking `ea_id`/`item_id`/
    `reservation_gb`. The counter print line relabeled to diagnostic phrasing. Existing
    checks preserved.
- Tests: `test_path_to_25_metrics.py` (LF-pin + no-goal-language regressions; surface-
  coherence test split so D2 surfaces assert the new headline while the cockpit-v2
  assertion stays for slice D1), `test_path25_red_team.py` (INFO pool + phase-3 guard
  semantics), plus new `test_book_evolution_readmodels.py` and
  `test_hourly_watch_census_stall.py`.

## Contracts

- Read-models consumed (write side owned by other slices; consumers tolerate absence):
  `book_evolution_dxz.json`, `book_evolution_ftmo.json`, `ftmo_challenge_readiness.json`,
  `research_state.json`, `factory_bottleneck.json` under `D:/QM/reports/state/`.
- New importable API: `book_evolution_readmodels.{load_read_model, book_evolution_headline,
  headline_lines}`; `hourly_watch_0909.{census_stall_alert, idle_factory_terminals}`.
- Additive JSON keys (backward compatible): `operator_surface.book_guard.reference_pool_size`
  / `.trigger_policy`; `path_to_25.counting_definition.count_semantics` /
  `.reference_pool_size`; red-team `evidence.*` diagnostics.
- `path25_red_team.audit_database`/`build_audit` gained keyword `order_dir` (defaulted).

## Tests + pytest summary

`python -X utf8 -m pytest tools/strategy_farm/tests/test_path_to_25_metrics.py
test_path25_red_team.py test_operator_surfaces_rebaseline.py
test_book_evolution_readmodels.py test_hourly_watch_census_stall.py
test_morning_brief_live_status.py test_notion_morning_brief.py
test_run_agent_orchestration_heartbeat.py test_mission_control_v2_data.py
test_book_build_guard.py -q`
→ **138 passed, 5 warnings** (warnings are pre-existing unrelated DeprecationWarnings).

The two pre-existing failures named in the b1 slice report (sealed count decision sha256
mismatch) are now green.

## Runtime artifacts written

- Vault surface regenerated once via the normal generator (`heartbeat_snapshot.py`):
  `G:/My Drive/QuantMechanica - Company Reference/08 Current State/Heartbeat.md`
  (`vault_mirror: ok`) and `D:/QM/reports/state/heartbeat_state.json` — both now show the
  Continuous Book Evolution headline and the diagnostic pool readout. Live read-models
  present on D: rendered real values (DXZ 24 sleeves / ADD_SLEEVE; FTMO NOT_READY);
  Research/Factory read `EVIDENCE_MISSING` as designed.

## Rollback

Revert the eight tracked files + delete the two new files
(`book_evolution_readmodels.py`, `test_hourly_watch_census_stall.py`,
`test_book_evolution_readmodels.py`). No DB, gate, verdict, or dated-decision bytes were
touched. Re-running `heartbeat_snapshot.py` restores the prior page automatically once the
code is reverted.

## Items NOT done (with reasons)

- **Dashboards `render_dashboards.py` / `render_cockpit.py`:** no change required. Grep
  confirms neither emits a "Way to 25" / 25-counter / objective string; their bottleneck
  lines are neutral and do not reference 25. Editing them would be scope creep with test
  risk. (The v2 surfaces `render_cockpit_v2.py` / `mission_control_v2_data.py` are slice
  D1 — untouched.)
- **Vault ToDo "Way-to-25" headline renderer:** not found. `grep` for
  `Way to 25`/`WAY_TO_25`/`Nordstern` across `tools/`+`scripts/` returns no renderer, so
  there is nothing to relabel (NOT_APPLICABLE).
- **PRE-EXISTING failing test outside this slice:**
  `tools/strategy_farm/tests/test_build_qualified_roster.py::test_roster_binds_the_census_snapshot_and_qualified_ids`
  asserts an exact `set(guard) == {…}` key set and now fails because the B/C landing of
  `book_build_guard.GuardResult` added `reference_pool_size` + `trigger_policy`. Neither
  `book_build_guard.py` nor that test is in this slice's file set (both untouched by D2);
  the trivial fix is to add the two keys to the expected set — flagged for the orchestrator
  to route to the book-guard/roster owner.
