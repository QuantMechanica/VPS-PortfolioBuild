# P1.4 — The fan-out halves the catch-up to 10.3 hours, and 99 of the 214 were my own over-broad predicate

## The result

The catch-up list reported **214 gate actions / 20.0 hours** as one undifferentiated number. Fanned
out by what each action actually needs:

| Action | Gate actions | Factory cost |
|---|---:|---|
| **RUN** — verdict missing, or its evidence is gone | **110** | **10.3 h** at the measured 10.7 completions/h |
| **RE_DERIVE** — arithmetic on stored evidence | **5** | zero |
| **NO_ACTION_FROM_CONTRACT** | **99** | zero |
| total | 214 | |

**10.3 hours instead of 20.0 — a 9.7-hour saving**, and it cost minutes to establish, exactly as the
brief predicted.

## The 99 are my own error, and it is the same error twice

My BUILD-0 catch-up list classified a pair as `RERUN_PRE_CONTRACT` if *any* phase verdict predated
2026-07-29, and then listed **every** phase of that pair as needing work.

But `b62cf0638` added exactly one thing: **the Q10 requirement for a `PASS_PORTFOLIO` dependency.**
It did not change Q04, Q05, Q06, Q07, Q08 or the portfolio arm itself. So a Q04 verdict dated
2026-07-20 was never invalidated by that contract — it is merely *older than a date*.

> **Date alone is not staleness.** That is precisely the conclusion BUILD-0 reached about provenance
> dating — a predicate that condemns everything carries no information — and I then reproduced the
> error inside my own catch-up list, one section later.

99 of the 214 actions were that. They are removed, not deferred.

## The 5 genuine re-derivations

Pre-contract Q10 verdicts that already have a `PASS_PORTFOLIO` arm with retrievable evidence, so the
today-contract can be satisfied by arithmetic rather than a run:

```
QM5_10440  NDX.DWX       PASS_PORTFOLIO   Q10
QM5_10692  NDX.DWX       PASS_PORTFOLIO   Q10
QM5_11422  USDCAD.DWX    PASS_PORTFOLIO   Q10
QM5_12969  USDJPY.DWX    PASS_PORTFOLIO   Q10
QM5_1567   EURUSD.DWX    PASS_PORTFOLIO   Q10
```

Note the discipline in the rule: a pre-contract Q10 whose portfolio arm is `FAIL_PORTFOLIO`,
`NEED_MORE_DATA` or absent is **not** re-derivable — it goes to RUN, because the dependency it now
needs does not exist and cannot be manufactured. That distinction is what keeps the 5 honest.

## What the 110 RUN actions are, and why they cannot shrink further

Two irreducible causes:

- **Evidence gone** — there is nothing to compare against, so no amount of arithmetic substitutes
  for a run. This is the larger share.
- **Gate never ran** — QM5_12778/AUDUSD is the heaviest single pair at **7 runs**, because it holds a
  Q10 PASS with the entire Q04→Q09_PORTFOLIO chain absent.

Neither shrinks with a better predicate. 10.3 hours is the floor for a delivery chain whose every
link is current.

## Where this leaves the queue decision

Still a decision, but a smaller one: **10.3 hours against a 784-row queue at ~73 hours per pass —
14 % of one pass, not 27 %.** And the reproduction evidence gathered today (three exponent pairs,
metrics byte-identical across a 5-day gap) is a first data point suggesting reproduction is high,
which would argue the *evidence-gone* runs mostly confirm rather than overturn.

That does not remove the need for them — an unverifiable verdict is unusable regardless of how
likely it is to be right — but it does mean the expected *information* per hour is low and the
expected *legitimacy* per hour is high. Those are different goods, and the queue decision is really
a choice between them.

## Evidence

- `artifacts/build0_catchup_fanout_20260817.json` — per-pair, per-phase action with the rule and my
  self-correction recorded in the artifact itself
- `artifacts/build0_catchup_list_20260817.json` — the 214-action list this corrects
- `b62cf0638` (2026-07-29) — the contract change, scoped to the Q10 dependency
- related: `2026-08-17_BUILD0_verdict_currency.md`,
  `2026-08-17_P0_lifted_ea_metrics_is_append_only_and_the_tolerance_was_inert.md`
