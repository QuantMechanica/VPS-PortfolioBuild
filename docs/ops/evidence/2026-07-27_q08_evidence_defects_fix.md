# Q08 evidence-production defects — mechanism and fix (census rank 7)

Date: 2026-07-27
Author: Claude (board-advisor worktree)
Scope authority: `docs/ops/evidence/2026-07-27_factory_loose_ends_census.md` (router task
`621d3c75`), rank 7: `8.5_neighborhood artifact_missing` (94) + `8.7_pbo got=0` (81).
Constraint honored: **no Q08 rows re-run**; this is a code-forward fix + classification +
regression tests. Re-running the ~209 historical INFRA_FAIL rows remains an OWNER capacity
decision.

---

## 1. What the two defects actually are (established from disk, not inferred)

Distribution across the **on-disk aggregates** of the 211 Q08 rows the DB marks
`INFRA_FAIL`/`INVALID` (151 aggregate.json files resolved; 60 had no aggregate on disk):

Full 8.5 detail (attempt-level):

| count | 8.5 detail |
|---:|---|
| 94 | `neighborhood_evidence_lineage_invalid:artifact_missing` |
| 22 | `all_{3,4}_valid_perturbations_within_plateau` (i.e. 8.5 actually PASSED) |
| 18 | `neighborhood_evidence_lineage_invalid:degenerate_baseline` |
| 15 | `neighborhood_evidence_lineage_invalid:baseline_setfile_defect:empty_strategy_params` |
| 2 | `neighborhood_evidence_lineage_invalid:evidence_status_missing_or_invalid` |

Full 8.7 detail (attempt-level):

| count | 8.7 detail |
|---:|---|
| 89 | `insufficient_distinct_configs:got=0:need>=2` |
| 25 | `insufficient_distinct_configs:got=1:need>=2` |
| 20 | `insufficient_common_even_slices:got=7:need_even>=2` |
| 13 | computed `PBO=..%` (a real verdict) |
| rest | `pbo_refresh_lineage_invalid`, `pbo_runner_scores_missing`, `insufficient_pbo_splits` |

These reconcile with the census headline (94 / 81; the census sampled a slightly earlier DB
snapshot for 8.7).

### 1a. The two headline cohorts are ONE cascade, not two independent bugs

For **every** sampled `8.7 got=0` case the neighborhood `perturbations.json` is absent at PBO
time. The PBO runner reconstructs its config family from (a) the Q03 sweep grid and (b) the
Q08.5 neighborhood configs. When the neighborhood artifact is absent/discarded AND the Q03
sweep yields `<2` distinct configs, the family is empty → `got=0`. So an absent neighborhood
artifact starves **both** 8.5 (`artifact_missing`) **and** 8.7 (`got=0`).

Evidence: `insufficient_distinct_configs:got=0` cases inspected → neighborhood
`evidence_status = NO_PERTURB_JSON` (perturbations.json absent) in all sampled cases.

### 1b. The naive "fixed-parameter" hypothesis is FALSE for these historical rows

The task asked whether `got=0` is "a strategy with fixed parameters, where a neighborhood is
undefined by construction." Checked directly against disk: **no** — none of the sampled
`got=0` distinct EAs is `structurally_inapplicable`. They carry 4–10 perturbable params and,
where the artifact survived, a **VALID** neighborhood:

- `QM5_11124 SP500.DWX`: on-disk `perturbations.json` is `evidence_status=VALID`, 7 eligible
  params, VALID baseline — yet 8.5 reported `baseline_setfile_defect:empty_strategy_params`.
  Cause: the aggregate's `_guess_baseline_setfile` resolved the plain
  `..._SP500.DWX_D1_backtest.set`, which has the strategy-block **header but no params**
  (`parse_setfile_assignments → 0`), while the Q03 pick that produced the valid artifact was
  `..._backtest_ablation_02.set` (7 params, sha `6988d5…`). The valid evidence was discarded
  as a false "setfile defect".
- `QM5_11916 GBPUSD.DWX`: the guessed setfile is now correct (4 params, `inspect` OK) — its
  INVALID is a **stale historical snapshot**; a natural re-run would clear it.

