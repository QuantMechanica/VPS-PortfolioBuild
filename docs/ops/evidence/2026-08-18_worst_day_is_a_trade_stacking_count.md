# v9 §7.2 first evaluation — `worst_day_1x` is a trade-stacking count, and that makes the FTMO daily budget decomposable

v9 §7.2 asks the question that can be answered without touching the framework: *how many of the pool
pairs already exceed a sensibly chosen daily share?* Answering it turned up something more useful
than the count.

## The distribution, over the 21 sleeves that carry the number today

| | % of account, 1× sizing |
|---|---:|
| min | 0.99 |
| p25 | 1.00 |
| median | 1.76 |
| p75 | 2.02 |
| max | **3.01** (9403:GDAXI) |

**Nine sleeves sit between 0.99 % and 1.04 %.** That is far too tight to be a distribution of worst
realised days. It is a floor, and the floor has a cause.

## The unit: `RISK_FIXED = 1000` on a `ACCOUNT = 100_000` engine is exactly 1.00 %

```
challenge_book_60d.py:75   ACCOUNT, DAILY_CAP, TOTAL_CAP = 100_000.0, 0.05, 0.10
framework/EAs/*/*.mq5      RISK_FIXED = 1000.0   in 3,699 of 3,722 EAs
```

So one stopped-out trade costs exactly 1.00 % at 1× sizing, and therefore

> **`worst_day_1x` ÷ 1.00 % = the number of losing trades the sleeve stacked into its worst day.**

Measured, and it comes out in clean integers:

| implied losing trades in the worst day | sleeves |
|---:|---:|
| 1 | **10** |
| 2 | **10** |
| 3 | **1** |

No sleeve stacks more than three. The tight cluster at 0.99–1.04 % is the ten sleeves that never lose
twice in a day — their worst day *is* one trade.

## Why this matters more than the raw threshold count

The naive admission question — "how many sleeves exceed a per-sleeve daily share?" — answers itself
badly:

| per-sleeve share at 1× | sleeves exceeding | implied book size at a 3.0 % working limit |
|---|---:|---:|
| 0.30 % | **21 / 21** | 10 sleeves |
| 0.50 % | 21 / 21 | 6 |
| 1.00 % | 14 / 21 | 3 |
| 2.00 % | 6 / 21 | 2 |

At 1× sizing **every** sleeve exceeds the share a 10-sleeve book would allow. Read naively that says
no FTMO book is constructible, which is wrong — and it is wrong in an instructive way. **The naive
share assumes every sleeve has its worst day on the same day.** That is the sum-of-worst-days upper
bound, not the portfolio's worst day.

With the stacking count the budget decomposes into quantities that are each separately measurable:

```
worst portfolio day  =  Σ over sleeves ( stacking_factor × per_trade_risk × sizing_multiplier )
                        evaluated on the worst CO-EXCEEDANCE day, not on the sum of separate days
```

- `stacking_factor` — **measured above**, 1–3, an integer per sleeve
- `per_trade_risk` — a rulepack setting, 1.00 % today, 0.20–0.30 % in the audit's recommendation
- `sizing_multiplier` — the free variable 3.3 and 3.4 solve for
- **co-exceedance** — the one term still missing, and it needs the 2.3 daily series

## The co-exceedance term is not hypothetical

The audit's own post-mortem records US100, GER40 and XAUUSD stopping out **on the same day** in trial
#2. That is the co-exceedance term with a real account loss attached. So the design question for
`Q11_TARGET` is not "which sleeves have a large worst day" — nearly all of them have 2 — but **which
sleeves have their large days together.**

That reframes the FTMO admission gate away from a per-sleeve threshold, which the table above shows
would reject everything or nothing depending on where the line is drawn, toward a **book-level**
criterion. It also confirms the ordering in the plan: P4 (same-day coupling) is the load-bearing
check, and P2 (per-sleeve daily-loss gate) is a cheap guard rail beneath it, not the main defence.

## What is deliberately not concluded

- **Coverage is 21 of 216 sleeves** — those with `entry_time`. That is a non-random slice, and v9 §7.7
  already requires repeating this once 2.3 delivers coverage. The integer structure of the stacking
  count is unlikely to change; the *distribution* across the full pool may.
- **No threshold is proposed here.** Per the standing rule, a limit needs a purpose and the purpose
  fixes the reference quantity. The reference quantity is the co-exceedance day, which is not yet
  measured, so proposing a per-sleeve number now would be picking a line before knowing what it is a
  line against.

## Evidence

- `D:\QM\strategy_farm\artifacts\portfolio\fund_scores.json` — `worst_day_1x` for 21 SCORED sleeves
- `tools/strategy_farm/portfolio/challenge_book_60d.py:75` — `ACCOUNT`, `DAILY_CAP`, `TOTAL_CAP`
- `RISK_FIXED = 1000.0` census across `framework/EAs/*/*.mq5` — 3,699 occurrences
- audit post-mortem, trial #2 same-day stop-outs, OWNER-supplied 2026-08-18
