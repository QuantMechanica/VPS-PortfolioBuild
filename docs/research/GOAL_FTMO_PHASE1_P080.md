# Goal: win FTMO Challenge Phase 1 within 30 days, P(pass) ≥ 0.80

Status: ACTIVE · set by OWNER 2026-07-26 (supersedes the demo-book goal) · execution: Claude

## The goal, stated so completion is checkable

A book that, simulated under the exact FTMO Phase-1 contract — +10 % target, 5 % daily loss
limit, 10 % total loss limit, real FTMO costs including swap — reaches the target inside
30 calendar days (~22 sessions) in **at least 80 % of runs**, with the pass probability
measured by `ftmo_p1_mc.py` / `ftmo_bar_joint_book_sim.py` over the deployed composition,
not over a research proxy.

This supersedes the demo-book goal. A demo could be justified as falsification; this cannot
— it is a money gate, and the number has to be earned before the account is bought.

## What tonight's measurements say about reachability

Two independent calculations, both from live evidence rather than assumption.

**1. Per-session arithmetic.** The target is +10,000 on 100k in ~22 sessions = **455 per
session**. Our best FTMO-shaped sleeve, QM5_13036 GDAXI (1,352 trades, exactly one held
overnight, Q08 PASS), books net +3,433 over ~7.5 years at gate sizing:

| | |
|---|---|
| per trade | 2.54 |
| per year | 458 |
| **per session** | **1.82** |
| sessions to +10 % alone | 5,505 (≈22 years) |

Scaling is bounded by the loss cap: at 8.1 % measured drawdown, planning to use 60 % of the
10 % cap allows only **0.74×**. Diversification is what buys scale — N uncorrelated sleeves
give book drawdown ≈ d·√N/N, so the cap binds less per sleeve:

| sleeves | book DD | permitted scale | per session | sessions to target |
|---:|---:|---:|---:|---:|
| 5 | 3.6 % | 1.66× | 15 | 665 |
| 10 | 2.6 % | 2.34× | 43 | 235 |
| 20 | 1.8 % | 3.31× | 120 | 83 |
| 40 | 1.3 % | 4.68× | 340 | **29** |

Even **40 uncorrelated sleeves of 13036's quality** land at 29 sessions against 22 required
— and that assumes perfect independence, which does not exist.

**2. Speed metric.** Return per unit of drawdown per unit of time is what a capped,
time-boxed challenge rewards:

    speed = (account-% per year) / drawdown-%

A +10 % run inside 22 sessions is ≈114 %/yr; at a book drawdown the cap tolerates (~6 %) the
**book** needs speed ≈19. Measured across sleeves where both net and drawdown exist:

| EA | symbol | PF | trades | DD % | net | %/yr | speed |
|---|---|---:|---:|---:|---:|---:|---:|
| 10919 | XTIUSD | 4.84 | 30 | 1.9 | 6,666 | 0.89 | **0.48** |
| 10939 | GBPUSD | 1.65 | 82 | 6.2 | 19,110 | 2.55 | 0.41 |
| 12567 | XAUUSD | 1.72 | 72 | 2.4 | 5,038 | 0.67 | 0.28 |
| 12989 | XAUUSD | 1.72 | 51 | 6.5 | 13,557 | 1.81 | 0.28 |

Best individual speed **0.48** against a book requirement of **19**. At √N scaling that is
over a thousand sleeves.

The two calculations disagree on the exact number — 40 versus ~1,500 — because they make
different assumptions about sizing headroom. They agree on the thing that matters: **we are
one to two orders of magnitude short, not twenty percent short.**

## What this means, plainly

**P(pass) ≥ 0.80 in 30 days is not reachable by stacking strategies of the quality we
currently own.** Our sleeves are slow: PF 1.04–1.7 with drawdowns of 2–8 %, earning
0.7–2.6 account-% per year. A challenge needs ~114 %/yr equivalent. No amount of
qualification work, evidence repair or portfolio assembly closes a gap of that size — those
activities make existing edge *usable*, they do not create edge.

This is not an argument against the goal. It is a statement about which lever moves it.

## The only levers that can move it

1. **Strategies with fundamentally higher edge per unit of risk.** Not more strategies — 
   *better* ones. A sleeve at speed 5 does more for this goal than fifty at speed 0.5.
   Everything in the current pool is an order of magnitude below what is needed.
2. **Leverage/sizing structure that the cap permits.** The 10 % total cap is the binding
   constraint on scale. A genuinely uncorrelated book of many small-drawdown sleeves is the
   only structural way to buy scale, and it needs both the count and the independence — our
   pool is concentrated in gold and indices.
3. **A different time box.** FTMO Phase 1 has no time limit in the current rules; the 30 days
   are self-imposed. At an unlimited horizon the same book that fails at 30 days may pass —
   slowly. Whether that is acceptable is an OWNER decision, and it changes the goal rather
   than the work.

## Recommendation

State the honest position first: **do not buy a challenge account against the current book.**
The measured pass probability of the best composition we can assemble today is in the low
teens at sizings that carry 60 % daily-breach risk — that is not a challenge attempt, it is
a coin flip with a fee.

The work that actually serves this goal, in order:

1. **Measure the speed of every candidate, not the density.** Tonight's census found seven
   swap-immune sleeves, which is a real correction to the "motor-dry" doctrine — but density
   without edge does not pass a challenge. The same census must now rank by speed.
2. **Source for edge quality, not trade count.** The sourcing spec has been "≥250 trades/yr,
   intraday-flat". It should be "speed ≥ 5", which is a far harder and far more useful filter.
3. **Keep the qualification machinery running** — it is now proven end to end and will be
   needed the moment a fast sleeve exists — but stop treating `challenge_ready` count as
   progress toward *this* goal. It is progress toward deployability, not toward 80 %.

## Caveats on these numbers

The net figures are booked at each gate's own risk sizing, and pairing net (Q08) with
drawdown (Q10/Q05) across gates is approximate. The √N diversification assumption is
idealised. Any of these could move the estimate by a factor of two or three. None of them
move it by the one-to-two orders of magnitude that separate the current pool from the target.
