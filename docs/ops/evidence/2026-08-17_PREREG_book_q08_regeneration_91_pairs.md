--- 
status: PRE-REGISTERED — written before the first run
---

# Pre-registration — regenerating all 91 pool sleeve streams under a recorded binding (option (b))

OWNER decided (b) and widened it to 91. This states, **before any result exists**, what will be run,
what each cohort is predicted to do, and what outcome would falsify the plan. Nothing has been
rebuilt, enqueued or run at the time of writing.

Frozen membership: `artifacts/book_q08_regeneration_cohorts_20260817.json`, schema
`qm.book-q08-regeneration-cohorts/v1`, 91 pairs, 0 unresolved.

## Why this is being run at all

The archived sleeve streams cannot be authenticated against current-tree behaviour: the binaries
that produced them are gone, the sealed evidence records no source commit or MQ5 hash, and the
setfiles have moved too
(`docs/ops/evidence/2026-08-17_the_vintage_question_is_unanswerable_and_why_that_argues_for_b.md`).
Regenerating them under a binding that *is* recorded resolves that, and simultaneously supplies the
`side` / `entry_price` fields that 3.3 and 3.4 need for the intraday path.

## The design, and why no separate vintage probe is needed

The rich stream emitter landed in `framework/include/QM/QM_Common.mqh` at commit **`85db6178c`,
2026-07-30 01:18**. That date splits the pool into three cohorts with *different* predictions, which
makes the 91 runs a controlled experiment rather than a bulk regeneration:

| cohort | n | binary | archived stream | action |
|---|---:|---|---|---|
| **C1** | **12** | post-cutoff, **unchanged since the stream was written** | already rich | re-run only |
| **C2** | **26** | post-cutoff | not yet rich | re-run only |
| **C3** | **53** | pre-cutoff (51 distinct EAs) | not rich | **rebuild**, then re-run |

**C1 is a determinism control that costs nothing extra**, because it is already inside the 91. Every
one of the 12 has an `.ex5` older than its stream file, so re-running executes *the same binary that
wrote the archived stream*. Verified for all 12, 0 exceptions.

A separate archived-vs-current probe was planned and is not runnable — the baseline arm no longer
exists. The Q08 re-run replaces it: Q08 is the deepest gate (11 sub-gates), so a rebuilt binary that
still passes Q08 on the same setfile is substantive evidence the strategy survived the recompile,
and a flip is exactly the vintage-dependence signal the 2026-07-28 bisect was chasing.

## Predictions, each with its falsifier

**C1 — determinism.** *Predicted:* the re-run reproduces the archived stream trade-for-trade (same
count, same entry/exit times, same volumes, net P&L equal within the fidelity tolerance 0.005).
*Falsifier:* any divergence. That would mean the tester is not reproducible, and **every** stream
comparison in 3.3/3.4 is weaker than assumed — including the fidelity ladder that 3.3's acceptance
rests on.

**C2 — same binary, richer record.** *Predicted:* the re-run emits the rich schema **and** the trade
content matches the archived stream, because the binary is unchanged. *Falsifier:* content differs.
That would mean the archived stream was not produced by the binary now sitting in the EA directory,
i.e. provenance is worse than the drift measurement suggested.

**C3 — rebuild.** *Predicted:* rich schema, and the Q08 verdict is unchanged from the archived one.
*Falsifier:* verdict flips. Each flip is a pair whose admission was vintage-dependent, and the count
of flips is the measurement the vintage question has been asking for since 2026-07-27.

**Pre-registered interpretation of C3 flips:** a small number (≲5 of 53) is consistent with ordinary
gate noise near thresholds and will be reported per pair, not treated as systemic. A large number
(≳15 of 53) means the framework changed strategy behaviour materially, and the pool itself — not
just its streams — needs revalidation before 3.2 can build on it.

## Order of execution, and the stop rule

**C1 → gate → C2 → C3.** C1 runs first and alone. **If C1 shows any divergence, C2 and C3 are not
started** and the finding is reported instead: a nondeterministic tester invalidates the premise of
the whole exercise, and spending 79 further runs before knowing that would be wasteful.

C3's rebuilds run **serially** with `compile_one.ps1 -EALabel <label> -Strict`, and `build_check`
is invoked **`-EALabel`-scoped only** — an unscoped invocation mutated 9,072 setfiles on 2026-08-13
and must not recur.

## Cost and why the queue is not being reordered

A fresh Q08 row scores `10 + 2 - age_weeks = 12` in the claim order
(`farmctl.py:1178-1182`; Q08 phase-rank 2 vs Q04 6 and Q02 8 — downstream phases drain first by
design). Measured against the live queue: **365 claimable rows rank ahead of a fresh Q08 row, 36
tie, 1,580 fall behind.** At the observed 15–19 completions/hour the batch should begin within about
a day and complete inside two.

**No priority-track intervention is being made.** `set_priority_track.py` is capped at
`MAX_EXACT_IDS = 10` and bound to a specific OWNER decision; it is not a bulk operator and 91 rows
have no business going through it. E7 ("Warteschlange bleibt, wie eingereiht") therefore stands
untouched — the phase ranking already delivers the needed ordering without moving anything.

## What this run will NOT do

No AutoTrading, no T_Live contact, no deployment. No existing verdict is rewritten — new rows are
appended and old ones superseded. No gate threshold is changed. No running backtest is interrupted.
The living 24-sleeve roster is untouched. Nothing here promotes a phase or removes a factory flag.

## Known exposure, stated up front

Rebuilding 51 EAs makes their existing **Q02–Q07** verdicts binary-stale in the same sense that
motivated this exercise. This run does not re-run those phases. The exposure is real and is being
recorded rather than silently absorbed: the Q08 re-run tests the deepest gate, and the C3 flip count
is the evidence on which a decision about the upstream phases should later be taken.

## Evidence

- cohorts: `artifacts/book_q08_regeneration_cohorts_20260817.json`
- pool: `artifacts/pool_union_20260817.json` (91 members)
- emitter: `framework/include/QM/QM_Common.mqh:1717`, landed `85db6178c` 2026-07-30 01:18
- claim order: `tools/strategy_farm/farmctl.py:1088-1112`, `:1178-1182`
- binding contract: `tools/strategy_farm/isolated_work_item_runner.py:1690-1713`
- precedent for a prepare/apply run-preparation script:
  `tools/strategy_farm/prepare_ftmo_book3_q02.py`
