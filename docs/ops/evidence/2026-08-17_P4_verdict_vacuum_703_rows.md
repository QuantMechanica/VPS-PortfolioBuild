# P4 — The verdict vacuum: 703 rows, and 329 of them are canonical work nobody is waiting for

## Definition, so the number is checkable

A **vacuum** row is one where the latest terminal row for an `(ea_id, symbol, phase)` triple
carries a **voiding** verdict — one that *withdraws* a result rather than deciding merit — and no
pending or active row exists for that `(ea_id, symbol)`.

Retirements are deliberately **excluded**: `RETIRE` (125) and `RETIRED_LOW_FREQ` (59) are answers,
not vacuums. Counting them would inflate the figure with decisions that were correctly taken.

## The count

Over 24,355 triples with a terminal row: **703 vacuum rows, 693 distinct pairs, 209 distinct EAs.**

| Verdict | rows |
|---|---:|
| INVALID | 536 |
| PENDING_RUNNER | 41 |
| SUPERSEDED_BY_LOGICAL_BASKET | 41 |
| DRAFT_DEFECT | 37 |
| SUPERSEDED | 23 |
| OBSOLETE_NON_DWX_SYMBOL | 18 |
| INVALID_BUILD_STATIC_FIDELITY | 5 |
| BLOCKED_STALE_BUILD_RESULT · CONFIG_LOCKED | 2 |

By reason token:

| Reason | rows | reading |
|---|---:|---|
| **`setfile_missing`** | **337** | the interesting block — see below |
| `poison_pill` | 182 | **my own sealing this morning** |
| `<none>` | 62 | no reason recorded |
| `phase runner not implemented yet` | 41 | not a vacuum in substance — the phase has no executor |
| `Q02_ALL_ENQUEUED_SYMBOLS_ZERO_TRADES` | 32 | a genuine no-signal answer |
| `Q02_HOST_OUTSIDE_APPROVED_CARD_AND_MAGIC_REGISTRY` | 22 | correctly refused |
| remainder | 27 | mixed |

## The 182 poison-pill rows are mine, and they are not a defect

The quarantine **is** the decision: a successor row would be blocked by it on the
`(ea_id, symbol, phase)` triple immediately. They only become a true vacuum if a seal is later
released without enqueueing a replacement. Recorded explicitly because it is my own action from
this morning and therefore the case I would be least likely to notice unprompted.

## The 337 `setfile_missing` rows are the finding

These were invalidated because their setfile was absent, and then nothing replaced them.
Checked against disk **now**, not against the state at the time:

| | rows |
|---|---:|
| setfile **still** missing | **329** |
| EA directory itself gone | 6 |
| setfile exists again today | 2 |

So they are not trivially re-runnable — the file genuinely is not there. But the EA source
directory survives for 329 of them, which makes this a **generation** task rather than a loss.

And the distinction that decides whether it is worth anything:

> **All 329 are canonical `_backtest.set` files.** Only 8 of the wider `setfile_missing` set are
> `_ablation_` exploration variants. These are not abandoned side-experiments — they are
> **329 (EA, symbol) pairs whose primary Q02 configuration was never produced**, so the pair has
> never been fairly evaluated at all.

For scale: the current Q02 pending queue is 660 rows. This is a further **329 pairs of genuinely
untested raw material**, recoverable by regenerating a setfile — and the generator was fixed
today, so regeneration now emits correct decimal expansion rather than reintroducing the exponent
defect.

## Why I am not launching it

This is *available* raw material, not work I am starting. P7 asks precisely whether it is right to
push more candidates through Q02 while the exit is blocked, and adding 329 pairs to a 660-row Q02
queue at 10.7 completions/hour would extend the single-pass drain by roughly 30 hours. That is a
queue-policy decision, and the honest thing is to present the number to it rather than pre-empt it.

The 32 `Q02_ALL_ENQUEUED_SYMBOLS_ZERO_TRADES` rows are also deliberately left alone: every
enqueued symbol produced zero trades, which is a strategy answer. Requeueing them needs a
hypothesis about why, not a requeue. The same restraint applies to QM5_20177, whose one post-fix
run returned ZERO_TRADES — that smells like over-rejection, but a smell is not a finding.

## Recommendation: carry it as a standing metric

The reason this went unnoticed is structural: a voided pair without a successor appears in no
count. It is not a success, not a failure, not a backlog. **703** is not a large number, but it was
invisible, and `setfile_missing` accumulating to 337 is exactly the kind of drift that only shows
up when someone asks a question nobody had asked.

`artifacts/verdict_vacuum_census_20260817.json` is re-runnable and reports the same figure with
the same definition, so the metric can be tracked rather than rediscovered.

## Evidence

- `artifacts/verdict_vacuum_census_20260817.json` — definition, counts, all 703 entries
- 24,355 triples from `work_items`, latest terminal row per triple
- disk check of every `setfile_missing` row's recorded `setfile_path`
- related: `2026-08-17_poison_pill_quarantine_identifies_186_parks_none.md`
