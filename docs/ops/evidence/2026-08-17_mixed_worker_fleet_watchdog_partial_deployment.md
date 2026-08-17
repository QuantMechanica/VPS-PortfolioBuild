# The worker fleet is running two different versions of the watchdog (2026-08-17)

## What prompted the check

`QM5_20178` `NDX.DWX` Q02 **completed with PASS after 98.7 minutes** — claimed
03:50:41Z, started 03:52:15Z, done 05:30:58Z — with `timeout_seconds = 7200` and no
`timeout_min` override in its payload.

That should have been impossible. The outer watchdog kills at the worker's
`--timeout-minutes` default of 90 minutes from process start, which is what killed four
runs of this exact EA earlier in the night and what killed `c7a4351f` at 90 min 09 s in a
pre-registered test. A run surviving to 98 minutes contradicts the model.

## Measurement

`terminal_worker.py` is resident in each worker from process start, so a worker enforces
whatever version of the code existed when it launched. The fix (`e607a1bc3`, committed
2026-08-17 02:30:48 +0200) binds the outer deadline to the inner computed budget.

Worker process creation times against that commit:

| Worker | Terminal | Started | Code |
|---|---|---|---|
| 12760 | T1 | 2026-08-17 06:50:27 | **fixed** |
| 18576 | T3 | 2026-08-17 05:20:40 | **fixed** |
| 8384 | T10 | 2026-08-17 06:50:28 | **fixed** |
| 14360 | T2 | 2026-08-16 22:50:35 | stale |
| 8 | T4 | 2026-08-16 23:00:51 | stale |
| 15952 | T5 | 2026-08-16 15:00:51 | stale |
| 9576 | T6 | 2026-08-16 23:10:35 | stale |
| 14568 | T7 | 2026-08-16 18:50:27 | stale |
| 16776 | T8 | 2026-08-16 21:50:25 | stale |
| 9000 | T9 | 2026-08-16 14:25:11 | stale |

**3 of 10 workers carry the fix; 7 do not.** The surviving run was on **T3**, one of the
three.

## Two consequences, and the second is the problem

**The ceremony is not required.** Workers respawn on their own, and the fix propagates as
they cycle. Three picked it up within about four hours of the commit without any
intervention. That materially lowers the cost of deploying this class of fix and removes
the argument for an unattended `Factory_OFF` / `Factory_ON` at night, where an aborted ON
writes `OFF_RECOVERY_REQUIRED` and stops the whole works.

**The fleet is in a mixed state, which is worse than being uniformly broken.** The same
work item now lives or dies according to which terminal claims it: a heavy Q02 completes
on T1, T3 or T10 and is killed at 90 minutes on the other seven. Two consequences follow:

1. *Evidence becomes non-deterministic.* A row's verdict depends on terminal assignment,
   which is not part of the strategy and not recorded as a variable in any comparison.
2. *It invites wrong conclusions.* `QM5_20178` was failing on four of five symbols all
   night. NDX now passes. Without knowing about the split, the natural reading is that
   something about the EA or the symbol changed. Nothing did — it simply landed on a
   fixed worker.

The uneven ages also mean waiting is not a plan: T9 has been up since 14:25 the previous
day and T5 since 15:00, so natural cycling could leave the split in place for a long time.

## Recommendation

Recycle the seven stale workers in a staggered sequence rather than running a full
Factory OFF/ON. That completes the propagation, is far cheaper than the ceremony, and
carries none of the `OFF_RECOVERY_REQUIRED` exposure. Until it is done, any comparison
between runs of the same EA must record which terminal served each one.

## Reading rule while the split lasts

A `summary_missing` / `UNCLASSIFIED` death at approximately 90 minutes on T2, T4, T5, T6,
T7, T8 or T9 is the known watchdog defect and is not evidence about the EA. The same row
on T1, T3 or T10 is a real test.
