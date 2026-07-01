---
ea_id: QM5_11902
slug: bermuda-triangle-123-fib-extension-h1
source_id: d2e5a8c4-3f76-5b91-8c47-a1f9d6e3b5c8
source_citation: "Michel Selim, 'Forex Bermuda Trading Strategy' on superiorfxsignals.com (2012). Constituent patterns: symmetric triangle (Edwards & Magee, 'Technical Analysis of Stock Trends', 1948) + 1-2-3 reversal (Vic Sperandeo, 'Trader Vic: Methods of a Wall Street Master', 1991) + Fibonacci extensions"
title: "Bermuda Triangle Compression + 1-2-3 + Fib-Extension Targets H1"
edge_type: triangle_breakout_with_123_and_fib_projections
period: H1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX]
risk_mode_backtest: RISK_FIXED
risk_fixed: 1000
risk_mode_live: RISK_PERCENT
risk_percent: 0.5
expected_trades_per_year_per_symbol: 25
status: cards_ready
r1_verdict: FAIL
r1_note: "Anonymous retail-FX source. Constituent patterns are classical TA literature."
r2_verdict: UNKNOWN
r3_verdict: UNKNOWN
r4_verdict: UNKNOWN
r1_track_record: PASS
r1_reasoning: "Single source_id with citation to Michel Selim superiorfxsignals.com guide; one source per card is satisfied and author credentials are not required."
r2_mechanical: PASS
r2_reasoning: "ZigZag(12,10,3) triangle and 1-2-3 pivot detection, Fib retracement validity filter, buy/sell-stop at P2±2pips, and three-tier Fib-extension TPs are deterministic despite complexity."
r3_data_available: PASS
r3_reasoning: "DWX forex majors are the target universe and are directly testable in the MT5 pipeline on H1."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic pattern-detection rules, no ML or PnL-adaptive parameters; scaled exit fractions are rule-defined, not adaptive."
strategy_params:
  timeframe: H1
  zigzag_depth: 12
  zigzag_deviation_pips: 10
  zigzag_backstep: 3
  triangle_min_bars: 30
  triangle_max_bars: 200
  triangle_convergence_required: true
  p3_fib_levels_valid: [0.236, 0.382, 0.50, 0.618]
  p3_fib_tolerance: 0.05
  entry_fib_level: 1.0
  target1_fib_level: 1.618
  target2_fib_level: 2.618
  target3_fib_level: 4.236
  scale_out_fractions: [0.4, 0.4, 0.2]
g0_status: APPROVED
g0_approval_reasoning: "R1 one source_id/source_citation; R2 mechanical triangle+123+fib entry/exit with plausible >2 H1 trades/year/symbol despite 25 estimate being aggressive; R3 forex DWX testable; R4 deterministic non-ML single-position compatible."
last_updated: 2026-05-25
---

# QM5_11902 — Bermuda Triangle Compression + 1-2-3 + Fib-Extension Targets (H1)

## Setup

Three-layer pattern confluence: (1) triangle compression structure (two
converging trendlines from opposite directions) provides regime context
indicating coiled volatility, (2) a 1-2-3 swing pattern within or near
the triangle identifies the directional bias and the breakout pivot, and
(3) Fibonacci extension projections from the 1→2 leg provide deterministic
entry, stop, and three scaled-out target levels.

## Entry Rules

Detected on H1 closed bars:

1. **Triangle detection**: Scan last 30-200 H1 bars for the presence of
   a converging triangle:
   - Trendline A: line connecting at least 2 consecutive ZigZag(12,10,3)
     highs with negative slope (resistance).
   - Trendline B: line connecting at least 2 consecutive ZigZag lows
     with positive slope (support).
   - Convergence: trendline A and trendline B project to intersect
     within the next 50 H1 bars (i.e., the apex is in the near future).
2. **1-2-3 pattern within triangle**: identify three sequential ZigZag
   pivots within the triangle:
   - For long setup: pivot_low (P1), pivot_high (P2), pivot_low (P3),
     with `P3.price > P1.price`.
   - For short setup: pivot_high (P1), pivot_low (P2), pivot_high (P3),
     with `P3.price < P1.price`.
3. **Point-3 Fib validity filter**: anchor Fib-0 at P1, Fib-100 at P2;
   the price of P3 must lie within tolerance ±0.05 of one of {0.236,
   0.382, 0.50, 0.618}. If P3 retraces deeper than 0.65, the pattern is
   invalidated.
4. **Entry trigger (long)**: place buy-stop pending order at
   `price_at_fib_100 + 2 pips` (which equals `P2.price + 2 pips`).
5. **Entry trigger (short)**: place sell-stop at `P2.price - 2 pips`.
6. **Order validity**: 50 H1 bars from order placement; cancel if not
   triggered by then.

## Exit Rules

- **Stop loss**: at P3.price ± 5 pips (below for longs, above for shorts).
- **Take profit, three-tier scaled exit**:
  - **TP1** at Fib-161.8 extension of the 1→2 leg, close 40% of position.
  - **TP2** at Fib-261.8 extension, close another 40% of position.
  - **TP3** at Fib-423.6 extension, close remaining 20%.
- **Breakeven shift**: after TP1 hits, move stop to entry price.
- **After TP2**: move stop to TP1 level.
- **Hard timeout**: close any open remainder at H1 bar 480 (20 days)
  after entry.
- **Risk**: backtest RISK_FIXED `risk_fixed = 1000`; live RISK_PERCENT
  `risk_percent = 0.5`.

## Universe

target_symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX,
AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX

H1 forex majors — source explicitly recommends low-spread pairs like
EURUSD; the pattern logic is symbol-agnostic.

## Source

source_citation: Michel Selim, "Forex Bermuda Trading Strategy"
self-published guide on superiorfxsignals.com (2012). Constituent
classical patterns: symmetric triangle (R.D. Edwards and J. Magee,
"Technical Analysis of Stock Trends", 1948 — canonical chart-pattern
reference); 1-2-3 reversal (Vic Sperandeo, "Trader Vic: Methods of a
Wall Street Master", 1991, John Wiley); Fibonacci-extension projections
(applied via the Elliott Wave / Larry Pesavento harmonic literature).
