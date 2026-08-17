# Correction: "1,562 pairs, 1,584 of them Q04" mixed three different units

I published a subset larger than its superset. Both numbers were real; neither meant what I
said it meant.

## What the two numbers actually are

| Number | Tool | Unit | Scope |
|---:|---|---|---|
| **1,562** | `requeue_stranded_infra.py` wave planner | **groups**, after the planner's own refusals | Q04–Q07 only (its `--phases` default) |
| **1,584** | `--health-census` | **groups** whose *latest* verdict is INFRA_FAIL, **before** disposition | **Q04 alone** |

So 1,584 is a Q04-only, pre-disposition group count and 1,562 is a Q04–Q07, post-refusal group
count. They are not subset and superset — they are different measurements that happen to be
adjacent in size. And **neither is a pair count**, which is what I called them.

## The full picture, per phase

| Phase | infra groups | latest-INFRA_FAIL groups | distinct pairs | disposition RETRY | BLOCKED |
|---|---:|---:|---:|---:|---:|
| Q03 | 1,176 | 0 | 0 | 1 | 14 |
| **Q04** | 1,840 | **1,584** | **1,386** | **1,488** | 266 |
| Q05 | 165 | 49 | 37 | 49 | 92 |
| Q06 | 23 | 9 | 9 | 9 | 3 |
| Q07 | 58 | 41 | 39 | 39 | 13 |
| Q08 | 50 | 8 | 8 | 1 | 12 |
| **total** | | **1,691** | **1,479** | **1,587** | 400 |

Consistency checks that now hold:

- planner eligible: 1,465 (Q04) + 49 + 9 + 39 = **1,562** ✓
- census RETRY: 1 + 1,488 + 49 + 9 + 9·0 + 39 + 1 = **1,587** ✓
- the Q04 gap **1,488 census RETRY vs 1,465 planner eligible = 23 rows** is the planner's own
  additional refusals on top of the census disposition. Not an error in either; two gates.

## The unit distinction is not pedantry

A **group** is `(ea_id, symbol, phase, setfile)`. A **pair** is `(ea_id, symbol)`. One pair can
carry several groups — `QM5_10005`/EURUSD appears with its ordinary backtest setfile *and* with
`_ablation_03` and `_ablation_04` setfiles, three groups for one pair.

That matters for two different questions:

- **How much terminal time does recovery cost?** → group count. Every group is a run.
- **How many strategies does recovery return to the funnel?** → pair count. 1,479, not 1,691.

I used the smaller-sounding word ("pairs") with the larger number (groups), which overstates
strategy coverage by about 14% and understates nothing — the honest headline is:

> **1,562 requeue-eligible groups across Q04–Q07, spanning roughly 1,471 distinct (EA, symbol)
> pairs, of which 1,465 groups / 1,386 pairs are Q04.**

## Statements that need reading with this correction

- `2026-08-17_stranded_infra_recovery_wave1.md`: "1,562 deep-phase pairs" → **groups**.
- `2026-08-17_bars_zero_is_oninit_rejection_misclassified_as_infra.md` and
  `2026-08-17_poison_pill_quarantine_identifies_186_parks_none.md`: both reference "the 1,562
  recoverable pairs" → **groups**.
- Router tasks `d8fb0b43`, `c6e7158f`, `1a44e6a0` carry the same wording in their payloads.

The *arguments* in those documents are unaffected — they concern whether the population is
correctly classified, which does not depend on the unit. Only the coverage claim changes.

## And the number that still stands

None of this touches the finding that matters most: the population is **not yet known to be
correctly classified**. Today proved one family (`QM5_410xx`) was deterministic rejection
recorded as infrastructure, and 186 triples meet the poison-pill criterion while nothing is
parked. Whether the 1,562 groups are recoverable at all is the open question, and the Wave-1
criterion (`2026-08-17_wave1_preregistered_abort_criterion.md`) is what answers it. Getting the
unit right does not make the census trustworthy — it only stops one wrong number propagating.

## Evidence

- `requeue_stranded_infra.py --health-census` output, captured at
  `C:\Users\…\scratchpad\health_census.json` (`per_phase`, `disposition_totals`)
- `requeue_stranded_infra.py --wave 1` planner table (per-phase `stranded / eligible / refused`)
- `artifacts/lost_pairs_census_20260817.json`
