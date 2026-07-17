# Q08 stale-cache and PBO-source calibration

Date: 2026-07-17  
Router task: `c10e5447-6e70-40ff-9e14-7bfe24a5823a` (`triage_failure`, Codex)  
Requested next state: `REVIEW`  
Main implementation commit: `fba60b795`  
Canonical board deployment commit: `29f2ed8af`

## Review verdict

READY FOR REVIEW at code/evidence level. The current Q08 engine already fails closed on stale or
degenerate neighborhood cache artifacts; this packet adds direct current-schema regression coverage
for that contract. Q08.7 now carries its configuration-family source into the result and calibrates
severity by scientific role: a real Q03 selection cohort retains the existing hard-fail policy, while
an explicit Q08.5 local-neighborhood fallback can emit a PBO failure but is capped at `EDGE_SOFT`.
Missing or unknown source remains fail-closed under the historical policy.

No fresh pipeline verdict is claimed. The QM5_12567/XNGUSD retry did not produce a new aggregate,
and the QM5_11708 replay below is a read-only classification check, not pipeline evidence.

## A. Stale-degenerate neighborhood reuse

The cited QM5_12567/XNGUSD evidence is historical rather than a fresh July 17 aggregate:

- `D:/QM/reports/pipeline/QM5_12567/Q08/neighborhood/XNGUSD_DWX/perturbations.stale_manual_quarantine_20260717T21Z.json`
  has mtime `2026-06-26T19:54:20.0173307Z`, SHA-256
  `c7ec2c6045634a5e94eb1033cb7fcfe56686d7944229f41d0f907afab2e754ec`, a zero-trade/null-PF
  baseline, no tested parameters, and no perturbations.
- The archived work-item aggregate under
  `D:/QM/reports/work_items/084a05e0-99cf-435e-bce3-d464d97081e0.requeued_manual_20260717T1705Z/`
  has mtime `2026-06-26T22:27:14.9732471Z` and `sub_gate_input_runs={}`. That matches the old
  existence-only cache behavior: the file prevented dispatch, then Q08.5 read it as a degenerate
  artifact.
- The July 17 database retry ended `INFRA_FAIL` with
  `final_failure=summary_missing_retries_exhausted`; its expected report root is absent. It did not
  regenerate the archived aggregate and cannot establish a new Q08 verdict.

Current code already closes the engine defect through commits `731c05338`, `be670c3de`, and
`6f02e31f5`. `_neighborhood_artifact_reuse_status` requires the current schema and engine, exact
symbol/setfile/parameter-source lineage, a valid traded baseline with PF and DD, and at least two
distinct non-degenerate valid perturbations. `_ensure_sub_gate_inputs` quarantines any rejected
artifact, dispatches a new Q08.5 run, post-validates it, and records the support-run metadata.
Failed refresh remains blocking `INVALID`; it cannot fall back to the stale file.

This task adds regression assertions against a fully current, exact-lineage schema-v2 artifact:

- baseline `status=VALID` with `trades=0`, `pf=null`, `dd=null` is non-reusable with reason
  `degenerate_baseline`;
- a row labeled `VALID` with zero trades/null PF is non-reusable with reason
  `valid_perturbation_degenerate`.

The pre-existing legacy-artifact, exact-lineage, and quarantine-failure tests remain intact.

## B. PBO on a Q08.5 plateau

QM5_11708/EURUSD evidence demonstrates a source-role mismatch, not a reason to change the raw PBO
threshold:

- `scores_meta.json` is schema v2 and records `config_source=Q08.5_neighborhood`, five distinct
  configurations, eight common slices, and only one Q03 candidate configuration.
- The existing calculator reports 22 overfit splits out of 35, PBO `62.857143%`.
- Q08.5 is valid: baseline PF `1.30`, DD `4366.72`, 178 trades; all four perturbations are valid,
  with PF `1.08` to `1.30` and DD `2630.06` to `5962.93`, below the hard neighborhood limit of
  `6550.08` (1.5 times baseline DD).
- The baseline and one distinct setfile produce the same 178 trades, PF, DD, and slice score vector.
  Rank instability in this small local-equivalence family is not evidence that Q03 selected an
  overfit winner.

PBO is a model-selection diagnostic. Q03 configurations form the candidate family from which a
winner can be selected; Q08.5 perturbations are generated after selection to test local sensitivity.
The implemented calibration therefore is:

| Configuration source | Q08.7 behavior |
|---|---|
| `Q03` | Existing policy unchanged: `<40%` PASS, `40-55%` soft, `>55%` hard. |
| `Q08.5_neighborhood` | Raw PBO and FAIL result remain visible, but aggregate severity is capped at `EDGE_SOFT`. |
| missing / unknown | Historical fail-closed classification remains unchanged. |
| invalid family / lineage | Still blocking `INVALID`; source calibration does not soften missing evidence. |

`sub_8_7_pbo.run` now publishes `config_source`, `q03_candidate_configs`, and
`neighborhood_candidate_configs` in its evidence and detail. The aggregate records the source policy
in `verdict_calibration`, making future reports self-describing.

The task deliberately does not introduce an ad-hoc plateau null, equivalence margin, or new PBO
threshold. A separate conformance concern was observed in the legacy raw calculator (complementary
CSCV orientations and tie/rank convention); changing that would require cohort-wide recalibration and
is not bundled into this containment change.

## Focused verification

Run from clean `C:/QM/worktrees/cto_main` before canonical deployment:

```text
python -m pytest framework/scripts/tests/test_q08_davey_subgates.py -q
63 passed

python -m pytest framework/scripts/tests/test_pbo_calculator.py tools/strategy_farm/tests/test_verdict_taxonomy_ws2.py -q
20 passed

python -m py_compile framework/scripts/q08_davey/aggregate.py framework/scripts/q08_davey/sub_8_7_pbo.py
PASS

git diff --check
PASS (line-ending notices only)
```

The same two test commands were repeated after deployment from canonical `C:/QM/repo` and returned
`63 passed` and `20 passed`; canonical `py_compile` also passed.

Read-only replay against the exact QM5_11708 scores produced:

```text
PBO=62.86%:max=40%:splits=35:overfit=22:source=Q08.5_neighborhood
classification EDGE_SOFT
static_replay FAIL_SOFT EDGE_SOFT
```

That replay substitutes the new Q08.7 result into the archived sub-gate set and uses a minimal
positive-PF trade fixture only to exercise aggregate classification. It is not a re-run, re-verdict,
or admission decision.

## Guardrail and deployment audit

- Code was committed first to local `main` through `C:/QM/worktrees/cto_main`, then the isolated
  commit was cherry-picked into the canonical runtime checkout `C:/QM/repo`.
- The canonical index and the three target files were clean before deployment; unrelated dirty board
  and FTMO work was neither staged nor modified.
- Existing Q08 Python processes were not stopped or restarted. Already-running processes retain their
  loaded modules; future aggregates load the deployed calibration.
- No terminal was started manually; no T1-T10 backtest was interrupted; `T_Live` and AutoTrading were
  untouched.
- No EA, setfile, news seed, risk setting, stale-news allowance, gate threshold, or pipeline row was
  changed by the implementation.
- Operator-facing phase names remain Q-only.
- No pipeline PASS/FAIL is inferred from unit tests or static replay.

Review disposition: review the source-aware severity contract and regression coverage. A fresh
pipeline run, if independently scheduled, remains the sole authority for any new Q08 verdict.