So the historical `got=0`/`artifact_missing` mass is a **production/lineage cascade**
(absent-or-mis-resolved neighborhood artifact), not structural inapplicability. The
`baseline_setfile_defect:empty_strategy_params` label is itself two distinct realities: a
genuinely un-materialised card (`; card_defaults_source=not_found`, no populated variant —
correctly a deterministic build defect) versus a resolver picking the empty template when a
populated sibling exists (`11124`). See §3 for why the latter is a build-lane concern, not a
Q08-reader concern.

### 1c. The genuine fixed-parameter NOT-APPLICABLE case is real — and mishandled

Independently of the historical cascade, a **fixed-parameter strategy** (every strategy input
fixed / structural / a categorical flag) has **no ±10% neighborhood and no ≥2-config PBO
family BY CONSTRUCTION**. The system already has the concept —
`q08_5_neighborhood_runner` computes `structurally_inapplicable` and `q08_7_pbo_runner`
emits meta `status=INVALID_NA` — but it was mis-wired end to end:

- **Gap A (8.5 sub-gate ignored the signal):** `sub_8_5_neighborhood.run()` never read
  `structurally_inapplicable`/`evidence_status`; an all-fixed card (baseline VALID, empty
  perturbations) hit `no_perturbations_tested_vacuous_pass` → a **blocking INVALID** that,
  via the NARROW C2 tooling whitelist, reads as retry-owed INFRA_FAIL — a retry that can
  never invent a neighborhood.
- **Gap B (runner under-detected the case):** `structurally_inapplicable` was derived from the
  fixed-*stripped* Q03 pick, so an **all-categorical card** (empty post-filter pick) computed
  `bool(classifications)=False → structurally_inapplicable=False`. Proven:
  post-filter pick `{}` → OLD `False`, NEW `True`.
- **Gap C (8.7 sub-gate downgraded the signal):** meta `INVALID_NA` was mapped to a plain
  `INVALID` (`INVALID_NA:<reason>`) → reads as failure, not "not applicable".
- **Gap D (aggregator had no NA path):** a `NOT_APPLICABLE` sub-gate status would fall
  through to `_classify_fail → EDGE_HARD → FAIL_HARD`. There was no non-punitive lane.

---

## 2. The fix

A distinct, non-punitive **`NOT_APPLICABLE`** sub-gate status, threaded end to end, emitted
**only on the runner's authoritative structural determination** — never on the ambiguous
`insufficient_distinct_configs` sub-gate signal, which the sub-gate cannot prove is structural
from `scores.csv` alone and which therefore **stays** a NARROW C2 tooling INVALID → INFRA_FAIL
(decisions/2026-07-25_q08_tooling_invalid_is_infra.md preserved intact).

| # | File | Change |
|---|---|---|
| A | `framework/scripts/q08_davey/aggregate.py` | `_aggregate_verdict`: a `NOT_APPLICABLE` sub-gate is classified `NOT_APPLICABLE`, treated like `INFORMATIONAL` — no fail/soft/infra weight, and within the DL-082 §3c PASS allowance (`_label_within_pass_allowance`). Added `summary.n_not_applicable`. |
| B | `framework/scripts/q08_davey/sub_8_7_pbo.py` | meta `status=INVALID_NA` → `NOT_APPLICABLE` (`not_applicable:<reason>`). Plain meta `INVALID` unchanged (stays a blocking/tooling INVALID). |
| C | `framework/scripts/q08_davey/sub_8_5_neighborhood.py` | payload with `evidence_status=INVALID_NO_PERTURBABLE_PARAMS` **and** `structurally_inapplicable=True` (baseline VALID) → `NOT_APPLICABLE`. A bare empty-perturbation payload (no flags) still → the vacuous-pass INVALID. |
| D | `framework/scripts/q08_5_neighborhood_runner.py` | new pure helper `baseline_is_structurally_inapplicable(...)` derives structurality from the FULL baseline inventory; `main()` now sets `structurally_inapplicable = not eligible and baseline_is_structurally_inapplicable(...)`. |
| E | `tools/strategy_farm/farmctl.py` | `_q08_insufficient_trades_reason` skip-set now treats `NOT_APPLICABLE` like `PASS`/`INFORMATIONAL` (non-blocking). |

