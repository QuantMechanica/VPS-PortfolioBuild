# v10 §7.2 — co-exceedance measured: the sizing multiplier is ≈0.44×, and §7.8 — the two zero-trade classes are disjoint

Two numbered points in one round because the second is a five-minute definition and the first needed
the room.

---

# §7.2 · Co-exceedance, the term the FTMO daily budget was missing

v10 §1 decomposed the worst book day into four terms and named the missing one: *at how many days do
how many sleeves lose together?* Measured over the 20 sleeves that carry a daily series and the
**2,114 trading dates** they span (2017-10-09 … 2025-12-30):

## How many sleeves lose on the same day

| simultaneous losers | days |
|---:|---:|
| 1 | 377 |
| 2 | 443 |
| 3 | 429 |
| 4 | 294 |
| 5 | 181 |
| 6 | 98 |
| 7 | 58 |
| 8 | 28 |
| 9 | 15 |
| 10 | 9 |
| 11 | 3 |
| **12** | **1** |

Deep co-exceedance is rare but real: 13 days had ten or more of twenty sleeves losing at once.

## The discount, and it is large

| | % of account, 1× sizing |
|---|---:|
| sum of each sleeve's **own** worst day | **−32.33** |
| **actual worst joint day** | **−6.86** |
| ratio | **0.21×** |

**The naive sum overstates the real worst day by 4.7×.** That is precisely why the per-sleeve share
table in the previous round read "no FTMO book is constructible" — it was applying a bound almost
five times too pessimistic. The rule *der schlechteste Tag eines Buchs ist nicht die Summe der
schlechtesten Tage seiner Teile* now has its coefficient.

## The number that actually decides the sizing multiplier

The worst joint day of the full 20-sleeve book at 1× sizing is **−6.86 %**, against FTMO's **5 %**
daily barrier. **At 1× this book breaches.** And not marginally — the eight worst days are:

| date | net across sleeves | simultaneous losers |
|---|---:|---:|
| 2023-02-03 | **−6.86 %** | **11** |
| 2020-09-08 | −6.46 % | 7 |
| 2023-01-25 | −6.10 % | 7 |
| 2023-05-24 | −5.76 % | 7 |
| 2022-10-11 | −5.70 % | 6 |
| 2021-11-24 | −5.70 % | 9 |
| 2019-09-27 | −5.69 % | 8 |
| 2021-05-12 | −5.48 % | 6 |

Eight days over the 5 % barrier in eight years, at 1×. So the multiplier follows directly:

```
to hold the worst joint day under the 3.0 % working limit :  ≤ 3.0 / 6.86 = 0.44×
to hold it under the hard 5.0 % barrier                   :  ≤ 5.0 / 6.86 = 0.73×
```

**v10 §1(b) predicted the direction — "die Risikoachse läuft nach unten" — and this puts a number on
it: ≈0.44× for the full 20-sleeve book at the working limit.** With `RISK_FIXED = 1000` on a 100k
account being 1.00 % per trade, 0.44× is **0.44 % per trade**, which sits just above the audit's
pre-registered expectation of 0.20–0.30 % and is therefore consistent with it rather than in tension.

## What this licenses and what it does not

**Licenses:** 3.3's risk axis is now bounded from a measurement rather than assumed, and 3.2 gains a
concrete objective — a book whose members do *not* co-exceed tolerates a larger multiplier, so
composition buys risk budget directly. That is the sense in which v10 §1(b) makes 3.2 more important
and 3.3 smaller.

**Does not license a threshold yet**, for two stated reasons:

1. **This is realised daily P&L keyed by close date, not the intraday equity path.** FTMO measures
   against balance at day start *including floating positions*. The true daily excursion is therefore
   **at least** this large and probably larger. −6.86 % is a lower bound on the worst day, so 0.44×
   is an upper bound on the admissible multiplier.
2. **20 of 216 sleeves**, the ones carrying `entry_time`. Non-random, and v10 §7.7 already requires
   the repeat after 2.3.

Both point the same way — the real constraint is tighter than measured here, not looser.

## Method note

Per-sleeve daily P&L was built from `challenge_book_60d.sleeves[k]`, summing each trade's net onto
its **close date** and dividing by `ACCOUNT = 100_000`. The "losing side" column separates the sum of
negative sleeve-days from the net, so a day where winners partly offset losers is visible as such;
the two differ by at most 0.96 pp on the worst eight days, so offsetting is not carrying the result.

---

# §7.8 · The two zero-trade classes at Q08 are disjoint — but their pair populations overlap

v10 asked whether `q08_zero_trade_baseline` and `q08_degenerate_neighborhood_baseline` are two
classes or one with two labels, noting that if they were one, the open cluster would be larger than
5 of 51.

**They are two, and the code makes them mutually exclusive by construction:**

| | condition | where |
|---|---|---|
| `q08_zero_trade_baseline` | the **main** Q08 baseline reported `n_trades == 0` | `farmctl.py:4222` |
| `q08_degenerate_neighborhood_baseline` | Q08 aggregate returned `INFRA_RECYCLE`: the **Q08.5 neighborhood** baseline had 0 trades **while the main baseline traded** (`n_trades > 0`) | `farmctl.py:4281`, DL-082 §3a |

One requires the main baseline to have traded; the other requires it not to have. **Positive control:
0 work items carry both tokens.**

**But the pair populations are not disjoint:**

```
distinct pairs with zero_trade_baseline        : 7
distinct pairs with degenerate_neighborhood    : 9
pairs appearing in BOTH, at different times    : 2   (QM5_10440/NDX, QM5_11147/SP500)
```

So the answer is better than either option offered: two conditions with different causes and
different repairs — a main baseline that does not trade is a strategy or setfile problem; a
neighborhood that does not trade is a sweep-generation problem — **but counting the open cluster by
label undercounts the fragile-pair population.**

The right unit is *pairs with any zero-trade condition at Q08*: **7 + 9 − 2 = 14 pairs**, not the
5 batch rows the degenerate label alone shows. And QM5_11147/SP500 appearing in both reinforces it as
a rework candidate rather than an unlucky run.

## Evidence

- `challenge_book_60d.py` — `sleeves`, `ACCOUNT = 100_000`; 20 sleeves, 2,114 dates
- `farmctl.py:4132,4222` — zero-trade baseline path and its docstring; `:4281` — DL-082 §3a
- `work_items` payload token census, both tokens, 2026-08-18
- prior round: `docs/ops/evidence/2026-08-18_worst_day_is_a_trade_stacking_count.md`
