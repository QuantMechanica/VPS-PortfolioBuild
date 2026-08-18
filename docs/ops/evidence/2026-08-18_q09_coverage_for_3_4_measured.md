# §0(ii) — Q09 coverage for 3.4, measured: 10.4% of planned cells, and the constraint is not fleet time

v7 §0(ii) calls this "der teuerste vermeidbare Fehler in der aktuellen Lage" and asks that the
coverage be checked now rather than at 3.4, because the work parallelises over the fleet and can run
beside batch (b). Checked. **The measurement changes the recommendation**: the binding constraint is
not fleet time, and starting the matrix wide today would spend the fleet without buying coverage.

## What 3.4 actually needs, from the contract

`q09_news_contract.py` defines the experiment as two logical arms:

- **`CONTROL_OFF`** — temporal OFF, compliance NONE. **This is 3.4's "without news filter" curve.**
- **`POLICY_ON`** — sweeps the seven temporal modes (`OFF, PRE30, PRE60, PRE30_POST30,
  PRE60_POST60, SKIP_DAY, CLOSE_ALL_PRE`) at the deployment target's compliance policy. **This is the
  "with news filter" curve.**

Every policy run is paired to a control run with the same seed and immutable base identity. So the
two curves are not an extra analysis on top of Q09 — they *are* the Q09 arms.

## Coverage, measured over every completed Q09_NEWS row

| | |
|---|---:|
| completed `Q09_NEWS` rows | 83 |
| rows whose evidence is missing or unreadable | 41 |
| **authenticated cells / planned cells** | **181 / 1,740 = 10.4 %** |
| distinct pairs touched | 18 |
| pairs with ≥1 authenticated cell | **7** |
| **pairs reaching `CONFIG_LOCKED`** | **1** (QM5_11422 / USDCAD) |

Verdict census over all `Q09_NEWS` rows: `REVIEW_REQUIRED` 39 · `INFRA_FAIL` 24 ·
`PENDING_RUNNER` 18 · pending 16 · `CONFIG_LOCKED` 1 · `INVALID_EVIDENCE` 1.

## `REVIEW_REQUIRED` does not mean "measured, awaiting adjudication"

This was the hypothesis worth testing, because if 39 pairs held complete evidence and only needed the
adjudicator wired, the cost would be an afternoon rather than fleet-weeks. It does not hold. Reading
the aggregate behind a representative `REVIEW_REQUIRED` row (QM5_1556 / XAUUSD):

```
matrix_scope              "7x1_target_compliance"   target_compliance "DXZ"
planned_cell_count        40
authenticated_cell_count   0        <- not one cell
failed_cell_count          1
missing_cell_count        39
locked_arms               []        chosen_config  null
reason_codes              ["cell_execution_failed"]
```

The adjudicator is behaving correctly — its own docstring says it "never invents a default
configuration when evidence is missing", and here there is no evidence to adjudicate. **The
adjudicator is not the bottleneck; cell execution is.**

Reason-code census across all readable aggregates: `cell_execution_failed` 22 ·
`cell_receipt_invalid` 10 · `expanded_7x4_matrix_required` 7 · `partial_cell_execution` 1 ·
`off_fallback_no_robust_improvement` 1.

## The failing cell is the control arm, and it has failed six times

```
cell                  control_off__m0__c0__s42
error                 Q09 selection run_smoke exited with code 1 without a fresh
                      run_smoke summary or cell receipt
error_type            TransientCellError
failure_occurrence    6
failure_schema        q09-news-cell-failure/v2
```

Two things matter here.

**It is `control_off`.** Not an exotic corner of the 7×4 matrix — the baseline arm. Without
`CONTROL_OFF` there is no "without news filter" series at all, so this single failing cell removes
*one of 3.4's two curves* for the pair, regardless of how many policy cells succeed.

**It is labelled `TransientCellError` at occurrence six.** A transient that recurs six times is not
transient. This is the same shape as v7's rule *a repetition limit sits at the level of the cause*:
the retry classification is doing the work that a diagnosis should be doing.

## No scheduled operator — fourth instance of the class

Checked every `QM_*` scheduled task action string: **none invokes any Q09 runner.** After the
poison-pill quarantine, `bind-q09-plan`, and `requeue_stranded_infra`, this is the fourth mechanism
whose operator is a hand-run command. It is exactly what v7 1.17 (Lebenszeichen je Wartungsjob) is
designed to catch, and it is the argument for building 1.17 rather than repairing a fourth
individual case.

## Recommendation — against the premise of §0(ii), with the measurement behind it

§0(ii) reasons that the work parallelises, so it should start now beside (b). The parallelism is
real. The problem is the yield.

At the observed authentication rate, covering the 91-pair pool would plan on the order of
**91 × 40 ≈ 3,640 cells** and, at 10.4 %, authenticate roughly **380**. That spends the fleet
alongside (b) — the one thing on the critical path — and buys a coverage number that still cannot
feed 3.4.

So the order should be inverted relative to §0(ii):

1. **Fix cell execution first.** One named defect: `run_smoke` exits 1 without writing a summary or
   receipt, six times on the same control cell. This is a bounded debugging task, not a fleet task,
   and it costs no factory time.
2. **Then re-run one pair end to end** as a positive control — a pair must reach `CONFIG_LOCKED`
   with both arms authenticated, as QM5_11422/USDCAD already does, proving the path works before it
   is widened.
3. **Then widen** — and widen over the sleeves 3.2 selects, not over all 91. v7 itself notes the
   pair count is an output of 3.2; running the matrix over 91 pairs pre-empts a decision 3.2 has not
   made yet.

**What this does not change:** §0(ii)'s core point stands and is now quantified. Coverage is 1 pair,
3.4 cannot compute two curves from that, and discovering it at 3.4 would have converted parallel
work into serial delay. The check was worth doing now; its answer is that the first move is a
debugging task rather than a fleet run.

## Evidence

- `tools/strategy_farm/q09_news_contract.py:1-45` — the two arms, seven temporal modes, 7×4 matrix
- `work_items` where `phase='Q09_NEWS'` — 83 completed rows, verdict census above
- per-row `aggregate.json`, schema `q09-news-adjudication/v2`; `details.authenticated_cell_count`
  and `details.planned_cell_count` summed across all readable aggregates
- failing cell record, schema `q09-news-cell-failure/v2`, sha256 `56eb4a0a029b9b62…`
- scheduled-task scan over all `QM_*` actions, 2026-08-18
