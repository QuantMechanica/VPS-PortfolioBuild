# Codex brief — runner + decorrelated satellites, with Q09 binding BEFORE the build

Date: 2026-07-27
Priority: high. OWNER set this architecture directly.

## OWNER's principle

> "Der Weg wäre ja eigentlich einen Runner (zB USDJPY Breakout) zu haben und dann 2 oder
> 3 unkorrelierte Sleeves dazu um das DD Risiko zu reduzieren, da wird dann Q09 natürlich
> relevant. Weil in so einem gesamt EA sollten natürlich keine EA Kopien sondern
> unkorrelierte Sleeves drin sein! Das Q09 Gate gehört also binded, bevor wir den
> nächsten Gesamt EA bauen."

One **runner** supplying drift, plus two or three **decorrelated satellites** whose job
is to cut drawdown depth — not to add return. And Q09's correlation criteria must gate
membership **before** a combined EA is built, not discover the problem afterwards.

## Why this is the right shape, quantitatively

The factory's screening metric is

```
FUND_SCORE = med60_1x / max( 2.0 , 2*|wDay_1x| , wDD_p90_1x )   >= 1.0
```

(`docs/ops/evidence/2026-07-27_sleeve_improvement_targets.md`). For **every**
drift-carrying sleeve in the pool the binding denominator term is `wDD_p90` — the depth
of the 60-day drawdown — not the single worst day. The pool maximum is 0.41 (9936, with
med60 3.34% against wDD_p90 8.18%).

A runner raises the numerator. Genuinely decorrelated satellites lower the denominator,
because uncorrelated P&L streams add in quadrature rather than linearly. So OWNER's
architecture is precisely the lever the metric points at.

## A correction you must factor in

An earlier measurement in `tools/strategy_farm/portfolio/challenge_single_account.py`
concluded that running several sleeves on one account was **indistinguishable** from
running one. **That test cannot have shown a diversification benefit**, because the
sleeves it combined were 9936 and 13213 — measured at **r = 0.905 with 269 bit-identical
trades** (`docs/ops/evidence/2026-07-27_joint_vs_python_model_validation.md`). It
combined the same bet with itself. Treat that result as uninformative about genuinely
decorrelated members, not as evidence against diversification.

## What to build

A **book composer** that selects members under Q09's own rules, before anything is built.

1. **Use Q09's in-force thresholds, not invented ones.** Read them from the gate's code
   and cite `file:line`. Do not hardcode a number from memory or from a decision
   document without confirming it is what the gate currently applies.
2. **Compute pairwise correlation the way Q09 computes it.** The candidate pool is the
   gate-clean sleeves with `entry_time` coverage. Correlate daily P&L from the existing
   Q08 streams — no new backtests. If Q09 uses a different basis (full-history versus
   overlapping window; the `corr_full` suffix in its reasons suggests at least two),
   match it and say which.
3. **Compose**: one runner (the highest `med60` sleeve that is dormancy-safe, currently
   9936:USDJPY at max inter-trade gap 27 days) plus 2-3 satellites selected for
   decorrelation and non-negative drift. Satellites are chosen to cut `wDD_p90`, **not**
   to add return — make that explicit in the selection criterion.
4. **Emit every member set that would PASS Q09**, ranked. If none exists, say so plainly:
   that would mean the pool has no genuine diversity, and the sourcing brief must target
   decorrelation rather than smoothness.

## The test of the whole idea

For each candidate member set, compute the combined `med60`, `|wDay|`, `wDD_p90` and
**FUND_SCORE** on one shared account, and compare against the runner alone.

**Does adding decorrelated satellites actually lift FUND_SCORE toward 1.0?** That is the
question this task exists to answer. Reuse the machinery in
`tools/strategy_farm/portfolio/challenge_book_60d.py` — it already handles the
pessimistic multi-day bound, `entry_time` as a precondition, calendar deadlines, the
30-day dormancy rule and the four-trading-day minimum. Do not reimplement it.

Method requirements, non-negotiable:

- Choose every parameter — membership, risk split, thresholds — **in-sample only**, on
  the first 60% of the calendar. Report out-of-sample separately. If OOS materially
  exceeds IS, say so; that is evidence against a leak.
- Count censored starts as failures and report them separately.
- Give an honest effective sample size. Overlapping starts are heavily autocorrelated.
- **A satellite that lowers combined FUND_SCORE must be reported as such.** Diversifying
  a fixed risk budget across more sleeves dilutes drift per unit of risk; whether the
  drawdown reduction outweighs it is an empirical question with a real chance of coming
  out negative. Do not assume the architecture works — measure it.

## What NOT to do

- Do not weaken, tune or bypass Q09 to admit a set. If nothing passes, that is the answer.
- Do not build a combined EA. This task selects members and measures whether the shape
  works. Building comes after, and only if the numbers support it.
- Do not re-run Q09 or queue backtests. Everything here is computable from existing Q08
  streams.

## Constraints

- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`; do not interrupt backtests; T5 is
  disabled and T9 is reserved; never `C:/QM/mt5/T_Live`.
- Commit with explicit pathspecs. Evidence over claims: `file:line` or a query for every
  number.

## Deliverable

`docs/ops/evidence/2026-07-27_runner_satellite_composition.md` plus the composer script.
Include Q09's actual thresholds with citations, the pairwise correlation matrix over the
gate-clean pool, every passing member set ranked, and the FUND_SCORE of each against the
runner alone — including any that came out worse.
