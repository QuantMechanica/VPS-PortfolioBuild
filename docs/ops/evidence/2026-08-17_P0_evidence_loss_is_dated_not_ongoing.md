# P0 — The evidence loss is dated, not ongoing; the watcher is live; ~35,900 verdicts are provably unbacked

## The rule that drove this, and why my earlier read was wrong

Last round I reported "current evidence is safe — nothing from August is missing, so this is
not an active process". That reasoning was invalid, and the correction is now a standing rule:
**absence in the newest cohort is never evidence that an age-triggered mechanism has stopped.**
An age-based retention *always* leaves the newest cohort looking clean. A monotone 100 % / 21 %
/ 0 % gradient is the signature of a *running* retention just as readily as of a finished
incident. The monthly aggregate could not tell them apart.

## Date or age? Measured per-day, and the answer is DATE

Monthly buckets hide the shape. Per-day present/missing over 60,504 rows with a set
`evidence_path`:

```
…2026-07-05   438 rows   100.0% missing
  2026-07-06   357 rows   100.0% missing     <- hard wall
  2026-07-07   571 rows    36.4% missing
  2026-07-08   645 rows    32.1% missing
  2026-07-09   744 rows     9.7% missing
  2026-07-10   831 rows     4.3% missing
  2026-07-13   533 rows    43.7% missing     <- isolated spike
  2026-07-14   667 rows     0.7% missing
  …07-15..07-28  ~0.0-2.1% missing
  2026-07-29  1074 rows    43.1% missing     <- isolated spike
  2026-07-30      5 rows     0.0% missing
  2026-08-01..17            0.0% missing  (every single day)
```

**This is not an age ramp.** Two features rule it out:

1. A **hard wall** at 2026-07-06: 100 % missing on 07-06, 36 % on 07-07. An age threshold
   produces a gradual crossing, not a 64-point step in one day.
2. **Isolated spikes at 07-13 (43.7 %) and 07-29 (43.1 %), each sandwiched between ~0 % days.**
   Age is monotone in calendar time — a rolling rule *cannot* delete 07-13 while sparing 07-12
   and 07-14. Those are event losses, not retention.

So the boundary sits on **dates**, which means one bulk event around 07-06/07-10 plus two
later incidents. Recorded so it is falsifiable: if this were an age rule with the boundary at
41 days, the boundary would sit near **2026-07-14 in a week's time**. The watcher will show
that directly.

## ~35,900 verdicts are provably unbacked — and I excluded the cheaper explanation first

Before claiming deletion I tested whether the evidence was ever *written*. A run that dies
before producing a summary has nothing to write, and such a row is indistinguishable from a
deleted one by a file-existence check.

Discriminator: a **PASS/FAIL-family verdict is derived from `summary.json`**, so its existence
at grading time is not in question.

| Absent rows by verdict | count | reading |
|---|---:|---|
| PASS | 20,051 | summary **must** have existed |
| FAIL | 15,398 | summary **must** have existed |
| INFRA_FAIL | 6,368 | may never have produced one |
| INVALID | 660 | may never have produced one |
| other productive | 616 | summary must have existed |

**35,918 of 43,151 absent rows (83.2 %) carry a productive verdict.** The "never written"
explanation is falsified for the bulk. By month: May 7,331 · June 25,588 · July 2,999 ·
**August 0**.

## Mechanism: searched, and honestly not found

Excluded, each with a reason rather than a guess:

| Candidate | Why it is not the cause |
|---|---|
| `reports_log_purge.ps1` | `Get-ChildItem -Recurse -File -Filter *.log`; removes no directories |
| `tester_cache_purge.ps1` | scoped to `T<n>\Tester`, never `D:\QM\reports` |
| `prune_workitem_logs.py` | deletes `*.log` inside a root; **keeps** summary.json / report.htm |
| `rollback_batch.py` | removes `framework/EAs` dirs whose name starts `QM5_`, not report roots |
| requeue-archive rename | `.requeued_*` roots do exist (488 ids) but account for **6** rows |
| path-convention migration | convention is byte-identical May→July: `work_items\<uuid>\<EA>\<stamp>\summary.json` |
| evidence never written | falsified: 83.2 % carry a productive verdict |

