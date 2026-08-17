# Point 2.2 — the candidate pool union is 91 pairs, and "up to 118 density returners" is 11

v6 §9 names one remaining measurement before any candidate number goes into a Vorlage: the
**union** of the three populations, measured rather than added. This is that measurement.

**Answer: 91 pairs.** The naive sum is 114, so adding overstates by **23 pairs (20%)**. And one of
the three inputs is wrong by an order of magnitude in the other direction.

## The three populations, as distinct (EA, symbol) pairs

| | population | measured | v6 §E1/E6 says |
|---|---|---:|---:|
| A | Q10 survivors | **34** | 34 ✓ |
| B | FAIL_PORTFOLIO returners | **69** | 66 |
| C | density returners under E6 | **11** | "up to 118" |
| | naive sum | 114 | "über 100" |
| | **union** | **91** | — |

Overlaps: A∩B **15**, A∩C **5**, B∩C **4**, A∩B∩C **1**.

**A∩B = 15 is the headline overlap:** 15 of the returning FAIL_PORTFOLIO pairs were never outside
the pool — they are already Q10 survivors. The FAIL_PORTFOLIO verdict at Q09_PORTFOLIO and the PASS
at Q10 coexist on the same pair, exactly as E1 predicts they should once marginal contribution stops
being the selection criterion.

**Unit check first**, because the brief mixes "Paare" and "Sleeves": `challenge_book_60d.py:158`
keys a sleeve as `f"{bare_ea}:{symbol_without_.DWX}"` — one sleeve **is** one (EA, symbol) pair. The
union is well-defined. Note that the row counts differ from the pair counts and are the wrong unit:
Q10 PASS is 40 rows / 34 pairs, FAIL_PORTFOLIO is 72 rows / 69 pairs.

## Why C is 11 and not 118 — the 118 is not a density population

The 118 is real: it is the `challenge_engine_ineligible` count in
`D:\QM\strategy_farm\artifacts\portfolio\fund_scores.json` (216 rows: 118 ineligible, 78
`entry_time_incomplete`, 20 `SCORED`). But that label conflates two different exclusions, and only
one of them is what E6 relaxes.

Reproducing `challenge_book_60d.py`'s filter chain over all 216 sleeve streams:

| | sleeves | does E6 return them? |
|---|---:|---|
| gate-blocked — a Q02..Q08 verdict outside the accept sets | **138** | **no** — these failed gates |
| coverage-blocked — entry_time on <99% of trades | 12 | no — waits on 2.3 |
| admitted today (≥250 close days) | 20 | already in |
| blocked by `MIN_DAYS` only, density ≥ 4.0/60d | **11** | **yes** |
| blocked by `MIN_DAYS` only, density < 4.0/60d | 35 | no — fails the new measure too |

**72 of the 118 are gate failures**, dominated by **96 occurrences of `Q08 FAIL_HARD`**. Removing
`MIN_DAYS` cannot return them; they would have to re-pass a gate. Of the 46 that are genuinely
`MIN_DAYS`-blocked, only 11 clear 4.0 active days per 60 — the rest are excluded by the *new*
measure as well.

So E6's stated effect — "bis zu 118 Sleeves kehren zurück" — is **11**. The reasoning behind E6 is
untouched by this: a 60-day KPI should be gated on density in the window, not on history length.
Only the expected yield changes.

## Controls

- **positive** — all **20 of 20** `SCORED` sleeves in `fund_scores.json` land in my `admitted`
  bucket, and my admitted count *is* 20. The filter chain is reproduced faithfully.
- **positive (v6 2.4 asked for one row; all 20 hold)** — every admitted sleeve still clears
  4.0 active days/60d, so the new measure demotes nobody.
- **negative** — 0 gate-blocked or coverage-blocked sleeves appear among the returners.
- **independent triangulation of 78** — my stream-derived coverage-blocked count, the
  `entry_time_incomplete` count in `fund_scores.json`, and v6 2.3's "78 Zeilen mit
  `entry_time_records: 0`" are the same 78, derived three separate ways. All 78 have
  `entry_time_records == 0` exactly — none is partially covered.

