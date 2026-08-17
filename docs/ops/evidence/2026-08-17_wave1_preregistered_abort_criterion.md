# Wave 1 — pre-registered outcome criterion (written 2026-08-17 10:55Z, before any result)

Wave 1 of the stranded-infra recovery is five Q07 canaries, requeued 2026-08-17 08:58:41.
The first one entered execution at **10:49:28** (`QM5_1116` / EURJPY.DWX on T2). **This
document is written while that run is in flight and before any of the five has a verdict**, so
the reading rule cannot be fitted to the answer.

| Canary | EA | Symbol | Prior failure |
|---|---|---|---|
| `e317cb4a` | QM5_1077 | XAUUSD.DWX | ACTIVE_TIMEOUT |
| `b37c01d6` | QM5_1116 | EURJPY.DWX | seeds_invalid_evidence (seed 42 evidence missing) |
| `c66474ef` | QM5_1206 | SP500.DWX | ACTIVE_TIMEOUT |
| `8146c6c7` | QM5_1226 | XTIUSD.DWX | seeds_invalid_evidence (seeds 42, 17 exit_code=1) |
| `6e1598dd` | QM5_12935 | XAUUSD.DWX | — |

## The question Wave 1 answers

Not "do these five pass". Whether they pass on merit is irrelevant to the wave decision — a
`FAIL` is a perfectly good outcome. The question is narrower:

> **Was the original `INFRA_FAIL` a transient, such that a plain requeue is the right lever?**

Everything downstream — whether Wave 2's 25 rows and eventually the remaining ~1,557 pairs are
requeued at all — turns on that and nothing else.

## Three outcomes, decided in advance

**Outcome A — transient confirmed.** A canary reaches a **merit verdict** (`PASS`, `FAIL`,
`PASS_SOFT`, `FAIL_SOFT`, `ZERO_TRADES` counts as merit here: the run executed and the
strategy's behaviour was measured).
→ *Reading:* the requeue path works and the original failure was environmental.
→ *Action:* counts toward Wave 2 eligibility.

**Outcome B — genuine infra reproduced.** A canary returns `INFRA_FAIL` whose evidence shows a
**real runtime or data failure**: `NO_HISTORY`, `METATESTER_HUNG`, `INCOMPLETE_RUNS` without an
OnInit marker, a timeout at the granted budget, a missing report after a started run.
→ *Reading:* the requeue path works, the *infrastructure* cause persists.
→ *Action:* **Wave 2 stays frozen.** Diagnose the reproduced cause first. Requeueing 25 more
rows into a live infra fault multiplies the fault, it does not measure it.

**Outcome C — deterministic rejection reproduced.** A canary returns `INFRA_FAIL` whose
evidence shows the run **never started**: `ONINIT_FAILED`, `BARS_ZERO` with an OnInit phrase in
`tester_log_decisive_lines`, `INIT_PARAMETERS_INCORRECT`, or `attempted_runs = n/n` with no
error marker and a zero-bar report.
→ *Reading:* the row was **misclassified**. Requeue is the wrong lever — it will fail
identically forever, as proved today on the QM5_410xx family.
→ *Action:* **Wave 2 is not merely frozen, it is void as designed.** The 1,562-pair census must
be rebuilt by applying the *corrected* classifier to stored `tester_log_decisive_lines` rather
than trusting the stored verdict, and only the residue that is genuinely bucket-I may be
requeued.

## Decision rule over the five, fixed now

Judged on the five canaries as a set:

| Observed | Decision |
|---|---|
| **5 of 5 in A** | Wave 2 proceeds at its designed size of exactly 25, unchanged. |
| **4 of 5 in A**, one in B | Wave 2 proceeds, but capped at **10** rows, and the B case is diagnosed first. A single reproduction is not noise at n=5. |
| **any C** | Wave 2 **void as designed**, regardless of how many A's accompany it. One deterministic reproduction proves the census mixes classes, and the classification must be fixed before quantity. This overrides every other row of this table. |
| **≥2 in B** | Wave 2 frozen until the reproduced infra cause is named and fixed. |
| **≥1 still unfinished after 48h** | Not an outcome. Report as "wave inconclusive, still running" — do **not** infer transience from absence of failure. |

**A single C outweighs four A's.** That asymmetry is deliberate: an A tells us one row was
transient, a C tells us the *population* was mismeasured, and the second claim is far more
consequential than the first.

## What must be recorded per canary

For each of the five, regardless of bucket: verdict, bucket (A/B/C), the evidence field that
decided the bucket, the terminal, and the run duration. A bucket assignment without the field
that produced it is not evidence.

## Why this is pre-registered rather than reported afterwards

Today produced three measurement errors of my own (a timestamp comparison that let every row
through a cutoff, a UTF-8 read of UTF-16 logs that returned zero hits, a JSON key fallback that
reported 0 instead of 186). Each was caught, but each shows how easily a reading gets fitted to
an expectation. Writing the decision table before the data exists removes that freedom.

The counter-check that makes this criterion falsifiable: **the buckets are distinguishable only
if `tester_log_decisive_lines` is populated on the new runs.** That field shipped today. If a
canary returns `INFRA_FAIL` and the field is absent or empty, the outcome is **U —
unclassifiable**, which counts as "wave inconclusive", not as A.
