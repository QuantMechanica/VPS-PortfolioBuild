# C1 gate PASSED — the tester is reproducible; and recompiles change streams while leaving verdicts intact

The pre-registration
(`docs/ops/evidence/2026-08-17_PREREG_book_q08_regeneration_91_pairs.md`) put a stop rule ahead of
the 91-pair regeneration: **C1 runs first and alone; any divergence halts C2 and C3.**

The gate was answerable without running anything. Every Q08 aggregate records
`portfolio_stream.content_sha256` and `content_row_count`, so wherever a pool pair has two Q08 runs
the recorded hashes are a comparison already on disk.

## Result

| | run pairs |
|---|---:|
| binary **provably unchanged** across both runs → identical stream | **4** |
| binary provably unchanged → **different** stream | **0** ← the falsifier |
| binary changed between runs → stream unchanged | 1 |
| binary changed between runs → **stream changed** | **2** |

**C1 PASSES: 4 of 4, zero divergences. The tester is reproducible, and C2/C3 may proceed.**

"Binary provably unchanged" means the `.ex5` mtime — the time of the last compile — precedes the
*first* of the two runs, so no compile occurred at any point across the pair. This is the only
binary-identity signal available, because Q08 aggregates carry no `ex5_sha256`; Q04 is the sole
phase that seals one.

## The vintage question, answered as a byproduct

Three pool pairs had a recompile between two Q08 runs. That is not a determinism test — it is the
measurement that has been open since 2026-07-27:

| pair | binary compiled | run 1 | run 2 | stream |
|---|---|---|---|---|
| QM5_10939 / XAUUSD | 2026-08-05 19:10 | 07-26 INFRA_FAIL, 89 rows | 07-31 FAIL_SOFT, 89 rows | **unchanged** (identical hash) |
| QM5_13036 / GDAXI | 2026-08-03 00:29 | 07-26 **PASS**, 1,352 rows | 08-03 **PASS**, 1,172 rows | **changed — 180 trades fewer** |
| QM5_13301 / GDAXI | 2026-08-03 11:48 | 07-26 **PASS**, 551 rows | 08-03 **PASS**, 551 rows | **changed — same count, different content** |

**Two of three recompiles changed the trade stream.** QM5_13301 is the sharper case: the trade
count is identical and the content is not, which is the shifted-exit signature the 2026-07-28
bisect saw 72 instances of on QM5_9936. So a recompile is **not** behaviour-neutral, confirmed on
pool members rather than on a single instrumentation EA.

n = 3 is small and the finding is reported as directional, not as a rate.

## The distinction that matters, and it is good news twice over

**Both pairs whose streams changed stayed PASS.** Behaviour moved; the gate verdict did not.

- **For admission**, that is reassuring. The exposure named in the pre-registration — that
  rebuilding 51 EAs makes their Q02–Q07 verdicts binary-stale — is real but looks smaller than
  feared: the gates absorbed a stream change of 180 trades without flipping.
- **For the book, it is exactly the problem (b) exists to fix.** The streams *are* the book input.
  A 180-trade difference is not gate noise when it feeds a daily equity path, a drawdown percentile
  and a P(pass) curve. Numbers computed from archived streams would not be the numbers this tree
  produces.

That is the case for (b) stated in measurement rather than in principle, and it vindicates widening
it to 91: schema completeness was never the only reason to regenerate.

## Correction to my own first pass

The first version of this gate reported **2 determinism falsifiers** — QM5_13036 and QM5_13301. It
was wrong, and its own control could not fire: I tried to detect a binary change via the aggregate's
`ex5_sha256`, which Q08 aggregates do not carry. The field was `None` on both sides of every
comparison, so `a["ex5"] and b["ex5"]` was falsy and **every** pair fell through to the
same-binary branch. "binary differed: 0" was vacuous, not measured.

Both flagged pairs sit in the 07-26 → 08-03 window, straddling the rich-emitter commit of 07-30 —
they were recompile effects, and are now classified as such. A vacuous check that reports zero is
the same failure shape as a key-format mismatch reporting zero: it looks like evidence of absence.

## What proceeds now

C1's stop rule is discharged. C2 (26 pairs, re-run only) and C3 (53 pairs, rebuild then re-run)
proceed as pre-registered, with the C3 flip count still to be measured against the pre-registered
bands (≤5 of 53 = gate noise; ≥15 = pool revalidation before 3.2).

Given this result, the expectation for C3 is now sharper: streams will change for many of the 53,
and verdicts are expected to mostly hold.

## Evidence

- gate computed from `portfolio_stream.content_sha256` in Q08 `aggregate.json`, schema
  `q08_aggregate/v2`, stream identity `q08_portfolio_stream/v2`
- cohorts: `artifacts/book_q08_regeneration_cohorts_20260817.json`
- binary timing: `.ex5` mtime per registry-resolved EA directory
- prior art: `docs/ops/evidence/2026-07-28_vintage_bisect.md` (72 shifted exits, boundary not established)