## The blocker this uncovered: E6's metric has a consumer and no producer

`build_book_ftmo.py:167` reads `scores[key]["active_days_per_60d"]` and `:183` gates on it.

**No row in `fund_scores.json` carries that key — 0 of 216.** The row schema is
`sleeve, status, reason, records, entry_time_records` and, for the 20 scored,
`fund_score, med60_1x, worst_day_1x, wdd_p90_1x, denominator, screening_only`. Nothing in `tools/`
writes `active_days_per_60d` either.

Consequence: `_density()` puts every sleeve in `missing`, so `density_evidence_complete` is False
and `each_sleeve_active_days_per_60d` is False on an empty list — `density.passed` is **False**, and
with it the whole FTMO manifest check. **2.4 is not a constant swap; the producer has to be
written.** That is a small, well-scoped job, but it is on the critical path into 3.4 and it is not
what the brief assumes.

**Therefore the 11 is provisional in a specific way:** because no canonical producer exists, I
derived density as `60 × distinct_active_days / span_days`, counting both entry and close days.
That is a defensible reading of "active days per 60d" but it is *mine*. A producer that measures in
a rolling 60-day window, or over trading days rather than calendar days, will move the 11. **The
number to carry forward is the method, not the 11** — and the method should come from the producer
2.4 has to write anyway.

## Two smaller corrections to the brief

- **B is 69, not 66.** Three additional FAIL_PORTFOLIO pairs exist versus the figure in the brief.
- **The scored population is 20, not 21.** v6 2.4 says "eine der 21 heute bewerteten Zeilen";
  `fund_scores.json` has 20 `SCORED`.

## My own errors in this measurement

Three, all caught by controls rather than by inspection:

1. **First pass omitted the gate filter entirely**, reporting 41 admitted and 25 returners. The
   real numbers are 20 and 11. `challenge_book_60d.py:123-128` rejects a sleeve on its Q02–Q08
   verdicts *before* opening the stream; I went straight to the stream.
2. **Second pass dropped `parse_ts`'s numeric branch**, so every stream read as empty and the whole
   classification collapsed to zeros. `time` is an epoch integer (`1512685002`), not a string.
3. **A registry check keyed `QM5_30001` against a file that keys `30001`**, reporting 0 rows for an
   allocation that was in fact complete (see the f24e9f6d review).

Three zero-or-absurd results in one round, each from re-deriving something that already existed.
The rule held every time: the zero was mine, not the data's.

## What this changes downstream

- **2.2's screening set is 91 pairs**, not "über 100". The pool did grow — from 34 to 91, a 2.7×
  increase — which is the substance of E1, and it is enough to make "how many candidates does 80%
  need" a real question.
- **2.4 acquires a build task** (write the `active_days_per_60d` producer) before it can be a
  gate change.
- **2.3 is confirmed as the larger lever than E6**: 12 gate-clean sleeves wait only on entry_time,
  and the other 66 entry-time-incomplete sleeves are gate-blocked anyway. Fixing 2.3 alone adds 12.

## Evidence

- `artifacts/pool_union_20260817.json` — schema `qm.pool-union-2p2/v2`, full member lists
- `tools/strategy_farm/portfolio/challenge_book_60d.py:83` (`MIN_DAYS`), `:120-128` (gate filter),
  `:158-161` (coverage + MIN_DAYS), `:259` (pool print)
- `tools/strategy_farm/portfolio/build_book_ftmo.py:160-195` (`_density`), `:256`
  (`min_active_days_per_60d=4.0`)
- `D:\QM\strategy_farm\artifacts\portfolio\fund_scores.json` — 216 rows, 0 with
  `active_days_per_60d`
- `work_items` — Q10 PASS 40 rows/34 pairs; Q09_PORTFOLIO FAIL_PORTFOLIO 72 rows/69 pairs
