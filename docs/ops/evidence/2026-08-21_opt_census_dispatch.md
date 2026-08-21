# OPT_CENSUS dispatchable end-to-end — TASK B (DL-089 §3, S1/S2 infra half)

**Date:** 2026-08-21
**Author:** Claude (board-advisor lane)
**Scope:** Make phase `OPT_CENSUS` claimable → runnable → bindable → scored, without
leaking into funnel/gate metrics. Optimization branch only (Q14→Q16 measurement
pool per DL-089). Core funnel Q00–Q13 untouched; no verdict history rewritten.
**Authorities:** `docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md` §3
(OPT-S1/S2), `decisions/DL-089_pattern_filter_wf_census_v3.md`,
`decisions/DL-088_optimization_track_v2_levers_and_overfit_contract.md`.

## What an OPT_CENSUS work item is

One `OPT_CENSUS` row = **ONE windowed single-year backtest** of an `_opt` EA with a
specific setfile (one pattern arm active) and an explicit calendar-year date window.
It runs the ordinary `run_smoke.ps1` path (NOT a phase runner), produces the standard
`summary.json` + self-report stream, and binds evidence like any Q02 row. It is a
**measurement, never a gate**.

## Prior state (reconciliation)

The OPT-S1 generator was already committed by Codex in `0298a5f42` ("Add DL-089
annual OPT census tooling"): `tools/strategy_farm/opt_census.py` plans/enqueues the
1,085-cell matrix (7 years × 155 arms) as append-only `phase='OPT_CENSUS'`,
`kind='backtest'`, `verdict=NULL`, `parent_task_id=NULL` rows, and writes the DL-089
ledger (`qm.opt-census.v1`, `declared_trial_count=154`). That commit also added a
first-cut run-path branch reading payload keys **`from_date`/`to_date`** and a
`_opt_census_` setfile marker.

**Key-name discrepancy (reported, not silently reinterpreted):** TASK B specified the
window keys `opt_from_date`/`opt_to_date`; the committed generator writes
`from_date`/`to_date`. Filesystem/committed truth wins for correctness, so the run
path accepts **both**, preferring `opt_from_date`/`opt_to_date` and falling back to
`from_date`/`to_date` (`farmctl._opt_census_window`). This keeps the already-enqueued
rows runnable AND satisfies the task's canonical spelling. **Open item for the
orchestrator:** standardise the generator's payload key names (or ratify the plain
keys) so the dual-spelling fallback can later be removed.

## Changes (all `tools/strategy_farm/`)