**Non-punitiveness downstream (verified):** a fixed-parameter EA no longer produces a
top-level `NOT_APPLICABLE` verdict — NA lives only at the sub-gate level, so the EA is judged
on its **applicable** merit gates and lands `PASS`/`FAIL_SOFT` (Q09 portfolio track), never a
blocking INVALID or a retry-owed INFRA_FAIL. The top-level verdict set is unchanged, so
dashboards (`render_dashboards.py`, keyed on `work_items.verdict`), the sleeve funnel, and the
portfolio contribution reader (`portfolio_q08_contribution.py`, keyed on 8.10 only) need no
change. NA detail strings deliberately avoid every `Q08_GENUINE_INFRA_DETAIL_TOKENS` token, so
a NA gate never reads as genuine infra in reason backfill.

**Precedence (locked by test):** `NOT_APPLICABLE` carries no weight, so a computed robustness
breach elsewhere (`FAIL`) still yields `FAIL_HARD` — NA never launders a real failure into a
PASS.

### End-to-end verification (no re-run of any work item)

- PBO runner fed a `structurally_inapplicable` neighborhood → meta `status=INVALID_NA`,
  `reason=structurally_inapplicable_config_family` → 8.7 sub-gate → `NOT_APPLICABLE`,
  `detail=not_applicable:structurally_inapplicable_config_family`.
- Neighborhood runner `main()` on an all-fixed card (backtests stubbed) →
  `evidence_status=INVALID_NO_PERTURBABLE_PARAMS`, `structurally_inapplicable=True`.
- Gap-B discriminator: all-categorical card (empty post-filter pick) → OLD `False`, NEW `True`.

---

## 3. Deliberately NOT changed (scope discipline)

- **`_guess_baseline_setfile` (the `11124` empty-template resolution bug).** Preferring a
  populated sibling would mean choosing among arbitrary `_ablation_00/01/02` variants as the
  canonical neighborhood baseline — a **build/setgen-lane semantic decision**, and the
  downstream sha-lineage gate already refuses a wrong pick. The canonical fix is to
  materialise card defaults into the `_backtest.set` template, not to have the Q08 evidence
  reader guess. `baseline_setfile_defect:empty_strategy_params` stays a deterministic blocking
  INVALID (its existing, correct classification for an un-materialised card).
- **The NARROW C2 `insufficient_distinct_configs` / `neighborhood_evidence_lineage_invalid`
  → INFRA_FAIL routing.** Left intact; NA is additive and gated on the *provably structural*
  signal only.
- **No Q08 row re-run; no work-item mutation.**

---

## 4. Regression tests (added to `framework/scripts/tests/test_q08_davey_subgates.py`)

Mechanism 1 (neighborhood NA):
- `test_neighborhood_structurally_inapplicable_is_not_applicable_not_invalid`
- `test_neighborhood_empty_perturbations_without_structural_flag_stays_invalid` (guard)
- `test_baseline_is_structurally_inapplicable_helper` (Gap B)

Mechanism 2 (PBO NA):
- `test_pbo_meta_invalid_na_is_not_applicable_not_invalid`
- `test_pbo_meta_plain_invalid_stays_invalid` (guard — NARROW C2 preserved)

Downstream / precedence:
- `test_not_applicable_subgates_do_not_block_clean_pass`
- `test_not_applicable_never_rescues_a_genuine_hard_fail`

Result: `test_q08_davey_subgates.py` 82 passed; taxonomy/reason/readiness suites 40 passed
(`test_verdict_taxonomy_ws2`, `test_ultracode_wsh_q08_reason`, `test_gate_summary_marker_wp57`,
`test_qm5_12580_q08_readiness`). The 3 failing `test_cascade_real_phase_runners` cases are
pre-existing environmental subprocess-spawn failures (identical on unmodified code:
`spawned process ... exited before identity capture`, farmctl.py:3404), unrelated to this fix.

---

## 5. Residual (for OWNER / build lane, not this task)

1. The historical ~209 Q08 INFRA_FAIL rows are unchanged by design. A future re-run (OWNER
   capacity decision) would reclassify: genuine fixed-parameter cards → clean merit verdict
   with 8.5/8.7 `NOT_APPLICABLE`; the mis-resolved-setfile cases (`11124`) → reuse of the
   already-VALID neighborhood.
2. Build lane: materialise card defaults into `_backtest.set` templates that carry only the
   empty strategy header, so `_guess_baseline_setfile` cannot resolve a param-less baseline.
