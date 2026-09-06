# EA_ML_FORBIDDEN predicate re-scoping — corpus sweep (ticket 690fc42a)

**Date:** 2026-09-06 · **Status:** DRY-RUN proposal (patched in an isolated worktree, nothing committed, nothing applied to `C:\QM\repo` `main`, no compile re-run)
**Trigger:** compile row `37e3b310` (QM5_41193 `xtixng-fracd-rv`) compiled PASS but `build_check` FAILED with `EA_ML_FORBIDDEN`.

## Root cause

`framework/scripts/build_check.ps1` (pre-change, line 888) used a single flat regex:

```
(?i)\b(tensorflow|torch|pytorch|sklearn|keras|onnx|xgboost|lightgbm|catboost|mlpack|dlib)\b|\.onnx\b|\.pb\b|\.pt\b|\.pth\b|\bweights\s*\[
```

The last alternative, `\bweights\s*\[`, is an **identifier-name** match. It fails any EA that
names an array `weights`, regardless of what the code does with it. QM5_41193 lines 746/840/844/845
hold the closed-form fractional-differencing recurrence

```
frac coefficients:  w[0] = 1;  w[lag] = w[lag-1] * (lag - 1 - d) / lag,  lag < strategy_frac_lags
```

— a deterministic binomial expansion over a fixed lag count. No training data, no error term,
no learning rate, no parameter carried across bars, no library. It is arithmetic, not ML.
The Hard Rule (`01 Identity/Hard Rules`) forbids **ML libraries / learning** in V5 EAs; a
coefficient array is not within its scope. The predicate was over-broad, not the EA non-compliant.

The scan also ran over raw file text, so ML words in **comments and string literals** counted
as evidence.

## Proposed predicate (implemented in the worktree, not committed)

`framework/scripts/build_check.ps1`, between the `# QM-MARK: BEGIN/END ML_PREDICATE_PATTERNS`
and `ML_PREDICATE_SCAN` sentinels. Detection now targets the three shapes that actually
constitute ML, on **comment-blanked** text (and additionally **string-blanked** for the code
shapes; blanking substitutes spaces so reported line numbers stay exact):

| # | Shape | Pattern name | Scope |
|---|---|---|---|
| 1 | ML library / model artifact pulled in via the preprocessor (`#include`/`#import`/`#resource`) | `$mlIncludePattern` | comments blanked |
| 1b | Serialized model artifact named in a string literal (`.onnx .tflite .h5 .pb .pt .pth .pkl .joblib .caffemodel`) | `$mlModelArtifactPattern` | comments blanked |
| 2 | Model inference / training API call — MQL5's native `Onnx*(...)`, plus `TrainModel/TrainNetwork/FitModel/BackProp/GradientDescent/UpdateWeights/LearnOnline/Perceptron/NeuralNetwork/QLearning/SGDUpdate/AdamUpdate` | `$mlApiPattern` | code only |
| 3a | An explicit **learning rate** anywhere in code (`learning_rate`, `learn_rate`, `lrate`) | `$mlLearningRatePattern` | code only |
| 3b | A **stored parameter updated from a learning signal**: an indexed element or struct member assigned/accumulated from a gradient, backprop term, RL reward, or an explicitly named training/prediction error | `$mlOnlineUpdatePattern` | code only |

Deliberate exclusions in 3b, calibrated against the corpus (see sweep below): a bare `loss`
or `error` is **not** a learning signal. The QM5_411xx family contains deterministic robust
estimators (LAD / Theil–Sen grid searches) that minimise an in-sample `loss` over a fixed
candidate set, and every EA reads `GetLastError()`. Neither is learning.

## Sweep — old vs new predicate over the whole EA corpus

Scan set: **3995** `framework/EAs/*/*.mq5` sources (one per EA directory), plus
`framework/include`, `framework/templates`, `framework/tests` (`.mq5`/`.mqh`).

| | EAs flagged |
|---|---:|
| Before (shipped predicate) | **2** |
| After (proposed predicate) | **0** |
| Cleared (flagged → clean) | **2** |
| Newly flagged (clean → flagged) | **0** |
| Still flagged | **0** |

### EAs whose verdict changes

| EA label | Before | After | Old-predicate hits | Assessment |
|---|---|---|---|---|
| `QM5_41193_xtixng-fracd-rv` | `EA_ML_FORBIDDEN` | clean | `weights[` ×8 (L746, 840, 844, 845, 847, 852, 853, 867) | Closed-form fractional-differencing coefficients. Deterministic recurrence, no data/error/state. False positive. |
| `QM5_2079_williams-ultimate-oscillator-h4` | `EA_ML_FORBIDDEN` | clean | `weights[` ×3 (L109, 135, 136) | Fixed Ultimate-Oscillator period weights (constant blend of the 7/14/28 averages). False positive. |

No EA gains a new `EA_ML_FORBIDDEN` finding, so the change cannot regress an EA that is
currently in the inventory. `framework/include`, `framework/templates` and `framework/tests`
contain **zero** matches for any ML library / learning token under either predicate.

### Calibration iteration (recorded, because it changed the pattern)

The first draft of 3b included a bare `\bloss\b` in the learning-signal alternation. That
produced **5 new false positives** — `QM5_41159_wti-lad-tr`, `QM5_41160_xauxag-mlad-rv`,
`QM5_41165_wti-mrobust3-agree-tr`, `QM5_41166_xauxag-mrobust3-agree-rv`,
`QM5_41189_xtixng-mlad-rv` — all on the line `candidate_losses[candidate] = loss;` inside a
least-absolute-deviation grid search (e.g. `QM5_41159_wti-lad-tr.mq5:647-662`: a fixed candidate
slope set, absolute residuals summed, minimum taken; no parameter survives the bar). `loss` was
removed from the alternation and replaced with `loss_grad*` / `training_loss`, after which the
sweep is clean.