### 1 · DISPATCH — `farmctl.pending_claim_order_sql()`
Added `WHEN 'OPT_CENSUS' THEN 6` to the phase-rank CASE (Q04's tier). OPT_CENSUS rows
are never `priority_track`, so their effective claim term is `1*10 + 6 - age = 16` —
identical to an ordinary (non-priority) Q04 row. Consequence, proven in the probe:
every `priority_track` funnel row and every downstream phase (Q05..Q10 at ranks 5..0)
drains first; OPT_CENSUS **interleaves** with ordinary Q04 and **out-ages Q02** (term
18). The measurement pool never leads and never starves the funnel.

No positive phase allowlist gates the claim path (the claim SQL selects any pending
phase minus explicit exclusions), so no whitelist needed registration there.
OPT_CENSUS is deliberately **NOT** added to `CASCADE_BACKTEST_PHASES` /
`SUPPORTED_BACKTEST_PHASES` — it is a leaf measurement with no successor.

### 2 · RUN PATH — `farmctl._spawn_run_smoke_for_work_item`
The committed `elif phase == "OPT_CENSUS"` branch is unified onto two testable
helpers:
- `_opt_census_window(payload)` — resolves the single-year window (opt_* preferred,
  plain-key fallback), **fails closed** on missing / malformed / reversed bounds
  (`spawned:False, reason:"opt_census_window_invalid"`), never silently falling back
  to a full-history run.
- `_opt_census_timeout_seconds(payload)` — preserves the committed `P2_FULL_TIMEOUT_MIN`
  floor; honours a `timeout_min` payload override (extend-only).

`n_runs="1"` (one deterministic model-4 measurement per cell), `p2_run_stage=None`.
The window flows to `run_smoke.ps1` through the existing `-FromDate`/`-ToDate` args
and is captured as `expected_from_date`/`expected_to_date`, so MNT-009 evidence
binding (`_summary_matches_expected_evidence`, `evidence_binding_required=True`) binds
the summary to the exact single-year window exactly as for a Q02 row.
OPT_CENSUS is exempted from the `DWX_MULTI_SYMBOL_FULL_HISTORY_FROM` start-clamp (same
treatment as the FTMO book-3 exact window) so the per-cell bounds stay immutable
evidence.

### 3 · VERDICT — MEASURED semantics
New `farmctl._apply_measurement_phase_verdict(phase, verdict, reason, payload)`:
for measurement phases, a healthy completion (any gate token PASS/FAIL/ZERO_TRADES)
collapses to verdict **`MEASURED`**, taxonomy **`measurement`**, reason
`opt_census_measured` (the underlying gate verdict/reason are preserved in payload
`opt_census_underlying_*` for the S3 walk-forward analysis, but kept OUT of
`verdict_reason` so the cockpit zero-trade scan can't pick them up). `INFRA_FAIL`
keeps the standard infra retry/binding path. Non-measurement phases pass through
unchanged (`infra`/`strategy`). Wired into BOTH classification sites: the
terminal-worker `_finish_work_item` path and the `farmctl.dispatch_work_items`
secondary-claimant path. (The P5/P5b/P6-only artifact-recovery site is unreachable
for OPT_CENSUS and left untouched.)

**MNT-016 clean-view invariant extended** (`work_item_clean_view.py`): the
`measurement` taxonomy is added to `TERMINAL_STATUS_BY_TAXONOMY` (→ `done`),
`verdict_taxonomy()` maps `MEASURED → measurement`, and both SQL projections
(`taxonomy_sql`, `status_sql`) admit it. The `(done, MEASURED, measurement)`
combination is a valid, disjoint family — it does NOT reuse PASS/`strategy`, so it
never enters `gate_pass`/`economic_fail` counts.

**Terminal-verdict vocabulary extended** so `MEASURED` is a recognised terminal token
(not a hard crash): added to `farmctl.CANONICAL_PARENT_CHILD_VERDICTS` (parent-closure
/ reconciler acceptance; OPT_CENSUS rows carry no parent so no cascade aggregation)
and to `work_item_lifecycle_v2.SUCCEEDED_VERDICTS` (the read-only lifecycle inventory
raises on any unknown verdict — this keeps it from failing closed once MEASURED rows
exist). The pinned identity `KNOWN_VERDICTS == CANONICAL ∪ placeholders` still holds.

### 4 · METRICS ISOLATION (verified)
- `mission_control_v2_data.MT5_TESTER_PHASES` already excludes OPT_CENSUS → throughput
  `completed`/`gate_pass`/`economic_fail` and the ETA drain all exclude it.
- `health.py` q02_* checks are scoped to `phase IN ('Q02','P2')` → exclude it.
- `phase_age_slo_snapshot` now skips `PHASE_AGE_SLO_EXCLUDED_PHASES = {OPT_CENSUS}` so
  a fresh 1,085-row batch does not read as an UNKNOWN-threshold WARN or a mass
  violation.
- MC-v2 `build_queue` shows OPT_CENSUS under `by_phase_parked` (its own phase),
  excluded from `pending_executable` — correct per task.
- Public website (`website_archive_contract._public_gate`) drops any phase not in
  `PHASE_ORDER` → OPT_CENSUS never reaches public data.

## Tests

New: `tools/strategy_farm/tests/test_opt_census_dispatch.py` (16 tests) —
claim-rank tier-6/non-priority probe + interleave-not-ahead; window pass-through
(opt_* preferred, fallback, fail-closed on missing/malformed/reversed) + timeout
override; MEASURED remap (PASS/FAIL→MEASURED, INFRA_FAIL kept, non-measurement
passthrough) + canonical-token check; clean-view derive + SQL projection of MEASURED;
MT5-phase exclusion + `build_progress` gate_pass excludes a MEASURED row;
phase-age-SLO ignores a fresh census batch.
Extended: `test_work_item_clean_view.py` invariant parametrization gains the
`(done, MEASURED, measurement)` case.

### Results
```
test_opt_census_dispatch.py .................... 16 passed
test_work_item_clean_view.py + test_work_item_lifecycle_v2.py + test_opt_census.py
  + test_priority_track_new_q02.py + test_mnt009_010_reconciliation.py
  + test_optimization_track_manifest_v2.py .................... 68 passed
Broad sweep (farmctl/terminal_worker/dashboard/cockpit/mission_control/dispatch/
  verdict/classif/cascade/evidence_binding/q02/wsa_claim, ~680 tests) ... 679 passed,
  1 failed
```
The single failure — `test_prepare_ftmo_book3_q02.py::test_real_a02_compile_manifest_loads_when_present`
(`compile manifest FACTORY_OFF binding drifted`) — is **environmental and
pre-existing**: it validates a real on-disk compile manifest against the live
`FACTORY_OFF` flag SHA, which drifts with live factory state. It has zero references
to OPT_CENSUS/MEASURED and I did not modify `prepare_ftmo_book3_q02.py`.

## Not in this task (handoff)
- OPT-S0 (`_opt` EA build) and OPT-S1 payload/setfile generation are Codex's
  (`opt_census.py` already committed); OPT-S3 walk-forward analysis is Claude's.
- Live workers do NOT self-reload farmctl/terminal_worker — the orchestrator restarts
  idle workers after commit for the new dispatch/verdict logic to take effect.
- Standardise the generator's window payload keys (see reconciliation above), then the
  dual-spelling fallback in `_opt_census_window` can be tightened to one spelling.
