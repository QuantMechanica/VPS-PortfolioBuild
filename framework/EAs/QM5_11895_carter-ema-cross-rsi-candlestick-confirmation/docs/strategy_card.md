---
ea_id: QM5_11895
slug: carter-ema-cross-rsi-candlestick-confirmation
source_id: 9b7e5f31-2d68-5aa4-b914-d7e2f5c1a8b6
source_citation: "Thomas Carter, '20 Forex Trading Strategies Collection (1 Hour Time Frame)' Kindle 2014 — Strategy #15 pages 28-29"
title: "Carter EMA 5/21 Cross + RSI + Candlestick-Pattern Confirmation H1"
edge_type: trend_change_with_candle_pattern
period: H1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX]
risk_mode_backtest: RISK_FIXED
risk_fixed: 1000
risk_mode_live: RISK_PERCENT
risk_percent: 0.5
expected_trades_per_year_per_symbol: 70
status: cards_ready
r1_verdict: FAIL
r1_note: "Kindle vanity-press, anonymous author. Candlestick patterns themselves are public-domain (Nison 1991)."
r2_verdict: UNKNOWN
r3_verdict: UNKNOWN
r4_verdict: UNKNOWN
r1_track_record: PASS
r1_reasoning: "Single source_id with Carter Kindle citation present; R1 requires one source per card and author credentials are not required."
r2_mechanical: PASS
r2_reasoning: "EMA5/21 cross, RSI(21) zone filter, named candlestick pattern conditions (engulfing/hammer geometry defined), fixed 2:1 RR TP, and adverse-signal exit are all mechanically implementable."
r3_data_available: PASS
r3_reasoning: "DWX forex majors are the target universe and are directly testable in the MT5 pipeline."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic indicator and pattern-geometry rules, no ML or PnL-adaptive components, 1-position-per-magic compatible."
strategy_params:
  timeframe: H1
  ema_fast_period: 5
  ema_slow_period: 21
  rsi_period: 21
  rsi_threshold: 50
  bullish_candle_patterns: ["bullish_engulfing", "hammer"]
  bearish_candle_patterns: ["bearish_engulfing", "inverted_hammer"]
  candle_lookback_bars: 3
  target_method: fixed_rr
  target_rr: 2.0
g0_status: APPROVED
g0_approval_reasoning: "R1 PASS single source_id/citation; R2 PASS mechanical H1 EMA cross with RSI and candle filters, exits and >=2/y plausible; R3 PASS forex DWX majors; R4 PASS deterministic no ML 1-pos compatible"
last_updated: 2026-05-25
---

# QM5_11895 — Carter EMA 5/21 Cross + RSI(21) + Candlestick Confirmation (H1)

## Setup

Combines a fast/slow EMA crossover (EMA 5 over EMA 21) as the trend-change
signal with an RSI(21) zone filter and a classical Japanese candlestick
pattern as the final trigger. The candlestick pattern requirement
distinguishes this from pure indicator-based EMA-cross systems by demanding
that the bar generating the entry shows clear reversal/continuation price
action consistent with the indicator stack.

Eligible long candles: Bullish Engulfing, Hammer. Eligible short candles:
Bearish Engulfing, Inverted Hammer. Patterns must complete within the last
3 H1 bars relative to the EMA cross.

## Entry Rules

Detected on H1 closed bars:

1. **Long EMA condition**: EMA(5) crosses above EMA(21) — i.e., on the
   just-closed bar, EMA5 > EMA21 AND on the previous closed bar, EMA5
   ≤ EMA21.
2. **Long RSI filter**: RSI(21) > 50 on the trigger bar.
3. **Long candlestick filter**: Within the last 3 H1 bars (inclusive of the
   trigger bar), at least one bar prints a Bullish Engulfing or Hammer
   pattern.
   - Bullish Engulfing: bar[i].open < bar[i-1].close AND bar[i].close >
     bar[i-1].open AND bar[i-1] is bearish AND bar[i] is bullish.
   - Hammer: lower_shadow ≥ 2 × body AND upper_shadow ≤ 0.1 × body AND
     close > open.
4. **Long entry**: Market buy at the open of the next H1 bar after all 3
   conditions are simultaneously satisfied.
5. **Short conditions**: Mirror of above — EMA(5) crosses below EMA(21),
   RSI(21) < 50, Bearish Engulfing or Inverted Hammer in last 3 bars.
6. **Short entry**: Market sell at the open of the next H1 bar.

## Exit Rules

- **Initial stop loss (long)**: Below the lowest low of the last 10 H1 bars
  prior to entry minus 2 pips. Mirror for shorts.
- **Take profit**: 2× initial stop-loss distance in trade direction
  (fixed 2:1 reward-to-risk).
- **Adverse-signal exit**: Close immediately if EMA(5) crosses back through
  EMA(21) against trade direction OR if RSI(21) crosses back through the 50
  level against trade direction OR if a contrarian candlestick pattern
  forms (long trade closed on Bearish Engulfing or Inverted Hammer).
- **Hard timeout**: Close at H1 bar 120 (5 days) if no other exit hit.
- **Risk**: backtest RISK_FIXED `risk_fixed = 1000`; live RISK_PERCENT
  `risk_percent = 0.5`.

## Universe

target_symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX,
AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX

H1 forex majors — Carter specifies EUR/USD or GBP/USD; the candlestick
filter is symbol-agnostic so the full forex-majors basket is appropriate.

## Source

source_citation: Thomas Carter, "20 Forex Trading Strategies Collection
(1 Hour Time Frame)" 2014 Kindle, Strategy #15 pages 28-29; URL unavailable. Candlestick
pattern definitions follow Steve Nison's "Japanese Candlestick Charting
Techniques" (1991) — the canonical reference. EMA cross + RSI filter is a
generic combination; the candlestick-pattern overlay is the distinctive
contribution.
