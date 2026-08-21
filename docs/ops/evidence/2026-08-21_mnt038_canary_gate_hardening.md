# MNT-038 canary-before-fanout gate hardening (2026-08-21)

Repairs two confirmed defects (plus two gaps) in the MNT-038 Q02
canary-before-fanout gate delivered by Codex in `3fa1485a6` + `813532ce4`, which
my adversarial code review BOUNCEd. The gate stages one liquidity-ranked FX
canary per built cohort and defers the rest; `_q02_canary_fanout_decision`
decides STOP / WAIT / RELEASE / CONFIRM from the canary evidence, and
`sweep_enqueue_built_eas.py` Part 3 acts on that decision against the deferred
sidecar `q02_deferred_symbols.json`.

Scope of edit: `tools/strategy_farm/farmctl.py` (canary decision helpers only),
`tools/strategy_farm/sweep_enqueue_built_eas.py`, and the two test files. No gate
threshold, verdict logic, or contract criterion was changed — this is a dispatch
gate; per-symbol Q02 economics (below-floor = RETIRE) remain the real judge.

## DEFECT 1 (primary) — identical-null STOP preempts per-symbol economics

**Broken:** `>=2` canary hosts returning a byte-identical bare `ZERO_TRADES`
signature (`verdict|Q02_ZERO_TRADES`) triggered `identical_null_signal_confirmed`
STOP with no corroborating defect class. Because the canary order is
liquidity-ranked FX majors (EURUSD, USDJPY, GBPUSD, …), a genuine metal/index/
cross strategy in a mixed cohort drew two quiet FX canaries and its whole cohort
was killed before its active symbol was ever probed — a dispatch gate preempting
the per-symbol economics floor.

**Fixed:** null confirmation is now cohort-aware. `_q02_canary_fanout_decision`
takes a new `cohort_symbols` argument (canaries + still-deferred setfiles). Before
an identical-null STOP is permitted it compares the probed asset classes against
the asset classes present in the whole cohort (asset class derived from
`framework/registry/dwx_symbol_matrix.csv` via the new cached `_q02_asset_class`,
falling back to the coarse `_q02_symbol_bucket`). If any asset class in the cohort
is still unprobed it returns `action=CONFIRM`,
`reason=identical_null_requires_cross_asset_confirmation`, and
`promote_asset_classes=[...]`. The sweep's CONFIRM handler then promotes the
lowest-ranked deferred host from those classes first. A cohort may only be
null-stopped once **every** asset class present has produced the identical bare
null (`reason=identical_null_signal_confirmed`). Homogeneous all-FX cohorts still
STOP, preserving the behavior for genuinely dead strategies. Defect-class
signatures (ONINIT/INVALID/…) keep today's fast STOP untouched.

farmctl.py: `_q02_asset_class` (new), `_q02_canary_fanout_decision`
(`cohort_symbols` param + cross-asset branch). sweep: Part 3 passes
`cohort_symbols`; CONFIRM handler honours `promote_asset_classes`.

## DEFECT 2 — `fanout_state=STOPPED` is a terminal sink

**Broken:** the sweep short-circuited any `STOPPED` sidecar entry forever
(`sweep_enqueue_built_eas.py:896`), and `STOPPED` was written on the first sight
of any deterministic-stop canary. A transient infra canary
(`NO_HISTORY` / `INCOMPLETE_RUNS` — a documented first-attempt cold-cache
condition that self-heals) permanently stranded the cohort's healthy symbols.

**Fixed, two parts:**

(a) *No terminal STOP on first infra sight.* `_q02_canary_outcome` now
sub-classifies a deterministic stop into `hard_defect` vs `transient_infra`
(`stop_class`): a bare `INFRA_FAIL` whose signature carries no hard-defect token
(`ONINIT`, `INVALID`, `DRAFT_DEFECT`, `COMPILE`, `MAGIC`, `PIN`, `SETFILE`) is
transient. A hard defect keeps the fast STOP. A transient-infra canary returns
`action=WAIT`, `reason=transient_infra_awaiting_confirmation` until its terminal
INFRA_FAIL rows (append-only reruns driven by Part 2) reach
`Q02_CANARY_INFRA_STOP_ATTEMPTS=3`, at which point it STOPs with
`confirmed_infra_canary_failure`.

(b) *STOPPED is re-evaluable.* Each sweep, for a STOPPED entry, the new
`_q02_canary_revival` runs one cheap scan of the already-fetched Q02 rows: if a
canary produced an economic outcome (PASS or any per-symbol economic verdict)
*after* `fanout_stopped_at`, the stop is contradicted and the cohort re-opens
(`fanout_state → AWAITING_CANARY`, annotated with `release_reason`,
`fanout_revived_at`, `fanout_revival_history`), falling through to a fresh
decision that RELEASEs. No verdict is ever written. Idempotent: once RELEASE
promotes the last deferred symbol the entry is popped from the sidecar, so the
next sweep is a no-op.

