---
ea_id: QM5_11906
slug: watthana-candlestick-rsi-stoch-ea-h1
source_id: 7f1c4b9a-3d68-5e52-a836-c4d9e2b7f1a8
source_citation: "Watthana Pongsena, Prakaidoy Ditsayabut, Panida Panichkul, Nittaya Kerdprasop, Kittisak Kerdprasop, 'Developing a Forex Expert Advisor Based on Japanese Candlestick Patterns and Technical Trading Strategies', International Journal of Trade, Economics and Finance (IJTEF) Vol. 9, No. 6, December 2018. DOI 10.18178/ijtef.2018.9.6.622"
title: "Watthana Long-Shadow Candle Reversal + RSI + Stochastic EA H1"
edge_type: candlestick_reversal_with_oscillator_confluence
period: H1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX]
risk_mode_backtest: RISK_FIXED
risk_fixed: 1000
risk_mode_live: RISK_PERCENT
risk_percent: 0.5
expected_trades_per_year_per_symbol: 50
status: cards_ready
r1_verdict: PASS
r1_note: "R1 — peer-reviewed IJTEF Dec 2018; senior author Kerdprasop has 155 publications. Published EUR/USD backtest: $10K→$15K in 2017."
r2_verdict: UNKNOWN
r3_verdict: UNKNOWN
r4_verdict: UNKNOWN
r1_track_record: PASS
r1_reasoning: "Single source_id with peer-reviewed IJTEF 2018 DOI satisfies R1's one-source-per-card requirement."
r2_mechanical: PASS
r2_reasoning: "Explicit shadow-ratio candle definitions, RSI(14) and Stochastic(14) zone thresholds, prior-trend detection, auto-reverse exit logic, ATR stop, and 120-bar timeout are all mechanically defined."
r3_data_available: PASS
r3_reasoning: "DWX forex majors on H1 are the target universe and are directly testable; the paper itself tested on EUR/USD H1."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic indicator-based rules, no ML or PnL-adaptive logic; auto-reverse closes before opening opposite, maintaining 1-position-per-magic."
strategy_params:
  timeframe: H1
  rsi_period: 14
  rsi_oversold: 30
  rsi_overbought: 70
  stoch_k_period: 14
  stoch_d_period: 3
  stoch_slowing: 3
  stoch_oversold: 20
  stoch_overbought: 80
  candle_body_to_shadow_ratio: 2.0
  trend_lookback_bars: 5
  trend_min_change_pips: 10
  bullish_patterns: ["hammer", "inverted_hammer"]
  bearish_patterns: ["hanging_man", "shooting_star"]
  auto_reverse_on_exit: true
g0_status: APPROVED
g0_approval_reasoning: "R1 single IJTEF source_id/citation; R2 mechanical candle+RSI+Stoch entries/exits with plausible H1 cadence >=2 trades/yr/symbol; R3 forex DWX symbols testable; R4 deterministic ML-free 1-pos."
last_updated: 2026-05-25
---

# QM5_11906 — Watthana Long-Shadow Candle Reversal + RSI + Stochastic EA (H1)

## Setup

Three-way confluence at extreme-momentum reversal points. The setup
requires (1) a long-shadow Japanese candlestick reversal pattern in
the appropriate prior-trend context, AND (2) RSI(14) in an extreme zone
(overbought or oversold), AND (3) Stochastic(14) also in the matching
extreme zone. All three conditions must hold on the same closed H1 bar
to trigger entry.

The auto-reverse exit rule (close + open opposite immediately when any
of the three exit conditions fire) keeps the system always-in-market
once a first signal triggers. This means the EA is rarely flat.

## Pattern Definitions

For a closed H1 bar with `body = |open - close|`:

- **Hammer (bullish reversal)**:
  - prior_trend == DOWN
  - `open - close > 0` (bearish candle body)
  - `(open - low) > 2 × body`
- **Inverted Hammer (bullish reversal)**:
  - prior_trend == DOWN
  - `open - close >= 0`
  - `(high - close) > 2 × body` if bearish (`high - open` if bullish)
- **Hanging Man (bearish reversal)**:
  - prior_trend == UP
  - `open - close < 0` (bullish candle body)
  - `(close - low) > 2 × body`
- **Shooting Star (bearish reversal)**:
  - prior_trend == UP
  - `open - close <= 0`
  - `(high - close) > 2 × body` if bullish

Prior trend is determined by comparing `close[bar]` to `close[bar - 5]`:
UP if `close[bar] > close[bar - 5] + 10 pips`, DOWN if
`close[bar] < close[bar - 5] - 10 pips`, else FLAT (no entry).

## Entry Rules

Detected on H1 closed bars:

1. **Long entry** (all three simultaneous):
   - Hammer OR Inverted Hammer pattern detected, AND
   - RSI(14) < 30, AND
   - Stochastic %K(14, 3, 3) < 20.
2. **Short entry** (all three simultaneous):
   - Hanging Man OR Shooting Star pattern detected, AND
   - RSI(14) > 70, AND
   - Stochastic %K(14, 3, 3) > 80.
3. **Order placement**: Market order at open of next H1 bar.
4. **No-pyramiding**: Only one open position per symbol at a time. If
   an entry signal fires while a position is open in the same
   direction, skip.

## Exit Rules

- **Auto-reverse exit** (close current position + open opposite at
  next H1 open) when ANY of:
  - An opposite candlestick reversal pattern is detected.
  - For a long: RSI(14) > 70 OR Stochastic(14) > 80.
  - For a short: RSI(14) < 30 OR Stochastic(14) < 20.
- **Defensive stop loss**: paper does not specify; this card adds
  a hard stop at `entry_price ± 2.0 × ATR(14)` for risk control.
- **Hard timeout**: close at H1 bar 120 (5 days) if no exit triggers.
- **Risk**: backtest RISK_FIXED `risk_fixed = 1000`; live RISK_PERCENT
  `risk_percent = 0.5`.

## Universe

target_symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX,
AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX

H1 forex majors. Paper tested H1 EUR/USD only; full majors basket is
the natural QM extension.

## Source

source_citation: Watthana Pongsena et al., "Developing a Forex Expert
Advisor Based on Japanese Candlestick Patterns and Technical Trading
Strategies," International Journal of Trade, Economics and Finance
Vol. 9, No. 6 (December 2018), pp. 238-242. DOI
10.18178/ijtef.2018.9.6.622. Senior author Nittaya Kerdprasop has 155
publications / 1,370 citations on ResearchGate. Published backtest:
EUR/USD 2017/01/02-2017/12/29, $10,000 starting balance → $15,017.18
final (50.17% YoY); outperformed two prior published Forex EAs.
