# Stranded Q02 pairs requeued — OWNER decision executed

Date: 2026-07-27
Author: Claude
Decision: OWNER, "Requeue der restlichen 1.246"

## What was released

| stage | rows | pending after |
|---|---:|---:|
| stage 1 (canary) | 50 | 2,089 |
| stage 2 (remainder) | 764 | 2,853 |
| **total** | **814** | |

Tool: `tools/strategy_farm/requeue_stranded_infra.py --phases Q02
--include-q02-exhausted --apply`. All rows set to `status='pending'` with
`attempt_count=0`.

Journals, both reversible:
- `D:\QM\reports\state\requeue_stage1_20260727T203434Z.json`
- `D:\QM\reports\state\requeue_stage2_20260727T203456Z.json`

Revert with `--revert <journal>`.

## Why 814 and not 1,246

My census counted **1,256** stranded (EA, symbol) pairs; ten went to the canary, leaving
1,246. The tool's own eligibility is narrower and I did not override it: it applies an
`attempt_count_poison_floor` of 12 and `max_infra_attempts` of 12, so pairs that have
already burned twelve or more infra attempts are excluded as poisoned. That filter is
correct and I let it stand — those are precisely the pairs least likely to return a
verdict and most likely to burn tester time again.

So the honest description is: **814 of the 1,246 were released; the remaining ~432 are
held back by the tool's poison floor.** They are not lost, and lifting the floor is a
separate decision that should be taken on evidence rather than to round the number up.

## Factory was NOT stopped

The tool's help says `--apply` expects "Factory OFF + DB quiescent". I deliberately did
not do that. `Factory_ON.ps1` requires an interactive, visible session, and a headless
`Factory_OFF` that cannot be cleanly reversed would leave the factory down — a far worse
outcome than lock contention.

Instead the release was staged: 50 rows first, verified, then the remaining 764. The
factory ran throughout. Immediately after each stage: 7 terminals live, 8 work items
active, no stalled claims. No contention was observed.

## Expected yield, stated honestly

The canary's resolved outcomes were **2 PASS, 1 ZERO_TRADES, 5 fresh `INFRA_FAIL`** of 8
resolved — roughly a **25% recovery rate**, and `ZERO_TRADES` is arguably a fourth failure
(`docs/ops/evidence/2026-07-27_stranded_canary_update.md`).

On that basis 814 released pairs should be expected to yield in the order of **200 real
verdicts**, not 814. This was OWNER's decision taken with that number already on the
table.

## Cost and drain

Pending went 2,039 → 2,853, a 40% increase. Recent throughput was net negative on 8 of the
last 10 days (arrivals minus completions), so the queue was draining before this and is
expected to absorb the addition rather than grow indefinitely — but the drain will be
slower and the pre-existing tail (1,458 rows older than 14 days) now sits behind more
work. Claim ordering is priority-first with age as the last tie-break, which is
deliberate, so these will not automatically jump the queue.

## What to watch

- Whether the fresh `INFRA_FAIL` rate on these matches the canary's ~60%. If it is much
  worse, stop and diagnose rather than letting 814 burn.
- The five fresh canary failures remain undiagnosed. They failed *after* the June cause
  was fixed, so they carry a current fault — diagnosing them would likely raise the yield
  of everything released here.
