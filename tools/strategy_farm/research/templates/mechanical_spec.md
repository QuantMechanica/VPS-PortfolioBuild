---
research_id: QM-RESEARCH-YYYY-NNNN
spec_version: 1
timeframe: D1
symbols: SYMBOL_INPUT_1
---

# Mechanical Specification — <edge name>

> MECHANIZE template (design doc sec 4.1). Fill every section with EXPLICIT,
> bounded, deterministic rules. The gate `mechanization_check.py` reads this file
> statically: it must contain every heading below, no ML/inference term inside the
> mechanics (only the `## Research provenance` narrative is exempt), and a finite
> parameter table with bounded numeric ranges. Symbols are INPUTS, never code
> literals (CLAUDE.md 2026-09-06).

## Structural cause
<Why the edge exists: the flow / inventory / auction / rebalance / liquidity /
risk-premium / behavioural cause. One paragraph, economic, not statistical.>

## Price signature
<The observable price pattern that expresses the cause: enter/break/cross/close/rank.>

## Persistence
<Why the edge persists — capacity, institutional constraint, forced flow, slow
arbitrage. What would erode it.>

## Long entry
<Exact deterministic long-entry rule. e.g. "Enter long at the close of the D1 bar
when close > upper_channel(channel_len) AND atr(atr_len) > atr_floor.">

## Short entry
<Exact deterministic short-entry rule, or "Not applicable — long-only edge.">

## No-trade conditions
<When the EA stays flat: news blackout window, session boundary, filter fail.>

## Exit
<Exact deterministic exit rule (time stop, opposite signal, target hit).>

## Stop loss
<Exact stop rule, in ATR multiples or price distance. Bounded.>

## Take profit
<Exact target rule if any, else "Not applicable — exit governed by trailing/time stop.">

## Position sizing
RISK_FIXED for backtest; RISK_PERCENT for live (CLAUDE.md Hard Rules). Bounded risk.

## Session rules
<Trading session window, in broker time (GMT+2/+3 NY-Close). Bounded.>

## Filters
<Every filter as a deterministic rule with a bounded parameter.>

## Parameter ranges
| Parameter | Range | Default |
|-----------|-------|---------|
| channel_len | 10 .. 80 | 40 |
| atr_len | 5 .. 30 | 14 |
| atr_floor | 0.1 .. 3.0 | 0.5 |
| risk_pct | 0.25 .. 2.0 | 1.0 |
| session_start_hour | 0 .. 23 | 8 |

## Required indicators / data
<Native MT5 indicators + the live news filter only. No external runtime feed.>

## Timeframe
<Single timeframe, e.g. D1 (charter allows D1 and M5..M15 / H1..H24).>

## Symbols
<Symbol applicability, provided as INPUT parameters — one input per symbol slot.>

## Expected trade frequency
<Approximate trades per year per symbol; must clear the Q02 floor of >= 5/yr.>

## Invalidation conditions
<The numeric kill rule: the observation(s) whose failure retires the edge.>

## Falsification
<The explicit falsifier with a NUMERIC kill criterion — how a walk-forward /
holdout result would refute the hypothesis.>

## Q08 / Q11 risk
<Crisis / news-risk behaviour; how the edge behaves through Q08 stress and Q11
full-history confirmation.>

## FTMO fit
5% daily / 10% total drawdown boxes; news blackout; timeframe swing/scalp fit.

## Research provenance
<Narrative of the ML/statistical DISCOVER work that surfaced this edge. This is the
ONLY section exempt from the ML-term scan. Every quantitative claim must cite a
computed-output file recorded (with sha256) in research.json (design doc sec 2.4).>