`20260523_152211` exists nowhere under `D:\QM\reports`. Nothing in the repo or the Windows
scheduler removes whole `work_items` trees. **Mechanism documented as not findable** — naming a
culprit here would be exactly the failure this document exists to prevent.

## A different live mechanism found, and it explains a recurring wall

`QM_WorkItemLogPruner_Daily_0310` runs `prune_workitem_logs.py --older-than-days 0` — last run
today 12:10, result 0. It correctly keeps summaries, but it removes every terminal work item's
raw tester journal essentially immediately.

**That is why INFRA_FAIL classification from tester logs keeps failing** — 99 of 103 BARS_ZERO
rows were unclassifiable earlier today for exactly this reason. The logs are not lost to a
mystery; they are deleted by design within ~24 h. The consequence is a requirement, not a bug
report: **decisive log lines must be lifted into the evidence at classification time**, because
the log will not be there tomorrow. Raising retention is a palliative; capturing the lines is
the fix.

## The watcher is live, and it can fire

`tools/strategy_farm/evidence_cohort_watch.py` — records a named cohort of report roots that
exist *today* and re-checks them on every later run. **1,205 rows baselined, 1,205 intact.**
Exit 3 means LOSS OBSERVED; the oldest baselined row that vanishes dates the retention window.

Because a watcher deployed onto a healthy farm reports NO_LOSS whether or not it works, the
firing paths are proven rather than assumed —
`tools/strategy_farm/tests/test_evidence_cohort_watch.py`, **4 controls, all passing**:

- negative: intact evidence must **not** be reported as a loss
- positive: whole report root vanished → exit 3, counted as a root loss
- positive: root survives but summary gone → exit 3, counted **separately** so two different
  mechanisms are not conflated
- guard: an **empty baseline is an error, not a pass** — otherwise the task runs green for
  weeks while observing nothing

Scheduled as `QM_EvidenceCohortWatch_Daily_0420`, SYSTEM/Highest, verified with a manual start:
result 0, check logged.

## Delivery-relevant evidence mirrored off-host

`_evidence_mirror` on G:, same pattern as the commit bundle. **143 files, 3.3 MB, verified
present at the destination.** Evidence file plus sibling metadata only — raw `*.log` excluded as
bulk and regenerable.

| Class | mirrored | already absent |
|---|---:|---:|
| Q10 PASS survivors | **40** | 0 |
| Q14 cohort | **11** | 0 |
| Q09_PORTFOLIO verdicts | 65 | **58** |

The important line: **every Q10 survivor and every Q14 cohort row still has its evidence, and
all of it is now off-host.** The 58 absent portfolio verdicts are the known casualty and cannot
be recovered by copying.

SYSTEM cannot see `G:`, so the mirror is a session tool by design and deliberately not a
scheduled task.

## Definition of Done, against the four asks

1. **Mechanism** — not findable, with an explicit exclusion table. A second, real mechanism was
   found and named (the log pruner) with its operational consequence.
2. **Cohort watcher active** — 1,205 rows, 4 controls passing, scheduled and verified.
3. **Date vs age** — **date**, from the per-day shape: a 64-point step in one day plus isolated
   spikes between clean days, neither of which age can produce.
4. **Delivery-relevant evidence secured** — 143 files on G:, Q10 and Q14 complete.

## Evidence

- `artifacts/evidence_retention_boundary_20260817.json` — per-day present/missing, all 60,504 rows
- `artifacts/evidence_absent_vs_never_written_20260817.json` — the 83.2 % productive-verdict split
- `artifacts/evidence_recoverability_20260817.json` — requeue-archive and purge-quarantine indexes
- `artifacts/evidence_cohort_baseline.json` — the watched cohort
- `artifacts/evidence_mirror_manifest_20260817.json` — per-file SHA-256 of the mirror
- `farmctl.py:20256-20266` (requeue rename), `prune_workitem_logs.py` (scope), `reports_log_purge.ps1:49-54`
