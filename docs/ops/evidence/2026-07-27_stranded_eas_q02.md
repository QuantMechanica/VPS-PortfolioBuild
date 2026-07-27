# 1,256 (EA, symbol) pairs are stranded at Q02 with no verdict and nothing queued

Date: 2026-07-27
Author: Claude
Reproduce: queries below against
`D:/QM/strategy_farm/state/farm_state.sqlite` (read-only)

## Summary

Hunting loose ends on OWNER's instruction, starting from the largest failure bucket in
the factory. Three findings, in order of consequence.

### 1. The queue is DRAINING, not growing

Arrivals versus completions per day, all phases:

| day | created | done | failed | net |
|---|---:|---:|---:|---:|
| 2026-07-27 | 96 | 152 | 17 | **-73** |
| 2026-07-26 | 310 | 620 | 9 | **-319** |
| 2026-07-25 | 332 | 297 | 5 | +30 |
| 2026-07-24 | 696 | 757 | 86 | **-147** |
| 2026-07-23 | 892 | 1079 | 113 | **-300** |
| 2026-07-22 | 570 | 819 | 139 | **-388** |
| 2026-07-21 | 501 | 605 | 400 | **-504** |
| 2026-07-20 | 660 | 762 | 294 | **-396** |
| 2026-07-19 | 982 | 735 | 156 | +91 |
| 2026-07-18 | 169 | 349 | 11 | **-191** |

Net negative on 8 of 10 days. The 2,073 pending items are a working buffer, not a leak.
This materially softens the "fleet is structurally saturated, days of backlog" framing in
`docs/ops/evidence/2026-07-27_joint_backtest_run_results.md` §1.1: the backlog is real
but it is being consumed.

### 2. The 44,760 Q02 `INFRA_FAIL` rows are a historical scar, largely healed

```sql
SELECT verdict, count(*) FROM work_items
WHERE phase='Q02' AND status='failed' GROUP BY verdict ORDER BY 2 DESC;
-- INFRA_FAIL 44760, INVALID 1578, (null) 684, OBSOLETE_NON_DWX_SYMBOL 12, ...
```

By month of last update:

| month | rows |
|---|---:|
| 2026-06 | **43,599** |
| 2026-07 | 1,128 |
| 2026-05 | 33 |

That is ~1,453/day in June against ~42/day in July — a **35x reduction**. Whatever was
fixed after the June event worked. The dominant payload reason is
`summary_missing_retries_exhausted` (19,570 of a 20,000-row sample).

The 2026-07-26 root-cause note attributed the class partly to EAs hard-depending on the
news calendar. That mechanism is **not currently active**: `QM_Common.mqh:197` loads
`D:\QM\data\news_calendar`, and `QM_News.mqh:287-297` already falls back to
`FILE_COMMON` and then to the bare basename, with the comment that MT5 build 5833+
rejects absolute paths with a drive letter. The fallback target exists and is current:

```
Administrator  forex_factory_calendar_clean.csv  4,314,335 bytes  2026-07-26 17:54
QMDev1         forex_factory_calendar_clean.csv  4,306,549 bytes  2026-07-19 18:12
QMDev2         forex_factory_calendar_clean.csv  4,306,549 bytes  2026-07-19 18:12
```

All three are inside the 336-hour staleness ceiling. Note `QM_Common.mqh:204` returns
**false** — a hard init failure — when `QM_NewsInit` fails, so this path remains a
single point of failure for every news-enabled EA if the Common copy ever lapses. The
QMDev copies are 8 days old; only the 05:30 refresh of the `D:` source is scheduled.
**Whether the Common copies are refreshed by anything is NOT ESTABLISHED and should be.**

### 3. The actual loose end: 1,256 stranded pairs across 442 EAs

```sql
SELECT ea_id, symbol,
  sum(CASE WHEN verdict IN ('PASS','PASS_SOFT','PASS_LOWFREQ','FAIL','FAIL_HARD',
                            'FAIL_SOFT','RETIRE','MULTI_SEED_PASS') THEN 1 ELSE 0 END) real_verdicts,
  sum(CASE WHEN verdict='INFRA_FAIL' THEN 1 ELSE 0 END) infra,
  sum(CASE WHEN status='pending' THEN 1 ELSE 0 END) still_pending
FROM work_items WHERE phase='Q02' GROUP BY ea_id, symbol;
```

| population | pairs |
|---|---:|
| Q02 (EA, symbol) pairs total | 13,538 |
| with a real verdict | 9,895 |
| no verdict but still queued | 1,732 |
| **stranded: no verdict, only `INFRA_FAIL`, nothing queued** | **1,256** |

Across **442 distinct EAs**. Verified:

- **All 442 have a source directory** under `framework/EAs/` — these are real EAs, not
  registry ghosts.
- **137 of 442** nonetheless have a completed work item at some other phase, so their
  Q02 stranding did not block them. **The remaining ~305 EAs have no completed work item
  anywhere** — they entered the factory and silently fell out.
- Last Q02 activity: 795 pairs in June, **461 pairs in July**. This is not purely the
  June scar; a third of it is recent.

Worst offenders by infra-row count: `QM5_9940/SP500` (37 rows), `QM5_10485/USDJPY` (26),
`QM5_10792` across six symbols (24 each), `QM5_10226/EURUSD` (24), `QM5_10809` (24).

## Why this matters

Sleeve supply is the binding constraint on the entire FTMO programme: only 15 sleeves are
gate-clean with usable evidence, and the best scores 0.41 against a target of 1.0
(`docs/ops/evidence/2026-07-27_sleeve_improvement_targets.md`). **~305 EAs that never got
a single verdict is the largest untapped candidate pool in the operation** — larger than
anything the research lane could produce in weeks.

They are also exactly what OWNER described: *"EAs stranden"*. Nothing is watching for
this. A pair that exhausts its retries leaves no queued successor and no alert; it simply
stops existing as far as the pipeline is concerned.

## What is NOT established

- **Whether they are recoverable.** The June cause appears fixed, but these rows were
  never retried after the fix. A requeue might now succeed, or might hit a deterministic
  per-EA defect — the 2026-07-26 analysis found genuine deterministic EA defects too
  (`QM5_11896` failed 119 of 119). Only a canary establishes which.
- **Why the July 461 failed**, given the June cause is fixed. This is the more urgent
  half: it suggests a second, still-active mechanism.
- Whether the Common-Files calendar copies are refreshed by any scheduled job.

## Recommended next step

A **canary requeue of ~10 stranded pairs**, spread across different EAs and symbols and
across both the June and July cohorts, to establish recoverability before anyone
considers the other 1,246. Ten backtests against a 2,073-item queue is negligible; the
information is decisive. Mass requeueing remains a capacity decision for OWNER and must
not be done on the strength of this document.

Detection is the durable fix: a pair that exhausts retries with no real verdict and no
queued successor should raise a health-check invariant, not vanish. `farmctl health`
already runs pipeline invariants and is the natural home.
