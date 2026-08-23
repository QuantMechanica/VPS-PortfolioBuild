# rb-v4-runtime — gate manifest v4 runtime wiring evidence

Date: 2026-08-23
Ticket: proposal ticket 8 part A (`rb-v4-runtime`)
Scope: runtime readiness for the active manifest being either v3 or linear v4.
Non-scope: no `DEFAULT_MANIFEST` activation flip, no live database migration,
no queue mutation, no verdict mutation, and no gate threshold/criterion change.

## Result

PASS. Runtime dispatch and evidence routing resolve stable manifest roles rather
than v3 gate numbers. V3 keeps its established storage names except for the
OWNER-directed A2 policy change: incumbent PASS enters the mandatory
optimization audit and terminal head-to-head has no automatic portfolio edge.
V4 follows `Q08 -> Q09 -> Q10_NEWS -> Q11 -> Q12 -> Q13 -> Q14 -> none`.
Portfolio entry is available only through the existing book-build guard.

The controlling decision is
`decisions/2026-08-23_owner_gate_manifest_v4_linear.md` section A2: optimization
is mandatory, `KEEP_INCUMBENT` is a valid no-change result, and a book is not
created automatically from a per-EA pass.

## Implementation evidence

- Stable role accessors, versioned news storage lanes, dependency-token
  translation, v3/v4 head-to-head roles, and the disabled historical portfolio
  route: `tools/strategy_farm/gate_manifest.py:225`, `:249`, `:276`, `:325`.
- Pure manifest-object runtime topology builder and manifest-aware successor /
  predecessor accessors: `tools/strategy_farm/phase_ids.py:163`, `:322`, `:328`.
  The runtime policy replaces v3 `Q10 -> Q11` with `Q10 -> Q14` and removes the
  v3 `Q16 -> Q11` runtime back-edge while retaining the raw manifest as history.
- Dynamic promotion, autoseal, optional informational portfolio binding, and
  incumbent enqueue paths: `tools/strategy_farm/farmctl.py:15525`, `:15717`,
  `:15829`, `:15947`, `:16142`.
- V4 head-to-head enqueue binds `BASELINE_Q09 + INCUMBENT_Q11 +
  CHALLENGER_Q11`; v3 retains `PARENT_LINEAGE + CHALLENGER_Q10`:
  `tools/strategy_farm/farmctl.py:25167`. The v4 baseline accepts an exact,
  hash-bound same-EA/symbol Q09 Baseline Full Run row or Q08 evidence row.
- Confirmation execution carries the manifest-resolved gate through tester
  dispatch and aggregate output; the same runner file supports v4 Q09 baseline
  and Q11 incumbent IDs: `framework/scripts/q10_confirmation.py:57`, `:58`,
  `:254`, `:455`.
- Optimization admission/freeze and dependency roles resolve to v3 Q14/Q15 or
  v4 Q12/Q13: `framework/scripts/q14_opt_admission.py:37`, `:38` and
  `framework/scripts/q15_freeze_check.py:56`, `:57`.
- Head-to-head lineage accepts the active incumbent evidence ID:
  `framework/scripts/q16_head_to_head.py:243`.
- SQLite compatibility keeps existing v3 rows readable while accepting the v4
  dependency vocabulary and validating active-manifest confirmation bindings:
  `tools/strategy_farm/q09_news_schema.py:567`, `:584`, `:1413`.
- Health, metrics/cohort analysis, news runner/autoseal census, terminal worker,
  and repair queries now consume manifest-derived phase values in:
  `tools/strategy_farm/health.py`, `tools/strategy_farm/ea_metrics.py`,
  `tools/strategy_farm/analyze_q04_survivor_cohort.py`,
  `tools/strategy_farm/q09_news_runner.py`,
  `tools/strategy_farm/q09_autoseal_hold_census.py`,
  `tools/strategy_farm/terminal_worker.py`, and
  `tools/strategy_farm/repair.py`.
- Static plus runtime activation preflight:
  `tools/strategy_farm/v4_readiness_check.py:32`, `:192`, `:221`.

## Test evidence

Dual-manifest integration coverage is in
`tools/strategy_farm/tests/test_v4_runtime_wiring.py:67`, `:107`, `:182`,
`:219`, `:274`, and `:355`. It executes promotion/autoseal/incumbent enqueue,
confirmation binding/runner propagation, v4 three-edge head-to-head dependency
creation, exact v3/v4 successors and storage lanes, and the no-auto-portfolio
grep guard.

Final touched-module command (from the worktree root):

```text
python -m pytest -q framework/scripts/tests/test_q10_confirmation.py framework/scripts/tests/test_q10_recency.py tools/strategy_farm/tests/test_gate_manifest.py tools/strategy_farm/tests/test_advancement_centralization.py tools/strategy_farm/tests/test_farmctl_cascade.py tools/strategy_farm/tests/test_cascade_real_phase_runners.py tools/strategy_farm/tests/test_phase_runner_process_lineage.py tools/strategy_farm/tests/test_q09_news_schema_v2.py tools/strategy_farm/tests/test_q09_news_farmctl_integration.py tools/strategy_farm/tests/test_q10_confirmation_contract_v2.py tools/strategy_farm/tests/test_q14_opt_admission.py tools/strategy_farm/tests/test_q15_freeze_check.py tools/strategy_farm/tests/test_q16_head_to_head.py tools/strategy_farm/tests/test_book_build_guard.py tools/strategy_farm/tests/test_health_q09_sealed_plan_hold_age.py tools/strategy_farm/tests/test_health_vacuousness.py tools/strategy_farm/tests/test_terminal_worker_q_phase_stall.py tools/strategy_farm/tests/test_terminal_worker_identity.py tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py tools/strategy_farm/tests/test_repair_transition_visibility.py tools/strategy_farm/tests/test_repair_r11_utility_phase_exemption.py tools/strategy_farm/tests/test_v4_runtime_wiring.py
............................................................................................................ [100%]
316 passed, 2 skipped, 10 subtests passed in 98.63s (0:01:38)
```

