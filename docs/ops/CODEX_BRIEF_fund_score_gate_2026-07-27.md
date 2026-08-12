# Codex brief — make FUND_SCORE a first-class factory metric

Date: 2026-07-27
Priority: high. This turns today's research finding into standing factory capability.

## What FUND_SCORE is

Derived in `docs/ops/evidence/2026-07-27_sleeve_improvement_targets.md` and implemented
in `tools/strategy_farm/portfolio/sleeve_improvement_targets.py`. It reduces OWNER's
FTMO requirement to one inequality computable from any existing Q08 trade stream, with
**no new backtest**:

```
FUND_SCORE = med60_1x / max( 2.0 , 2*|wDay_1x| , wDD_p90_1x )   >= 1.0
```

at the sleeve's native ~1%/trade sizing, where:

- `med60_1x` = median rolling 60-calendar-day summed net / account (the sprint drift)
- `|wDay_1x|` = magnitude of the worst single day's summed net / account
- `wDD_p90_1x` = 90th-percentile peak-to-trough drawdown *inside* a 60-day window

Plain reading: **the median 60-day gain must be at least as large as the 90th-percentile
60-day drawdown.** The denominator term that is largest tells you which lever to pull.

Empirically the numerator is the discriminator: Spearman rho of `med60` against measured
P(funded) is **+0.88** across 15 sleeves; trades/yr is only +0.59.

Current pool maximum is **0.41** (9936:USDJPY, 3.34 vs 8.18). Nothing reaches 1.0.

## What to build

1. **A reusable scorer.** Extract FUND_SCORE from the one-off reporting script into a
   proper module so other tools can import it. Do not duplicate the maths; the existing
   engine in `tools/strategy_farm/portfolio/challenge_book_60d.py` already handles the
   pessimistic multi-day bound, entry_time coverage as a precondition, calendar
   deadlines and the dormancy rule. Reuse, do not reimplement.
2. **A farmctl surface**, following the existing `ea-metrics` pattern, so FUND_SCORE can
   be queried per (ea_id, symbol) without hand-writing SQL.
3. **Automatic scoring.** Every sleeve with a Q08 trade stream should get a FUND_SCORE
   without anyone asking. Decide where that belongs — a Q08 post-step, an aggregator, or
   a scheduled scorer — and justify the choice against how the factory already works.
   State what happens to sleeves whose stream lacks `entry_time` (currently 70 of 189):
   they must be reported as UNSCORABLE, never silently as 0.
4. **Dashboard exposure.** Surface it where sleeve quality is already shown
   (`tools/strategy_farm/dashboards/render_dashboards.py`, and the cockpit if
   appropriate). Follow the STEEL/EMERALD dark-v2 brand and the rule that operator
   surfaces show only **Qxx** phase labels, never raw `P*` keys.

## Guard rails on the metric itself

- FUND_SCORE is a **screening** metric, not a verdict. It must never override a gate
  verdict or admit a sleeve that failed Q02-Q10. Make that structurally impossible.
- It is computed on historical streams and inherits their period. Do not present it as
  a forward guarantee.
- Report the three components alongside the score. A single number without `med60`,
  `|wDay|` and `wDD_p90` hides which lever to pull, which is the metric's main use.

## Constraints

- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`; do not interrupt backtests; never
  touch `C:/QM/mt5/T_Live`.
- Read-only against the farm DB except where the design requires writing scores; if it
  writes, say exactly what and where.
- Commit with explicit pathspecs. Evidence over claims.

## Deliverable

The module, the farmctl surface, the dashboard change, and
`docs/ops/evidence/2026-07-27_fund_score_gate.md` with the full scored table for every
sleeve that has a stream, including the UNSCORABLE ones and why.
