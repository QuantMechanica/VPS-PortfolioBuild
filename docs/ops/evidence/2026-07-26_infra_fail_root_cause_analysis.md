# INFRA_FAIL — what actually causes it (2026-07-26)

OWNER directive: investigate the failures so they stop recurring; find sustainable fixes.
This is the measurement, including the hypotheses it killed.

## Scope

2,553 `INFRA_FAIL` rows in the seven days from 2026-07-20, against 5,879 total terminal
runs. **43 % of everything the factory ran was written off as infrastructure.**

## The real taxonomy

My first pass called half of them "unrecorded" — that was a defect in my query, not in the
pipeline: it looked for `prior_failure`/`fail_reason` and missed `verdict_reason`, which
**100 %** of rows carry. Corrected distribution:

| count | share | `verdict_reason` |
|---:|---:|---|
| 600 | 23.5 % | `summary_missing_retries_exhausted` |
| 500 | 19.6 % | `run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS` |
| 490 | 19.2 % | `run_smoke_fail:NO_HISTORY;INCOMPLETE_RUNS` |
| 266 | 10.4 % | `shared_bases_history_lock_transient_cap_exhausted` |
| 189 | 7.4 % | `run_smoke_fail:BARS_ZERO;INCOMPLETE_RUNS` |
| 156 | 6.1 % | `ACTIVE_TIMEOUT` |
| 130 | 5.1 % | `invalid_summary:BARS_ZERO,EMPTY_EXPERT,EMPTY_SYMBOL` |
| 66 | 2.6 % | `run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS` |

Grouped: **55 % are "the run produced nothing usable"**, 20 % are "the EA refused to
initialise", the rest is timeouts and the storm class.

## Hypotheses tested and killed

Each of these was plausible, and each is wrong. Recording them so nobody re-runs them.

1. **Missing custom-symbol data on some terminals.** `SP500.DWX` is present on all ten
   terminals with byte-identical sizes (164 MB history, 650 MB ticks). Killed.
2. **Missing symbol history for the energy symbols.** `XTIUSD.DWX` 608 MB and
   `XNGUSD.DWX` 247 MB, identical on all ten terminals. Killed.
3. **MetaTester agent port collisions.** Real but not dominant: every terminal allocates
   agents in 3000-3008 and six bind errors (`[10048]`) appear in today's journals — but the
   per-terminal port sets differ (T10 holds {3000,3001,3004}, T6 {3002,3003}), which proves
   MT5 probes and skips busy ports rather than failing. Contributory at most. Killed as the
   main cause.
4. **Resource starvation.** The decisive test: join every failure and every clean verdict to
   the watchdog's five-minute resource snapshots.

   | metric | INFRA_FAIL (n=92) | clean verdict (n=364) |
   |---|---:|---:|
   | free RAM, median | 29.7 GB | 29.6 GB |
   | commit headroom, median | 62.7 GB | 60.6 GB |
   | pagefile, median | 43.1 % | 48.8 % |
   | pages/sec, median | 6,564 | 7,643 |
   | active items, median | 9 | 9 |

   The distributions are indistinguishable; paging is *higher* on the successful runs.
   Failures do not happen under more pressure than successes. **Killed — and this matters,
   because it also means a concurrency cap would cost throughput without fixing this class.**
5. **Missing magic-registry rows.** Every member of the failing cohort has exactly one
   matching `active` row for its run symbol. Killed.

## What the data does show

**The failures are deterministic properties of specific work, not random infrastructure
events.** Of 1,005 EAs that ran, 486 hit at least one INFRA_FAIL, and many fail *every
single time*:

| EA | runs | INFRA_FAIL | dominant reason |
|---|---:|---:|---|
| QM5_11896 | 119 | **119 (100 %)** | `summary_missing_retries_exhausted` |
| QM5_10001 | 55 | **55 (100 %)** | `summary_missing_retries_exhausted` |
| QM5_9940 | 33 | **33 (100 %)** | `ACTIVE_TIMEOUT` |
| QM5_10485 | 24 | **24 (100 %)** | `ACTIVE_TIMEOUT` |
| QM5_20007 | 18 | **18 (100 %)** | `LOG_BOMB` |
| 15 × QM5_12xxx | 12 each | **12 each (100 %)** | `ONINIT_FAILED` |

The concentration is broad rather than narrow (top 50 EAs = 45 % of failures), so this is
not a handful of bad apples — it is a systemic absence of any "this will never work" state.
**QM5_11896 alone consumed 119 identical runs.** The queue is 96 % Q02 with exactly one
pending Q08 and no pending Q10; a large share of that backlog is work the factory has
already proven it cannot complete.

## ⚠ CORRECTION (same evening): the ONINIT_FAILED attribution below is WRONG

The section that follows blamed the sandboxed news calendar. A population audit found the
real cause, and I verified it directly rather than accepting it: the MT5 tester journals
contain the EA's own runtime error, once per cohort member:

```
EA_MAGIC_NOT_REGISTERED: ea_id=12621 slot=0 magic=126210000
EA_MAGIC_NOT_REGISTERED: ea_id=12734 slot=0 magic=127340000
EA_MAGIC_NOT_REGISTERED: ea_id=12746 slot=0 magic=127460000   (and the rest of the cohort)
```

`QM_MagicRegistered()` returns false **inside the compiled `.ex5`**, so `QM_FrameworkInit`
bails at `QM_Common.mqh:148-150` — *before* `QM_LoggerInit` at line 162. That is precisely
why run_smoke reports "expected exactly one growing logger file, found 0". The binaries
embed an older generation of `QM_MagicResolver.mqh` that predates their own magic row; the
current header contains all 2,966 ea_ids, so **a clean recompile against the current header
fixes the cohort** — no source or CSV change needed.

