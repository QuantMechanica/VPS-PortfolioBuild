# C2's first result — and an error in my own pre-registration, caught by it

The pre-registration
(`docs/ops/evidence/2026-08-17_PREREG_book_q08_regeneration_91_pairs.md`) stated the C2 prediction
as:

> **C2 — same binary, richer record.** *Predicted:* the re-run emits the rich schema **and** the
> trade content matches the archived stream, because the binary is unchanged.

**The rationale is wrong, by my own cohort definition.** C2 is exactly the set whose archived stream
is *not* rich — which means it was emitted by a binary predating the rich emitter (`85db6178c`,
2026-07-30 01:18) — while the `.ex5` on disk is post-cutoff. So for C2 the binary **did** change
between the archived run and now. "Unchanged binary" is C1's defining property, not C2's; C1 is
additionally gated on `ex5_mtime < stream_mtime`, and C2 is not.

The cohort membership was correct throughout. The error is in the sentence explaining why, and in
the falsifier I hung on it.

## The first C2 result

| pair | archived trades | new trades | archived sha | new sha |
|---|---:|---:|---|---|
| QM5_13013 / NDX | **68** | **70** | not recorded | `679ce2cd7db33a5d` |

Two more trades from the same source under a newer binary. Under the corrected reading this is not
a falsifier — it is a **second, independent measurement of the recompile effect**, on a pair where
the recompile happened between the archived run and this one.

The evidence now reads consistently across all three cohorts:

- **same binary → identical stream** — C1, 7 of 7 exact, including the two pairs whose historical
  recompiles changed their streams
- **different binary → changed stream** — QM5_13036 (1,352 → 1,172), QM5_13301 (551 rows, different
  content), and now QM5_13013 (68 → 70)

## Corrected C2 prediction and falsifier

*Predicted:* the re-run emits the rich schema; trade content **may** differ, because the binary is
newer than the one that wrote the archived stream. *Falsifier:* the rich schema fails to appear —
that would mean the binary on disk does not carry the emitter its compile date implies, and the
cohort split by `.ex5` mtime is unsound.

Note this is a **weaker** test than C1's, and it should be labelled as such rather than quietly
reinterpreted. C1 carried the determinism claim; C2 carries only the schema claim.

## A related gap the result exposed

The archived side of the QM5_13013 comparison is `None` because its previous Q08 aggregate records
no `portfolio_stream` block at all. Measured across the frozen cohorts:

| cohort | archived stream hash recorded | not recorded |
|---|---:|---:|
| C1 | 12 | 0 |
| C2 | 9 | 17 |
| C3 | 12 | 41 |

So for **58 of 91 pairs the archived stream hash was never recorded**, and the stream file itself is
overwritten in place by the re-run. Without the frozen cohort artifact, those comparisons would have
been lost entirely — the archived trade count survives only because
`artifacts/book_q08_regeneration_cohorts_20260817.json` captured it before the first run.

That is the freeze earning its keep, and it is also a standing argument for recording
`portfolio_stream.content_sha256` in every phase aggregate, not just the ones that happen to carry
it today.

## What does not change

C1's determinism result stands untouched — it was measured on pairs where the binary was provably
unchanged, and that gating was correct. The C3 flip count remains the open measurement against its
pre-registered bands (≤5 of 41 = gate noise; ≥15 = the pool needs revalidation before 3.2).

## Evidence

- cohorts: `artifacts/book_q08_regeneration_cohorts_20260817.json` (frozen before the first run)
- C1 readout: `docs/ops/evidence/2026-08-18_C1_live_readout_5of5_bit_reproducible.md`
- emitter cutoff: `framework/include/QM/QM_Common.mqh:1717`, commit `85db6178c`