## Tests

New: `tools/strategy_farm/tests/test_ml_predicate_scope.py` (11 tests). The harness lifts the
**shipped** regexes and the **shipped** scan loop verbatim out of `build_check.ps1` between the
`QM-MARK` sentinels and runs them through PowerShell, so the fixtures cannot drift from the
production predicate.

Negatives (must NOT trip):
- the QM5_41193 fractional-differencing recurrence (`weights[lag] = weights[lag-1] * (lag-1-d)/lag`)
- deterministic constant weight/coefficient arrays, `GetLastError()`, `stop_loss`, and ML words
  appearing only in comments

Positives (MUST trip):
- online learning: `g_weights[i] += learning_rate * err * features[i]` each bar
- gradient update without the words "learning rate": `g_state.coeffs[i] -= 0.05 * gradient[i]`
- `#include <Math/Onnx/InferenceModel.mqh>` / `#resource ".../xgboost_booster.mqh"`
- `OnnxCreate` / `OnnxRun` / `OnnxRelease` call sites
- a serialized model artifact in a string literal (`"MQL5\Files\gbm_model.onnx"`)

Plus a line-number-fidelity test (comment blanking must not shift reported lines), a regression
guard that the bare `\bweights\s*\[` token cannot come back, and a PowerShell AST parse check on
the modified `build_check.ps1`.

### Command and result

```
python -m pytest tools/strategy_farm/tests/test_ml_predicate_scope.py \
                 tools/strategy_farm/tests/test_build_gate_hardening.py \
                 tools/strategy_farm/tests/test_compile_work_items.py -q
```

`1 failed, 114 passed in 129.71s`

- `test_ml_predicate_scope.py`: **11/11 passed**
- `test_build_gate_hardening.py`: 31 passed, **1 pre-existing failure**
  (`test_qm5_411xx_sources_have_no_unbounded_numeric_buffers`, `EA_INDICATOR_BUFFER_UNBOUNDED`).
  Unrelated to this change: it exercises `tools/strategy_farm/build_gate_hardening.py`
  (untouched here) against unmodified EA sources, and the same failure is recorded in
  `docs/ops/evidence/2026-09-05_buildcheck_predicate_fix/tests.txt` / `verification.json`
  from before this work. It belongs to the open buffer-bound family
  (`docs/ops/evidence/2026-09-05_buffer_bound_family.md`).
- `test_compile_work_items.py`: 72 passed.

## Alternative (b): source-side rename in QM5_41193 only

`docs/ops/evidence/2026-09-06_qm5_41193_frac_coeffs_rename_690fc42a.patch` renames
`weights[]` → `frac_coeffs[]` in `QM5_41193_xtixng-fracd-rv.mq5` and nothing else.

Identifier-only proof (all three assertions hold):
1. **Round trip is byte-exact** — re-substituting `frac_coeffs` → `weights` reproduces the
   original file byte-for-byte.
2. **Line count unchanged**; 9 lines differ, 9 whole-identifier occurrences replaced.
3. **Token stream identical** per changed line apart from the renamed identifier
   (`re.findall(r"\w+|\S", ...)` comparison).

Applied in the worktree, the file scores **0 hits under the OLD predicate**
(8 `frac_coeffs[` sites, 0 `weights[`), then reverted — the worktree source is unmodified.
`weight_count` is intentionally left alone (it is a counter, not the coefficient array, and
does not match the predicate).

## Recommendation: (a)

(b) fixes one file; (a) fixes the rule. The failure is not a property of QM5_41193 — it is a
property of a predicate that matches an identifier name instead of a behaviour, and the sweep
shows it has been silently mis-scoring at least one other EA (`QM5_2079`) on the same basis.
Renaming the array teaches the factory that the way past a Hard-Rule gate is to rename a
variable, which is exactly the wrong incentive: it leaves the gate able to fail the next
legitimate coefficient array (and, worse, unable to say why), while the evidence trail records
a "fix" that changed no behaviour. (a) restores what the Hard Rule actually forbids — library
intake, model inference, and parameter learning — tightens the scan by ignoring comments and
string literals, and the corpus sweep shows the change is strictly a false-positive removal:
2 EAs cleared, 0 newly flagged, so no EA in the inventory can regress behind it. (b) remains
available as a cosmetic follow-up if OWNER wants the array name to read as intent
(`frac_coeffs` is the more honest name), but it should not be the mechanism that unblocks the
compile row.

## Blast radius / rollback

- Touches one function (`Invoke-ForbiddenScan`) in `framework/scripts/build_check.ps1`. Nothing
  outside `EA_ML_FORBIDDEN` changes: the `BUILD_CHECK_EXTERNAL_DATA_API_FORBIDDEN` scan and every
  DWX advisory are byte-identical.
- Loosening a gate criterion touches the **ROT** zone (gate thresholds & contract criteria) —
  this is submitted as a proposal for OWNER, not executed.
- Rollback: revert the single hunk in `build_check.ps1`; the new test file is additive.
- `37e3b310` still needs a re-run of the compile row after the decision; no recompile was
  performed here.

## Files

- `framework/scripts/build_check.ps1` — patched in worktree (uncommitted), +64/−4
- `tools/strategy_farm/tests/test_ml_predicate_scope.py` — new, 11 tests
- `docs/ops/evidence/2026-09-06_ml_predicate_sweep_690fc42a.md` — this document
- `docs/ops/evidence/2026-09-06_qm5_41193_frac_coeffs_rename_690fc42a.patch` — alternative (b)
