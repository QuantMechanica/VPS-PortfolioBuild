# BUILD-2 — The entry-timestamp gap is real but secondary; the binding constraint is a 250-trading-day density requirement

## The chain, traced to the actual filter

`fund_score.py` does **not** compute scores from trade streams. It imports
`sleeve_improvement_targets`, which imports `challenge_book_60d`, and takes whatever that module's
`keys` contains. For sleeves *absent* from `keys` it invents a diagnostic label by inspecting the
stream itself:

```python
"reason": "entry_time_incomplete" if n and covered < n else "challenge_engine_ineligible"
```

So both labels are **symptoms of an upstream exclusion**, not causes computed by the scorer. Also
worth stating plainly: `sleeve_improvement_targets.py` is a research script that prints ranked
tables, and `fund_score.py` imports it with `contextlib.redirect_stdout` to swallow the printing.
The FTMO bar's scoring input is a table-printing analysis script.

The real gate is `challenge_book_60d.py:158-161`:

```python
# span must be known: a missing entry_time is unknown exposure, not zero.
if not n or cov < 0.99 * n:                     continue    # <- criterion 1
if len({c for _, c, _, _ in ev}) < MIN_DAYS:    continue    # <- criterion 2
```

with `MIN_DAYS, MIN_TRADING_DAYS, DORMANCY_DAYS = 250, 4, 30`.

## Two different exclusions, and I had conflated them

| Bucket | count | fails | fixable by repairing data? |
|---|---:|---|---|
| `entry_time_incomplete` | **78** | criterion 1 — under 99 % entry-time coverage | **yes**, in principle |
| `challenge_engine_ineligible` | **118** | criterion 2 — **fewer than 250 distinct trading days** | **no** — it is a density fact |
| `SCORED` | **20** | — | — |

(Counts drift by one or two between reads because the cache is being regenerated live; unit is
sleeves, and the split is what matters, not the last digit.)

The 118 have **complete** timestamps — earlier samples show `records: 513, entry_time_records: 513`
— and are excluded anyway. They simply do not trade on enough distinct days.

### The correction to my own number

Last round I wrote that closing the entry-time gap "would take the scorable pool from 21 to
potentially 99". **That was the ceiling, and it assumed all 78 would then clear the density gate.**
Given that 118 sleeves *with* complete timestamps already fail that gate, the prior is that many of
the 78 will fail it too. The honest statement: repairing timestamps makes 78 sleeves *evaluable*;
how many become *scorable* is unknown and plausibly a minority.

## Why the filter is right, not a bug

The comment at criterion 1 is correct and worth preserving verbatim: *"a missing entry_time is
unknown exposure, not zero."* This is exactly the point the brief raises about intraday risk. FTMO
measures daily loss against the balance at the Prague-midnight anchor and **includes open
positions**; a trade whose entry time is unknown has an unknown holding span, so its contribution to
any given day's exposure cannot be computed. Treating it as zero would understate the risk
systematically — the failure mode the brief names.

So criterion 1 must **not** be relaxed to get more sleeves scored. The data has to be fixed, or the
sleeve stays out.

## What this means for the FTMO book, concretely

The binding constraint on FTMO candidacy is **trading density over a long history**, not the
tolerance scale and not the timestamps:

- A sleeve needs **≥ 250 distinct trading days** merely to be *evaluated*.
- It then needs `FUND_SCORE ≥ 1.0`, i.e. `med60 ≥ wdd_p90`, where the best of the 20 scorable
  sleeves reaches **0.4085** — a 2.45× gap.
- And the cost snapshot covers **3 symbols**, so the book is one sleeve per each.

Three independent constraints, and density is the one nobody had named. It also explains the
manifest's density contract (`minimum_active_days_per_sleeve_per_60d: 4.0`,
`minimum_trading_days_phase1: 4`) — that is the *per-window* version of the same requirement.

**This is the answer BUILD-6 needs before it can be parameterised.** "How many candidates for
P(pass) ≥ 80 %" is unanswerable while the candidate *filter* is a 250-day density gate that most of
the inventory cannot clear. Low-frequency strategies — which the Q02 frequency floor of 5 trades/yr
explicitly admits — are structurally excluded from an FTMO Phase-1 book by this gate.

That is a strategic finding, not an implementation detail: **the DZ book and the FTMO book need
different kinds of sleeve**, and the current funnel is not selecting for FTMO density anywhere.

## What I did not do

- **Did not relax criterion 1.** It is protecting against exactly the intraday understatement the
  brief warns about.
- **Did not touch `MIN_DAYS`.** 250 may be too strict for a 60-day challenge — a sleeve needs
  density *within the window*, not 250 days of history — but that is a modelling decision with a
  direct effect on which candidates exist, and it belongs to OWNER. **Naming it is the deliverable;
  changing it is not mine.**
- **Did not investigate the 78 streams' provenance yet.** Where the timestamps are lost (tester
  output, parser, or aggregation) is the next step, and the positive control is one of the 20
  sleeves that has them.

## The question this raises for OWNER

`MIN_DAYS = 250` is a *history-length* proxy standing in for *window density*. For a 60-day Phase 1
the relevant property is trades-per-60-days, which the manifest already encodes as
`minimum_active_days_per_sleeve_per_60d: 4.0`. If the 250-day gate is a legacy of the funded-account
analysis this script was written for, it may be excluding sleeves that would be perfectly adequate
for Phase 1 — and that would change the candidate count materially, which is precisely the number
BUILD-6 is meant to produce.

## Evidence

- `tools/strategy_farm/portfolio/fund_score.py:26-60` — the label-inventing path
- `tools/strategy_farm/portfolio/sleeve_improvement_targets.py:29,36,177-192` — the imported table script
- `tools/strategy_farm/portfolio/challenge_book_60d.py:74,83,130-166` — `STREAMS`, `MIN_DAYS=250`, both criteria
- `D:\QM\strategy_farm\artifacts\portfolio\fund_scores.json` — 78 / 118 / 20 split
- related: `2026-08-17_P2_what_the_two_books_actually_need.md` (the number corrected here)
