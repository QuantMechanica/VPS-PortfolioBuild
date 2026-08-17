# C1 live readout — 5 of 5 bit-reproducible, and the QM5_13036 recompile effect is confirmed causal

First hard reading of the running (b) batch against
`docs/ops/evidence/2026-08-17_PREREG_book_q08_regeneration_91_pairs.md`.

The pre-registered C1 prediction: a C1 re-run executes **the same binary** that wrote the archived
stream, so it must reproduce that stream trade-for-trade. Falsifier: any divergence, which would
mean the tester is not reproducible and every stream comparison in 3.3/3.4 is weaker than assumed.

## Result — 5 of 5 exact, 0 divergences

| EA / symbol | verdict before → after | archived stream sha | new stream sha | rows | |
|---|---|---|---|---:|---|
| QM5_1537 / XAGUSD | PASS → PASS | `1885c21e4c895827` | `1885c21e4c895827` | 96 → 96 | match |
| **QM5_13036 / GDAXI** | PASS → PASS | `6336dde9f08bbbe2` | `6336dde9f08bbbe2` | 1,172 → 1,172 | match |
| QM5_10183 / XAUUSD | PASS → PASS | `023e8d73fe7b27a7` | `023e8d73fe7b27a7` | 338 → 338 | match |
| QM5_11660 / NDX | FAIL_SOFT → FAIL_SOFT | `a3f6200fb88377fc` | `a3f6200fb88377fc` | 1,410 → 1,410 | match |
| QM5_12354 / XAUUSD | PASS → PASS | `bf9a50ca870e3a69` | `bf9a50ca870e3a69` | 97 → 97 | match |

**Determinism holds end to end**: identical binary → identical stream → identical verdict, 5/5.
The verdict column matters independently — a matching stream that produced a different verdict
would have indicated a moved gate threshold rather than a moved measurement. None moved.

## The sharpest case confirms causality

**QM5_13036 / GDAXI is the pair whose recompile historically destroyed 180 trades** (1,352 → 1,172
between the 07-26 and 08-03 runs). Its binary has not changed since 2026-08-03, and this re-run
reproduced `6336dde9f08bbbe2` and 1,172 rows **exactly**.

That closes the attribution the 2026-07-28 bisect could not: the 180-trade loss was caused by the
**recompile**, not by tester noise. Same binary is bit-reproducible; different binary is not the
same measurement. It is the cleanest available demonstration that the vintage problem is real and
that regenerating the streams under a recorded binding was the right call.

## What this licenses

- **3.3's acceptance basis stands.** The fidelity ladder's claim — that an isolated re-run
  reproduces a joint run to half a cent — rests on tester reproducibility. That premise is now
  measured on five live pairs rather than assumed.
- **C2 and C3 proceed** as pre-registered. C2 rows began claiming while C1 was still finishing
  (QM5_10128, QM5_10403 active at time of writing).
- **The C3 flip count remains the open measurement**, to be read against the pre-registered bands
  (≤5 of 41 = gate noise; ≥15 = the pool needs revalidation before 3.2).

## Method note

The comparison reads `portfolio_stream.content_sha256` from each run's own aggregate rather than
re-hashing the stream file. The sleeve stream path is overwritten in place, so the file on disk is
already the new run's output — re-hashing it would have compared the new run against itself and
returned a match unconditionally.

## Evidence

- `work_items` rows carrying `book_q08_regeneration`, `requeue_source.verdict` for the prior verdict
- per-run `aggregate.json`, schema `q08_aggregate/v2`, stream identity `q08_portfolio_stream/v2`
- prior recompile evidence:
  `docs/ops/evidence/2026-08-17_C1_gate_passed_and_recompiles_change_streams_not_verdicts.md`
- execution record: `docs/ops/evidence/2026-08-17_option_b_executed_78_rows_enqueued_51_rebuilt.md`
