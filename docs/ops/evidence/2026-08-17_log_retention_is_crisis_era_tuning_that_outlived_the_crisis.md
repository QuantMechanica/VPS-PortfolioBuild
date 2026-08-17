# The 2-hour log retention is crisis-era tuning that outlived its crisis — and relaxing it costs ~1 GB

## What surfaced it

`ef08a876` QM5_20178/XAUUSD came back `INFRA_FAIL` with `failure_class: UNCLASSIFIED`,
`prior_failure: summary_missing`, `attempt_count=2`. Its report root exists with 13 files across
three run directories from today (`065834`, `091246`, `122500`) — and **zero `*.log` files**. The
classifier had no journal to read, so the failure is permanently unattributable.

Rate of that class: **4 today, 5 on 08-16, 1 on 08-15, 5 on 08-14, 1 on 08-13** — roughly 16 in
five days. Small, persistent, and each one is an INFRA_FAIL nobody can ever explain.

## The mechanism, measured rather than inferred

Every surviving journal under `D:\QM\reports\work_items` — a clean cliff at two hours:

| Age | `*.log` files |
|---|---:|
| < 1 h | **36** |
| 1–2 h | **32** |
| 2–4 h | **0** |
| 4–12 h | **0** |
| > 12 h | **0** |

And the task doing it is not the one I blamed in P0:

```
QM_StrategyFarm_ReportsLogPurge_12h
  trigger repeat : PT1H          <- HOURLY, despite the "_12h" in the name
  action         : reports_log_purge.ps1 -RetentionHours 2
  last run       : 16:17 local   next: 17:17
```

**Correction to my own P0 attribution.** In P0 I named
`prune_workitem_logs.py --older-than-days 0` as the reason tester logs are unavailable for
classification. That task is real but only touches terminal items updated *before today*. The
binding constraint is this one: **an hourly purge with a 2-hour retention**, which removes journals
while runs are still being classified. My P0 conclusion (capture the decisive lines at
classification time) stands; the culprit named there was the wrong one.

## The configuration drifted from its own design document

`docs/ops/ACCELERATION_2026-06-10.md:72` records the intended design:

> *"(`reports_log_purge.ps1`, **12h cadence, 48h retention**) but was mistuned —"*

Live: **1 h cadence, 2 h retention.** That is 12× more frequent and **24× more aggressive on
retention** than the documented design. Nobody updated the document, so the scheduler inventory and
the design note both describe a system that is not running.

## Why the tuning made sense then and does not now

The June 10 incident that motivated it: **475 GB of dead logs**, 36,103 journals at 529 GB — roughly
**15 MB each**. Against that, a 2-hour retention is obviously right.

Today's journals, measured over the surviving 69:

| | |
|---|---|
| total (2 h worth) | **0.04 GB** |
| median | **0.1 MB** |
| p90 | 2.3 MB |
| max | 10.1 MB |

**Median journal size has fallen roughly 150× since the crisis** — plausibly because the LOG_BOMB
class was fixed (per-tick news checks on synthetic hosts) and because `prune_workitem_logs` keeps
summaries while dropping bulk. So the retention is calibrated against a condition that no longer
exists.

## The cost of relaxing it

At the measured ~0.02 GB per hour of retention:

| Retention | Disk |
|---|---:|
| current 2 h | 0.04 GB |
| 6 h | ~0.1 GB |
| 12 h | ~0.3 GB |
| **48 h (the documented design)** | **~1.0 GB** |

D: currently has **162.3 GB free**, i.e. 12.3 GB above the `tester_cache_purge` low-water of 150 GB.
**Restoring the documented 48-hour retention costs about 1 GB and would eliminate the UNCLASSIFIED
class outright.**

## Recommendation, with the caveat that belongs to it

**Restore retention toward the documented 48 h** — or at minimum 12 h, which already covers any
realistic classification delay. It is the cheapest fix available to any problem on the current list.

**The caveat:** 0.02 GB/h is measured over a two-hour window on a day running ~34 completions/hour.
A busier day, or a regression that reintroduces multi-megabyte journals, changes it by orders of
magnitude — the crisis-era figure was 150× larger per file. So a pure time-based retention is the
wrong shape twice over:

> Make the purge **size-aware**: keep journals for N hours *or* until the journal tree exceeds a
> stated budget, whichever binds first. That way the retention serves classification in normal
> operation and still collapses automatically if a LOG_BOMB class returns — which is exactly the
> failure the 2-hour setting was defending against.

And independently of retention, **P0's requirement still stands and is strictly better**: lift the
decisive log lines into the evidence at classification time. Then retention becomes irrelevant to
attribution rather than merely generous.

## Also worth fixing while it is visible

The task name says `_12h` and the trigger says `PT1H`. Anyone reading the scheduler inventory — I
did, two rounds ago — will believe the name. Rename or re-trigger so the two agree.

## Evidence

- `ef08a876-…` QM5_20178/XAUUSD — `failure_class: UNCLASSIFIED`, report root present, 0 `*.log`
- age histogram of all 69 surviving journals under `D:\QM\reports\work_items`
- `Get-ScheduledTask QM_StrategyFarm_ReportsLogPurge_12h` — `PT1H`, `-RetentionHours 2`
- `docs/ops/ACCELERATION_2026-06-10.md:18,72` — the 475 GB incident and the intended 12h/48h design
- related: `2026-08-17_P0_evidence_loss_is_dated_not_ongoing.md` (attribution corrected here)
