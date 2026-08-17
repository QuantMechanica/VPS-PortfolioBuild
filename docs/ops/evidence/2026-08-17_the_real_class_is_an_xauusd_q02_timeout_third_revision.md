# The real class is an XAUUSD Q02 timeout — my third diagnosis, and the first with a discriminator

## Three diagnoses of one class, in two rounds

| Round | I said | Why it was wrong |
|---|---|---|
| 24 | the journal was **purged** by the 2h retention | the journal was never written — the file tree showed only `tester.ini` |
| 25 | the tester **failed to launch** | it launched: `metatester64` pid 20432 holds **4,723 s of CPU** against 86 min wall |
| **26** | **the run times out because XAUUSD is too slow to finish a 4.5-year Q02 in 7200 s** | has a discriminator (below) |

I am recording all three because the sequence is the point: each revision came from a better
observation, and the first two were mechanisms I found plausible before I had looked at the right
thing.

## Why diagnosis 2 was wrong, including the control that misled me

Last round I "controlled" for mid-run journals by noting that active **Q07** runs already hold
journals. That control was invalid. **Q07 is multiseed** — it runs several sequential passes, so its
journals belong to *finished seeds* while the current seed is still in flight. A single-pass **Q02**
writes its journal and report only at the end of the pass. So an in-flight Q02 with no journal is
entirely normal, and I read normality as pathology.

The live process table settles it. For the two stalled claims:

```
T6  QM5_20178/XAUUSD  Q02  86 min wall   metatester64 pid 20432   4,723 s CPU   1 file, 496 B
T5  QM5_13205/basket  Q02  53 min wall   metatester64 pid 16368   2,889 s CPU   1 file, 459 B
```

79 minutes of CPU against 86 minutes of wall time is a tester saturating a core, not one that failed
to start.

## The discriminator: it is the symbol, not the window

QM5_20178's Q02 across every symbol it was dispatched on:

| Symbol | window | outcome |
|---|---|---|
| EURUSD | — | **PASS** |
| GBPUSD | — | **PASS** (after one `unclassified`) |
| NDX | 2021.01.01 → 2022.12.31 | **PASS** (after one) |
| USDJPY | — | **PASS** (after one) |
| **WS30** | **2018.07.02 → 2022.12.31** | **PASS** |
| **XAUUSD** | **2018.07.02 → 2022.12.31** | **4 failures + 1 active, never passed** |

**WS30 carries the identical 4.5-year window and completes.** So the window is not the differentiator
— the symbol is. XAUUSD.DWX is the most heavily used symbol in the farm (9,991 work-item rows) and the
densest in ticks. The same EA over the same span finishes on WS30 and cannot finish on XAUUSD inside
7200 s.

`ACTIVE_TIMEOUT` appears once in the XAUUSD history, which is the same event recorded honestly; the
three `summary_missing:unclassified` rows are that same timeout recorded after the kill, when nothing
had been written yet to classify.

## What this costs, recomputed on the right mechanism

Each requeue re-runs a two-hour computation that cannot complete. Four terminal rows at up to three
internal attempts each is roughly **12 attempts × up to 2 h ≈ up to 24 slot-hours on a single
(EA, symbol) pair** — essentially the whole ~25 slot-hours I attributed to the class. The cost figure
was right; the reason was not.

And it is still running: the fifth attempt is at 86 of its 120 minutes as I write, and a sixth will
follow, because nothing recognises "this pair has timed out four times".

## What actually fixes it

Not retention. Not a launch repair. Three real options, in increasing cost:

1. **A per-pair timeout budget.** The stopping rule I proposed remains correct but must key on
   *repeated timeout*, not on any absence signature: four timeouts on the same (EA, symbol, phase) is
   a determination, and the fifth dispatch should not happen.
2. **A symbol-aware timeout.** If XAUUSD legitimately needs more than 7200 s for a 4.5-year pass, the
   ceiling is mis-set for that symbol rather than the run being broken. That is checkable: measure
   the wall time of *successful* XAUUSD Q02 runs over comparable windows.
3. **A shorter window for dense symbols.** NDX passed on a 2-year window; XAUUSD is being asked for
   4.5. Whether that is required by the phase contract or inherited by accident is worth knowing.

Option 1 stops the bleeding regardless of which of 2 or 3 is right, so it should not wait for them.

## Options 2 and 3 measured, and both are falsified

Wall time of **successful** Q02 runs, recovered from run-directory start stamps against
`summary.json.timestamp_utc`:

| Symbol | n | median | p90 | max | runs > 7200 s |
|---|---:|---:|---:|---:|---:|
| **XAUUSD.DWX** | 471 | **6.4 min** | 17.2 min | 104.0 min | **0** |
| WS30.DWX | 110 | 4.1 min | 10.4 min | 109.5 min | 0 |
| NDX.DWX | 400 | 3.5 min | 10.4 min | 97.8 min | 0 |
| EURUSD.DWX | 672 | 3.5 min | 8.5 min | 89.3 min | 0 |

**Option 2 is wrong: the 7200 s ceiling is not mis-set for XAUUSD.** It is ~19× the median and ~7× the
p90, and **not one of 471 successful XAUUSD Q02 runs exceeded it.** Only 1 % run beyond 60 minutes.

**Option 3 is unnecessary:** WS30 carries the same 4.5-year window at a 4.1-minute median, so the
window is affordable. XAUUSD is ~1.8× slower than the other symbols at the median — real, but nothing
like the gap that would be needed to explain a timeout.

So **QM5_20178/XAUUSD is a genuine outlier at roughly 19× the median comparable run**, and the anomaly
lives in this EA's computation on this symbol, not in the ceiling, the window, or the symbol as such.
Worth noting that near-ceiling runs do exist and do succeed — QM5_20176/XAUUSD took 104.0 minutes and
passed — so the ceiling is tight for the tail but adequate.

**Option 1 is therefore the whole remedy for the loop**, and the open question narrows to a single
well-posed one: what in this EA scales with XAUUSD tick density such that it cannot finish in 120
minutes while finishing on five other symbols? That is a code question about one EA, not an
infrastructure question.

## The transferable lesson, stated once

I asserted a mechanism three times before measuring the one thing that separated the cases — the same
EA's behaviour on *other symbols*. That comparison was available from the start and would have pointed
at the symbol immediately. **When a failure is confined to one member of a set, compare against the
set before theorising about the member.**

## Evidence

- live process table: `metatester64` pid 20432 (T6) 4,723 s CPU, pid 16368 (T5) 2,889 s CPU
- per-claim file inventory: T6 1 file/496 B, T5 1 file/459 B, T7 23 files/94.6 MB (alive, Q07)
- QM5_20178 Q02 across six symbols with per-row verdicts and windows
- corrects: `2026-08-17_unclassified_is_a_launch_failure_not_a_purged_journal.md` (diagnosis 2) and
  the stopping-rule leg of `2026-08-17_log_retention_is_crisis_era_tuning_that_outlived_the_crisis.md`
- the retention raise itself stands on its forensic justification and is unaffected
