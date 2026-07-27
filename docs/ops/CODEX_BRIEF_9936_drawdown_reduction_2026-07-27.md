# Codex brief — cut 9936's 60-day drawdown depth without cutting its win side

Date: 2026-07-27
Priority: high. This is the single highest-leverage strategy change available.

## The target, quantified

`docs/ops/evidence/2026-07-27_sleeve_improvement_targets.md` reduced OWNER's FTMO
requirement to one screening number:

```
FUND_SCORE = med60_1x / max( 2.0 , 2*|wDay_1x| , wDD_p90_1x )   >= 1.0
```

`9936:USDJPY` is the lead sleeve and the pool maximum at **0.41**:

| component | current @1x | needed |
|---|---:|---|
| `med60` median 60-day gain | **3.34%** | hold it |
| `wDD_p90` p90 60-day drawdown | **8.18%** | **<= ~3.3%** |
| `\|wDay\|` worst day | **1.76%** | <= ~1.6% |

The binding term is `wDD_p90` for every drift-carrying sleeve in the pool — the
loss-streak depth, not the single-day loss. Plainly: **the drawdown 9936 must survive is
about 2.4x the gain it produces, and that ratio has to flip.**

Halving `wDD_p90` while holding `med60` lifts FUND_SCORE from 0.41 to roughly 1.0, which
is the difference between a sleeve that cannot pass a challenge and one that can.

Note what is NOT wanted: 9936 already has the required per-trade expectancy
(0.131% of account at 1x, against a derived requirement of ~0.13%). **This is not a
search for more edge. It is a search for the same edge delivered more smoothly.**

## Why 9936 specifically

- Best measured single-account result: 4.0% at 1x rising to 35.7% at 3x on the
  60/30 KPI, out-of-sample.
- Intraday-flat (0% multi-day), so it is clean for every FTMO phase including the
  Standard funded weekend-flat rule.
- Max inter-trade gap 27 days, inside the fixed 30-day dormancy limit — most of the pool
  is not.
- EA: `framework/EAs/QM5_9936_ff-range-breakout-gmt3-h1/`.

## What to do

1. **Diagnose the drawdown, do not guess at it.** Using the existing Q08 stream
   (`D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/9936_USDJPY_DWX.jsonl`),
   characterise the losing streaks that produce the p90 60-day drawdown. Are they
   clustered in time, in a session, in a volatility regime, after a particular signal
   condition, or on a particular weekday? Give the discriminating statistic, not a
   narrative.
2. **Propose parameter directions grounded in that diagnosis.** Read `SPEC.md` and the
   EA source to know which parameters exist. For each proposal state the mechanism by
   which it should cut `wDD_p90` and its expected cost to `med60`. Label anything
   speculative as SPECULATIVE.
3. **Respect the gates.** 9936 currently holds gate evidence. Any parameter change
   creates a NEW sleeve variant that must earn its own evidence — it does not inherit
   9936's. Name the variant properly and say which gates it must re-run.
4. **Do NOT queue backtests yourself.** Produce the ranked candidate list with the
   diagnosis behind each. Tester capacity is the factory's primary throughput metric and
   queueing is a capacity decision. A joint-backtest workflow is currently occupying
   terminals.
5. Beware the obvious trap: a filter that removes losing streaks in-sample is usually
   curve-fitting. For every proposal, say what would distinguish a real regime effect
   from a fitted one, and what out-of-sample test would settle it.

## Constraints

- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`; do not interrupt running backtests;
  never touch `C:/QM/mt5/T_Live`.
- Do not modify `framework/EAs/QM5_9936_...` in place. It holds gate evidence.
- Do not invent commission, swap or DST values.
- Commit with explicit pathspecs. Evidence over claims.

## Deliverable

`docs/ops/evidence/2026-07-27_9936_drawdown_diagnosis.md`: the streak diagnosis with
its discriminating statistic, the ranked parameter proposals with expected effect on
each FUND_SCORE component, the gate re-run requirement per variant, and the
overfitting test for each.
