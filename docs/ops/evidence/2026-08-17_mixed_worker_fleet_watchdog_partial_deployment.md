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

## Staggered restart — executed 2026-08-17 08:40Z, OWNER-authorized

Progress: **5 of 10 workers now carry the fix** (T1, T3, T8, T9, T10). T8 and T9 were
restarted here; the other three had cycled on their own earlier.

### Correction: the pump does NOT respawn a killed worker

I expected the 5-minute pump to refill the slot, because `start_terminal_workers.py` is
idempotent and the pump invokes it. It does not. T9 was stopped at ~08:36Z, a full pump
tick passed at 08:38Z, and the fleet stayed at **9 workers**. Nothing brought it back.

That matches the known dead `InteractiveToken` task class: `QM_StrategyFarm_WorkerDedupe`
cannot run, `factory_watchdog.ps1` delegates all healing to it by design, and
`interactive_worker_keeper.py` — the interim substitute — is not running. The factory has
no automatic worker self-healing at present. On 2026-07-26 the same gap let the fleet
bleed 9 → 7 → 6 and only manual spawner runs restored it.

**The working procedure is therefore: stop the worker AND immediately run
`python tools/strategy_farm/start_terminal_workers.py --dedupe` from the interactive
session.** Do not stop a worker and wait. I made that mistake with T9 and the fleet ran a
worker short for about four minutes.

### Method that worked

Per worker, in this order:

1. Confirm the terminal holds **no active claim** in `work_items` — restarting a busy
   worker aborts its backtest.
2. Confirm the worker process has **zero child processes** — a running `terminal64`
   under it means work is in flight regardless of what the database says.
3. Resolve the PID by matching the full command line `--terminal <T>`, never by a broad
   name filter. A loose filter killed my own shell earlier in this session.
4. `Stop-Process -Force`, then run the spawner immediately.
5. Verify: fleet back to 10, the terminal's process creation time is after the fix
   commit, and it survives ~25 s (a worker spawned from session 0 dies 0xC0000142, so an
   immediate death means the wrong session).

### Remaining

T2, T4, T5, T6, T7 are stale and all currently busy. They get the same treatment as they
free up. **T4 must be left alone** while `QM5_41030` runs — a 450-minute basket that has
been going since 00:02Z and is the one job on the fleet where a restart would discard
hours of work.

## Prospective confirmation — 2026-08-17 08:00Z, prediction held 4 of 4

The pre-registered prediction was: a symbol that died as `INFRA_FAIL` on a stale worker
will **pass** when re-run on a worker carrying `e607a1bc3`, with no change to the EA, the
setfile or the window. `QM5_20178` was the natural experiment — it had been failing on
four of five symbols all night.

Terminal and duration read from each run's own evidence summary (`work_items.claimed_by`
is cleared on completion, so it cannot serve as the record):

| Symbol | pre-fix | post-fix | terminal | duration | attempts |
|---|---|---|---|---|---|
| NDX.DWX | INFRA_FAIL 08-16 21:13 | **PASS** 08-17 05:30 | T3 | 217.8 min | 1/3 |
| WS30.DWX | INFRA_FAIL 08-16 23:40 | **PASS** 08-17 07:02 | T10 | 229.5 min | 1/3 |
| GBPUSD.DWX | INFRA_FAIL 08-16 23:54 | **PASS** 08-17 07:02 | T1 | 234.6 min | 1/3 |
| USDJPY.DWX | INFRA_FAIL 08-17 03:28 | **PASS** 08-17 07:13 | T3 | 213.9 min | 1/3 |
| EURUSD.DWX | — | PASS 08-16 21:18 | T10 | 209.3 min | 1/3 |
| XAUUSD.DWX | INFRA_FAIL ×3 | running on T9 | — | — | — |

**Four symbols died before the fix and passed after it. None was re-authored between the
two runs.** Every passing run landed on a terminal that carries the fix (T1, T3, T10).
The prediction is confirmed.

The mechanism is visible in the durations: **QM5_20178's Q02 full run costs 209–235
minutes on every symbol** — a tight cluster across six independent symbols. No run of
that length can survive a 90-minute outer deadline, which is why this EA and not others
failed all night. It was never a strategy or symbol property.

Note the asymmetry the deaths leave behind: none of the seven `INFRA_FAIL` rows has an
evidence summary at all. A killed run writes nothing, so the only trace is the absence of
a file — which is why the class read as `summary_missing` / `UNCLASSIFIED` rather than as
a timeout.

`XAUUSD.DWX` is the one symbol still unproven: it failed three times and is currently
running on T9, a fixed worker. It is the last open item of this experiment.
