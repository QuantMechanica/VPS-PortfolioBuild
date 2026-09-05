# DL-089 census prescreen B5/B2 — 2026-09-05

## Result

**FAIL-CLOSED / IMPLEMENTATION NOT ACTIVATED.** The requested B5/B2 production
patch cannot be made deterministic from the released authority as written.
No census verdict, measured cell, selection rule, or already-enqueued year was
rewritten. The environment kill switch is therefore unnecessary in this
revision: existing behavior remains unchanged.

This is not a code-complexity deferral. Two decision inputs required to avoid a
selection-affecting invention are absent or explicitly negative:

1. Decision B2 says “two screening years” and “the declared subset”, but neither
   `OWNER_VORLAGE_2026-09-04_census_shortening_amendment_c_bundle_rule.md` nor
   `PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md` identifies the two years. Choosing
   2019/2020, 2020/2021, or another pair changes which arms reach stage 2.
2. The only authorized counter, `pattern_fire_count.count_program`, still emits
   `safe_to_skip: false`. Its evidence explicitly says the delivered D1 cache is
   a native CopyRates diagnostic export without the previously requested native
   tick/tester parity. The task declares the D1 path, but does not amend this
   counter-side fail-closed result or its required provenance contract.

Activating B2 without item 1 would silently alter the population selected for
measurement. Activating B5 while ignoring item 2 would turn a diagnostic into a
production skip authority despite its explicit refusal. Both would be evidence
overclaims.

## Current enqueue/consumer audit

The existing implementation is not a dormant B5/B2 path that only needs a
switch:

- `optimization_fork_driver._pattern_candidate_declaration` seals all 1,085
  annual cells (seven baselines + 154 arms per year).
- `opt_census.enqueue` writes all 1,085 setfiles and inserts all 1,085 pending
  rows in one transaction.
- `dl089_matrix_service._program_binding_guard` requires the complete sealed
  1,085-row set and rejects a partial program.
- `opt_census_select` recognizes only `SKIPPED_EXCLUDED`, using
  `opt_census_pruning.SKIPPED_VERDICT` and its
  `qm.dl089-skipped-as-excluded/v1` receipt.
- `dl089_scheduling.arm_frontier`, `farmctl` terminal-verdict handling,
  `work_item_clean_view`, and `work_item_lifecycle_v2` likewise enumerate
  `SKIPPED_EXCLUDED`; they do not currently treat `SKIPPED_PRESCREEN` as an
  equivalent resolved/no-metric disposition.

A safe implementation therefore needs a versioned staged-program state machine,
not an insertion-time `if` alone: enqueue stage-1 baselines, derive and bind the
per-year count receipt, append either a pending arm or a terminal prescreen
receipt, wait for both declared screening years, apply the same-year
`return_to_maxdd >= baseline * 1.05` rule, then append stage-2 rows. Every
consumer above must accept the new terminal disposition while the declared
trial count remains 154. Existing rows must be left untouched.

## Requested live dry run

Fresh diagnostic outputs were produced read-only from the running programs’
completed baseline reports and the declared T_Export D1 files:

- `D:/QM/reports/portfolio/census_prescreen_b5_b2_20260905/41196_XAUUSD_counts.json`
- `D:/QM/reports/portfolio/census_prescreen_b5_b2_20260905/41196_XAUUSD_counts.csv`
- `D:/QM/reports/portfolio/census_prescreen_b5_b2_20260905/41197_GBPUSD_counts.json`
- `D:/QM/reports/portfolio/census_prescreen_b5_b2_20260905/41197_GBPUSD_counts.csv`

The calculation below applies B5’s requested **per-year** threshold `N=5` to
the 154 direction-specific arms. “Measured cells” includes the annual baseline.

| Measurement EA / subject | Year | Arms `<5` | Skip share | Projected measured cells | Cell saving |
|---|---:|---:|---:|---:|---:|
| 41196 / 21507 XAUUSD | 2019 | 111/154 | 72.08% | 44 | 111 |
| 41196 / 21507 XAUUSD | 2020 | 113/154 | 73.38% | 42 | 113 |
| 41196 / 21507 XAUUSD | 2021 | 110/154 | 71.43% | 45 | 110 |
| 41196 / 21507 XAUUSD | 2022 | 111/154 | 72.08% | 44 | 111 |
| 41196 / 21507 XAUUSD | 2023 | 114/154 | 74.03% | 41 | 114 |
| 41196 / 21507 XAUUSD | 2024 | 112/154 | 72.73% | 43 | 112 |
| 41196 / 21507 XAUUSD | 2025 | 117/154 | 75.97% | 38 | 117 |
| 41197 / 11881 GBPUSD | 2019 | 145/154 | 94.16% | 10 | 145 |
| 41197 / 11881 GBPUSD | 2020 | 143/154 | 92.86% | 12 | 143 |

XAUUSD has all seven baseline years measured. GBPUSD has only 2019 and 2020
baseline cells measured; 2021–2025 remain pending, so no count is invented for
those years. Source D1 SHA-256 values are:

- XAUUSD: `105aa27a6d0aff0818b9b76b0eb081d917ea8fb90ec077b599a33ea65ab12f13`
- GBPUSD: `c354b33f801382b8cc508180238c1d4d04e1d743d5d76f1ce7f0634f3ce5b5ea`

These figures are projections only because both output documents truthfully
retain `safe_to_skip=false`.

## Running-program preservation check

The three Amendment C programs that became service-ready during this cycle
(12849/XTIUSD, 12855/XTIUSD, 21501/USDJPY) were materialized by the scheduled
matrix service with 1,085 pending rows each before any B5/B2 implementation.
The acceptance contract says years already enqueued in running programs are
untouched. This artifact honors that rule and does not delete, terminalize, or
rewrite those rows.

## Focused verification

```text
python -m pytest tools/strategy_farm/tests/test_pattern_fire_count.py \
  tools/strategy_farm/tests/test_opt_census.py \
  tools/strategy_farm/tests/test_opt_census_pruning.py \
  tools/strategy_farm/tests/test_opt_census_select.py \
  tools/strategy_farm/tests/test_dl089_matrix_service.py -q
619 passed in 35.01s
```

This confirms the current counter, enqueue, pruning, selection, and matrix
service contracts remain internally green after the read-only audit.

## Exact unblock needed

An OWNER/CEO correction should state both:

1. the exact two stage-1 calendar years; and
2. that the named T_Export D1 source/provenance is accepted as production skip
   authority, including whether `pattern_fire_count` may change
   `safe_to_skip` to true under a hash-bound native-export manifest.

With those two values, the implementation can pre-register the staged state
machine, `SKIPPED_PRESCREEN` receipt schema, consumer equivalence, synthetic
fixture, and `QM_DL089_PRESCREEN=0` rollback without inventing policy.