Three things disprove my calendar attribution outright:

1. The failing QM5_12706 run logged `news_calendar_status=OK … age_hours=4` — the calendar
   was **fresh** at the time of failure.
2. A working energy EA (20049) and a failing one (12706) carry **identical** news settings,
   so news cannot be the differentiator.
3. Decisive and purely logical, which I should have checked myself: the news failure path
   **logs** (`QM_Common.mqh:203`) before returning false. It therefore can never produce the
   "zero logger files" signature that defines this class.

What I got right and still stands: the failures are deterministic per (EA, symbol), they are
not resource-driven, and the pipeline has no notion of "never succeeded". What I got wrong
was the mechanism for the 20 % ONINIT class. The calendar finding remains real as a separate
diagnostic gap — run_smoke validating the `D:` source while the EA reads `Common\Files` — but
it is **not** what killed these runs.

Bonus finding in the same journal scan: `EA_MAGIC_NOT_REGISTERED: invalid symbol_slot=-1300668464`
— an uninitialised `symbol_slot` reaching the resolver as garbage, the known
must-ZeroMemory trap, still occurring.

**Also corrected, in the other direction:** the audit flagged QM5_20007 as symbol-locked to
XAUUSD and therefore mis-dispatched onto NDX/GDAXI/SP500. That is wrong. The lock sits inside
an `else if(intraday_lane == LANE_GOLD_BREAKOUT)` branch, and **all four setfiles select
`LANE_MOMENTUM_BAND`**, so the guard never executes. 20007 is not mis-dispatched.

## ✅ FIXED AND PROVEN AT RUNTIME (2026-07-26 21:39)

Cohort derived from the DB rather than the journal scan — every EA with ≥3 runs since
07-10 and ≥90 % `ONINIT_FAILED`: **27 EAs**, most with a clean 12-of-12 failure record,
~310 wasted runs between them.

All 27 recompiled against the current resolver (`b06b36fd8`); every one returned `COMPILED`,
which the `MAGIC_NOT_IN_RESOLVER` guard would have refused had the row still been absent.

**The proof that matters is not the compile log but the run.** QM5_12610 — 11 of 11 previous
runs `ONINIT_FAILED` — was requeued immediately after its recompile:

```
canary QM5_12610 Q02: status=done verdict=PASS   2026-07-26T19:39:55   terminal T10
```

Requeued one run per (EA, symbol, phase) for the whole cohort — 30 items, deliberately
**not** on the priority track so the FTMO evidence re-runs stay ahead. Reversible from
`D:\QM\reports\state\requeue_stale_resolver_cohort_20260726.json`.

Still open, and it decides whether this recurs: the `MAGIC_NOT_IN_RESOLVER` guard exists
since `91027e955` (2026-07-03), yet three cohort members carry `.ex5` timestamps *after* it
(20035 07-22, 20054 07-23, 12746 07-25). Either a second compile path bypasses
`compile_ea.py`, or `update_magic_resolver.py` can drop a row a binary already depends on,
or those mtimes reflect a deploy rather than a compile. Until that is answered the backlog
is cleared but the mechanism is not.

## The ONINIT_FAILED thread

`OnInit` in these EAs is a single `QM_FrameworkInit(...)` call returning `INIT_FAILED`, and
the failure occurs before the EA writes its first log line ("expected exactly one growing
logger file, found 0"), which rules out anything after initialisation.

Inside `QM_FrameworkInit` (`framework/include/QM/QM_Common.mqh`) the only fail-closed path
with an *external* dependency is:

```
if(any_news_active)
   if(!QM_NewsInit("D:\\QM\\data\\news_calendar", ...))
      { QM_LogEvent(QM_WARN, SETUP_DATA_MISSING, ...); return false; }
```

That is an absolute path, and MQL5 sandboxes file access — an EA cannot open it. The
working route is the `FILE_COMMON` basename in
`Roaming\MetaQuotes\Terminal\Common\Files`, which is why that copy is doctrine.

**A real diagnostic defect follows from this:** `run_smoke` validates calendar freshness
against the `D:` source (its log line `news_calendar_status=OK ... age_hours=22`), while
the EA reads the Common copy. A stale or missing Common copy therefore passes the pre-run
check and then kills the run — invisibly. That is exactly the observed signature.

**Honest limit of the evidence.** Today's calendar refresh (my fix `e95efa9c1`, applied
17:54 local) improved but did not end the class: normalised per hour, all INFRA_FAIL went
from 4.65/h to 2.7/h and ONINIT_FAILED from 2.0/h to 1.15/h — a factor of ~1.7, with three
EAs still failing after the refresh. The calendar is a **contributor, not the proven sole
cause**, and I am not claiming more than the data supports.

## Sustainable fixes that follow

1. **Poison-pill quarantine (highest leverage).** Nothing in the pipeline records "this
   (EA, symbol) has never once succeeded". After N failures with the same `verdict_reason`
   and zero successes, quarantine it and surface it as a diagnosis worklist instead of
   re-queueing forever. This stops thousands of wasted runs and — the point that matters for
   the FTMO book — frees the capacity that Q08/Q10 are currently starved of.
2. **Check the calendar the EA actually reads.** `run_smoke` must validate the
   `Common\Files` copy, not only the `D:` source, so this failure mode can never again be
   invisible to the pre-run gate.
3. Leave concurrency alone. The resource test says throttling would cost throughput and fix
   nothing here.