Readiness and syntax checks:

```text
python -m py_compile <all touched Python runtime modules>
python tools/strategy_farm/v4_readiness_check.py
remaining_hardcoded_v3_gate_literals=0
runtime_violations=0
git diff --check
exit=0
```

`git ls-files --eol tools/strategy_farm/farmctl.py` remained
`i/mixed w/mixed attr/-text`; the `-text` file was not normalized.

## Operational risk and activation note

- V4 remains READ_INERT. The separate orchestrator activation/migration ticket
  must install the OWNER-authorized ACTIVE manifest and migrate/stamp the live
  database before v4 writes occur.
- Role-derived module constants are intentionally process-start values. Factory
  processes must be restarted by the authorized activation procedure after the
  manifest flip; this ticket does not toggle factory state.
- Compatibility SQL deliberately contains both v3 and v4 identifiers. The
  readiness checker reports those occurrences as allowlisted schema/UNION-read
  compatibility, never as dispatch targets.
- No file under `C:/QM/mt5/T_Live` and no runtime state database was changed.

## Rollback

Revert the single ticket commit with `git revert <rb-v4-runtime-commit>`.
This restores the prior runtime code and tests without a database rollback,
because this ticket performs no live migration or state mutation. If the
separate activation ticket has already run, roll that activation/migration back
first under its own runbook; reverting this code alone must not be used against
an active v4 database.

## Review fixes (2026-08-23)

Reviewer verdict FIX_REQUIRED. Two findings addressed.

### P1 — sibling merge conflict in phase_ids.py (merge-order safety)

Verified the P1 finding is already resolved on the branch that owns the fix.
rb-activate carries commit `db0aa2ebc fix(rebaseline): drop rb-activate
phase_ids delta, guard v4 migration entrypoint`, so `rb-activate` no longer
touches `tools/strategy_farm/phase_ids.py` (`git diff --stat be2d247 rb-activate
-- tools/strategy_farm/phase_ids.py` is empty). rb-v4-runtime's own phase_ids.py
bytes are the accumulated correct version and are kept verbatim.

Merge-order confirmation (shared merge-base `be2d247`):

- Real sequential merge into `agents/board-advisor` in a throwaway worktree:
  step1 `rb-v4-runtime` CLEAN, step2 `rb-surfaces` CLEAN, step3 `rb-activate`
  CLEAN (0 unmerged files at every step).
- Pairwise `git merge-tree --write-tree`: v4-runtime+surfaces CLEAN,
  surfaces+activate CLEAN, v4-runtime+activate CLEAN.

A2 runtime policy invariant re-verified on rb-v4-runtime (active schema
`qm.gate-manifest/v3`, v4 READ_INERT):

- `build_advancement_table` path from Q08: `Q08 -> Q09_NEWS -> Q10 -> Q14 ->
  Q15 -> Q16` (Q16 terminal). Q10 advances to Q14, not Q11.
- `portfolio_route(optimized=False)` and `portfolio_route(optimized=True)` both
  return `None` — the auto-portfolio / Q16->Q11 back-edge stays neutered.

### P2 — BASELINE_Q09 required_verdicts contract mismatch (fixed)

`tools/strategy_farm/farmctl.py`: the v4 head-to-head baseline lane is
legitimately allowed a `FAIL_SOFT` parent (baseline selection query and the
`BASELINE_Q09` insert trigger both admit `verdict IN ('PASS','FAIL_SOFT')`), but
the dependency was bound via `_ensure_q16_dependency -> add_dependency` with a
hardcoded `required_verdicts=['PASS']`. This is more than cosmetic once v4
activates: the append-only `trg_wid_validate_insert` trigger rejects any
dependency whose parent verdict is not in `required_verdicts_json`, so a
`FAIL_SOFT` baseline bound with `['PASS']` would be ABORTed.

Fix: threaded `required_verdicts` through `_q16_dependency_spec` (default
`('PASS',)`) into `_ensure_q16_dependency` (used for both the append and the
idempotent re-verify comparison), and bound the BASELINE_Q09 spec with
`('PASS','FAIL_SOFT')`. The confirmation/incumbent/challenger lanes keep the
PASS-only default. v4 is READ_INERT, so no live migration is implied.

Tests (`tools/strategy_farm/tests/test_q16_head_to_head.py`):

- `test_baseline_q09_dependency_records_fail_soft_verdict_set` — FAIL_SOFT
  baseline binds and stores `["PASS","FAIL_SOFT"]`, idempotent re-verify passes.
- `test_baseline_q09_pass_only_binding_is_rejected_for_fail_soft_parent` —
  regression guard: `['PASS']` on a FAIL_SOFT baseline is rejected by the
  insert trigger.
- `test_default_dependency_spec_stays_pass_only` — default lanes remain
  PASS-only.

Test run: `test_q16_head_to_head.py` 11 passed; `test_v4_runtime_wiring.py` +
`test_gate_manifest.py` + `test_q09_news_farmctl_integration.py` 56 passed,
2 skipped.
