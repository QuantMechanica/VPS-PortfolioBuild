# P0 is lifted — `ea_metrics` *is* append-only, my finding was a query artefact, and the tolerance was inert

## The correction, first, because it unblocks 214 runs

P0 was made the gate for the entire catch-up on the strength of my claim that `ea_metrics`
overwrites superseded rows, and therefore that *"würde die 214-Läufe-Nachholaktion heute starten,
zerstörte sie ihre eigene Vergleichsbasis."*

**That claim is false.** `ea_metrics` is keyed on the work item, not on the pair:

```sql
CREATE TABLE ea_metrics (
    work_item_id    TEXT PRIMARY KEY,   -- <- one row per RUN, not per (ea, symbol, phase)
    ea_id TEXT, phase TEXT, symbol TEXT, verdict TEXT, ...
```

| | |
|---|---:|
| rows | **62,227** |
| distinct `work_item_id` | **62,227** |
| distinct `(ea_id, symbol, phase)` | 24,033 |
| rows on the busiest triple (`QM5_10042 / AUDUSD / Q03`) | **387** |

62,227 rows over 24,033 triples, with one triple carrying 387 rows: the table has been retaining
every superseded run all along.

**Where my error came from.** I queried `ea_metrics WHERE ea_id=?` and printed `rows[-3:]` ordered
by `extracted_at`. QM5_20289 has more than three metric rows, the three most recent happened to be
Q04, Q05 and the new Q02, and I concluded the old Q02 row was gone. It was never gone — it was
outside my own output window. Checked directly by id:

```
41d6f237  old Q02, 2026-08-12   trades=53  pf=0.71  source=summary_runs
c1a2de16  new Q02, 2026-08-17   trades=53  pf=0.71  source=summary_runs
```

**Consequence: P0 is not a blocker and the catch-up is not gated on it.** The append-only
requirement it asked for already exists, in both `work_items` and `ea_metrics`. I am reporting this
as prominently as I reported the finding, because a false blocker on 214 runs costs more than the
original mistake.

## What the 12 pending comparisons actually are

Twelve of the fifteen cohort pairs show no metrics row for their *new* work item. That is not loss
either — it is **extractor lag**. Extraction runs hourly on the hour:

```
14:00:09Z   43,166 rows   <- latest pass (a full sweep)
13:00       11 rows
12:00        6 rows
11:00       22 rows
```

Latest pass 14:00:09Z, current time 14:46Z. The twelve reruns finished inside that gap and get their
rows at 15:00. Nothing needs fixing; the comparison needs one hour.

## Z4 answered for the three pairs that are comparable — and the answer is *inert*

| Pair | old trades / PF / DD | new trades / PF / DD | |
|---|---|---|---|
| QM5_13203 / XTI_XNG basket | 67 / 0.94 / 3.29 | 67 / 0.94 / 3.29 | **identical** |
| QM5_13205 / XAU_XAG basket | 2 / 6.97 / 0.32 | 2 / 6.97 / 0.32 | **identical** |
| QM5_20289 / XTIUSD | 53 / 0.71 / 11.98 | 53 / 0.71 / 11.98 | **identical** |

Three for three, identical to stored precision, and no verdict changed. Neither is confounded —
QM5_21527 is the one pair whose `.ex5` was also rebuilt, and it is not among these three.

### What follows, and it is a negative result worth stating plainly

Identical **trade counts** mean the EA generated exactly the same trades with the tolerance at 0.1
as at 1e-12. So the input is not influencing signal generation at all — either it is unused on
these paths, or both values fall on the same side of every comparison it participates in.

**Strong prediction, recorded before the remaining twelve land:** the rest of the cohort will
reproduce its original verdicts exactly, and the Q04 comparison will be identical too. If that
holds, then:

> **The 15 EAs did not fail because the parameter was broken. They failed on merit, and the
> false-negative hypothesis is closed for this cohort.**

That is the opposite of what I hoped when I dispatched the requalification, and it is the more
valuable outcome: it removes 15 pairs from the "maybe rescuable" column, where they would otherwise
have sat indefinitely as an unresolved possibility. The generator fix remains correct and necessary
— it stops a real defect that killed QM5_41033 deterministically — but it is a correctness fix, not
a recovery lever.

I will confirm or retract the prediction next round when the twelve have metrics.

## One thing to hand to the PF-guard ticket

QM5_13205 sits in this cohort with **2 trades and PF 6.97**. That is a degenerate profit factor
inside the requalification set, and under the current one-sided low-frequency rule it would pass a
fold comparison unchallenged at Q04. It belongs in `1025125e`'s reclassification scope as a live
example rather than a hypothetical.

## Evidence

- `ea_metrics` DDL (`work_item_id TEXT PRIMARY KEY`), 62,227 rows / 24,033 triples / max 387 per triple
- `41d6f237` and `c1a2de16` fetched by id, both present with identical metrics
- extraction cadence: hourly on the hour, latest pass `2026-08-17T14:00:09Z`
- `artifacts/z4_exponent_old_vs_new_20260817.json` — the per-pair comparison, re-runnable
- corrects: the P0 premise in this round's brief, which came from my own review of `dc02ec96`
