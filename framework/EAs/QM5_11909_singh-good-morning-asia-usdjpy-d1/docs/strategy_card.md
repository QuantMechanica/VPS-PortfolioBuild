---
ea_id: QM5_11909
slug: singh-good-morning-asia-usdjpy-d1
source_id: b4d7e6c1-2f59-5a83-9d68-c5b4e2a8d7f3
source_citation: "Mario Singh, '17 Proven Currency Trading Strategies: How to Profit in the Forex Market' (John Wiley & Sons, 2013), Strategy 17 'Good Morning Asia', chapter 10 pp. 228-233. ISBN 978-1118385517."
title: "Singh 'Good Morning Asia' — Previous-Day Momentum Continuation USD/JPY D1"
edge_type: previous_bar_momentum_continuation
period: D1
target_symbols: [USDJPY.DWX]
risk_mode_backtest: RISK_FIXED
risk_fixed: 1000
risk_mode_live: RISK_PERCENT
risk_percent: 0.5
expected_trades_per_year_per_symbol: 100
status: cards_ready
r1_verdict: PASS
r1_reasoning: "Single source_id links to Singh Wiley 2013 book chapter; exactly one source with traceable lineage."
r1_note: "R2 — Wiley 2013 published. Mario Singh is media-known forex commentator (CNBC, Bloomberg appearances)."
r2_verdict: PASS
r2_reasoning: "Bar color check, next-bar market entry, prior-bar high/low stop, 0.5× pip-distance TP, and one-bar time stop are all mechanically implementable."
r3_verdict: PASS
r3_reasoning: "USDJPY.DWX is a standard DWX forex major directly testable on MT5."
r4_verdict: PASS
r4_reasoning: "Pure bar-structure price rules; no ML, no adaptive parameters, one position per symbol."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
strategy_params:
  timeframe: D1
  daily_close_time_ny: "17:00"
  pair_lock: USDJPY
  min_stop_loss_pips: 30
  target_to_stop_ratio: 0.5
  signal_bar_color_required: true
  always_in_market: false
g0_status: APPROVED
g0_approval_reasoning: "R1 PASS single source_id/citation; R2 PASS mechanical D1 prior-bar entry, SL/TP/time exit with ~100 trades/year plausible; R3 PASS USDJPY.DWX testable; R4 PASS deterministic no ML one-position compatible"
last_updated: 2026-05-25
---

# QM5_11909 — Singh 'Good Morning Asia' — Previous-Day Momentum Continuation (USD/JPY D1)

## Setup

Pure price-action strategy from Mario Singh's "17 Proven Currency
Trading Strategies" (Wiley 2013). Exploits the empirical tendency for
the early Asian session on USDJPY to continue the directional
sentiment established by the prior US session close. Single-pair
strategy (USDJPY only), daily-bar resolution with the bar boundary at
17:00 New York time (= NY close = Darwinex DXZ daily close).

The negative reward-to-risk profile (1:2 — risking 2 units to make 1)
is intentional and offsets a claimed high hit rate. This is a distinct
risk-shape from the rest of the QM registry; testing it alongside the
positive-R:R majority is itself part of the portfolio diversification
goal.

## Entry Rules

Detected at the close of each D1 bar (NY 17:00):

1. **Bar color check on just-closed D1 bar**:
   - Bull bar: `close > open` → long setup armed for next bar.
   - Bear bar: `close < open` → short setup armed for next bar.
   - Doji (`close == open`): no trade.
2. **Long entry**: At the OPEN of the next D1 bar (NY 17:00 next day),
   market buy.
3. **Short entry**: At the OPEN of the next D1 bar, market sell.

## Exit Rules

- **Stop loss (long)**: at the LOW of the prior signal candle (the bull
  candle that armed the setup). If the resulting pip distance is less
  than 30, widen the stop to entry minus 30 pips. Mirror for shorts at
  the HIGH of the prior bear candle / entry plus 30 pips.
- **Take profit**: 0.5 × stop-loss pip distance, in trade direction.
  Example: stop-loss 80 pips below entry → take-profit 40 pips above
  entry. 1:2 R:R by design.
- **Time stop**: close at end of D1 bar t+1 (i.e., hold for at most
  one full daily bar after entry). If neither stop nor target hit by
  next NY-close, close at market.
- **Risk**: backtest RISK_FIXED `risk_fixed = 1000`; live RISK_PERCENT
  `risk_percent = 0.5`.

## Universe

target_symbols: USDJPY.DWX

**USDJPY only**. The strategy is explicitly single-pair per Singh's
specification. The rationale (US-economy size + JPY as primary Asian
major + USDJPY liquidity at Asian open + Tokyo being first major Asian
session) does not transfer to other JPY crosses or to non-USD pairs.

## Source

source_citation: Mario Singh, "17 Proven Currency Trading Strategies:
How to Profit in the Forex Market," John Wiley & Sons (2013), ISBN
978-1118385517. Strategy #17 "Good Morning Asia," chapter 10 pp.
228-233. The author runs FX1 Academy (Singapore-based forex training)
and has appeared on CNBC and Bloomberg as a forex commentator. The
strategy is presented as one of the deliberately mechanical setups in
the book's "Strategies for Mechanical Traders" section.