## GAP 3 — apply-mode end-to-end STOP coverage

Added `test_deterministic_defect_canary_stops_cohort_in_apply_mode`: a real
`--apply` subprocess sweep against a temp DB with a hard-defect (INVALID) canary
asserts `fanout_state=STOPPED` persisted in the sidecar, deferred setfiles kept,
and zero new pending Q02 rows — mirroring the existing RELEASE subprocess test.

## GAP 4 — legacy sidecar entries rewritten unannotated

**Broken:** legacy entries (e.g. QM5_10001 / QM5_11755, `deferred_at`
2026-06-29, `requeue_excluded_q02`, no `fanout_*` fields) were persisted back to
the sidecar unannotated, riding it in an unevaluated format.

**Fixed:** the sweep's requeue-excluded branch now stamps
`fanout_policy=qm-q02-canary-fanout/v1` and `fanout_state=LEGACY_EXCLUDED` before
keeping the entry deferred. Covered by
`test_legacy_requeue_excluded_entry_is_annotated_in_apply_mode`.

## Tests

New unit tests (`test_mnt038_canary_fanout.py`): mixed-cohort cross-asset
promotion, homogeneous-FX still-stops, cross-asset-confirmed final stop,
transient-infra WAIT (1 attempt), transient-infra STOP (3 attempts), hard-defect
first-sight STOP, revival on later economic verdict, no-revival without a newer
economic row. New subprocess tests (`test_sweep_enqueue_built_eas.py`):
mixed-cohort gold promotion, deterministic-defect STOP (GAP 3), legacy annotation
(GAP 4), STOPPED-unstop-on-later-PASS with idempotency (DEFECT 2b).

Verbatim tails:

```
$ python -m pytest tools/strategy_farm/tests/test_mnt038_canary_fanout.py -q
..............                                                           [100%]
14 passed in 0.22s

$ python -m pytest tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py -q
............                                                             [100%]
12 passed in 4.77s

$ python -m pytest test_mnt038_canary_fanout.py test_sweep_enqueue_built_eas.py \
    test_requeue_stranded_infra.py test_p2_full_dwx_fanout.py -q
.........................................................                [100%]
57 passed in 31.13s

# adjacent farmctl-importing suites (no collateral breakage)
$ python -m pytest test_zero_trade_prevention.py test_farmctl_cascade.py \
    test_candidate_repair_enqueue.py test_governed_work_item_hold.py -q
72 passed, 4 subtests passed in 20.44s
```

## Files changed

- `tools/strategy_farm/farmctl.py` — constants
  (`Q02_CANARY_INFRA_STOP_ATTEMPTS`, hard/transient token sets); new
  `_q02_asset_class`, `_q02_terminal_infra_attempts`, `_q02_canary_revival`;
  `_q02_canary_outcome` `stop_class`; `_q02_canary_fanout_decision`
  `cohort_symbols` + transient-infra confirmation + cross-asset null branch.
- `tools/strategy_farm/sweep_enqueue_built_eas.py` — Part 3 reordered
  (rows/canary computed before the STOPPED check), STOPPED revival, cohort-aware
  decision call, CONFIRM cross-asset promotion, GAP 4 legacy annotation.
- `tools/strategy_farm/tests/test_mnt038_canary_fanout.py` — 8 new unit tests.
- `tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py` — 4 new subprocess
  tests + `_canary_apply_env` / `_insert_canary_row` helpers.

## Rollback

`git revert` the orchestrator's commit of these four files. The changes are
additive to the decision surface (new optional param defaults to prior behavior,
new sidecar states are annotations); reverting restores the prior
`3fa1485a6` gate exactly. No DB migration, no verdict rows written.

## Risks / notes

- `_q02_asset_class` reads the matrix via `REPO_ROOT` (the live repo), so the
  subprocess sweep resolves real asset classes even under a temp
  `QM_CANONICAL_REPO_ROOT`; symbols absent from the matrix fall back to the
  coarse bucket heuristic.
- Cross-asset confirmation adds at most one extra probed host per unprobed asset
  class before a null STOP (bounded, terminating): worst case one additional Q02
  backtest per asset class present in a dead cohort.
- Transient-infra confirmation relies on Part 2's existing stranded-infra requeue
  to accumulate attempts; a canary that never re-runs stays WAIT (deferred,
  healthy symbols not promoted) rather than STOPPED — a conservative,
  self-healing default consistent with the cold-cache runbook.
