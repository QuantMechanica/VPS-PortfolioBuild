---
ea_id: QM5_11912
slug: cheng-triangle-2touch-second-break-h1
source_id: e3a7c5b9-4d62-5f81-9c47-d2b6e3f5a1d8
source_citation: "Grace Cheng, '7 Winning Strategies for Trading Forex' (Harriman House, 2007), Strategy 5 'Decreased Volatility Breakout', chapter 9. ISBN 978-1905641192."
title: "Cheng Triangle Breakout — 2-Touch Validity + Ignore-First-Break (H1)"
edge_type: triangle_second_breakout
period: H1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX]
risk_mode_backtest: RISK_FIXED
risk_fixed: 1000
risk_mode_live: RISK_PERCENT
risk_percent: 0.5
expected_trades_per_year_per_symbol: 20
status: cards_ready
r1_verdict: PASS
r2_verdict: PASS
r3_verdict: PASS
r4_verdict: PASS
g0_status: APPROVED
last_updated: 2026-05-25
---

# QM5_11912 — Cheng Triangle Breakout — 2-Touch + Ignore-First-Break (H1)

This is the build-time snapshot of the approved card at
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_11912_cheng-triangle-2touch-second-break-h1.md`.

## Setup

Cheng's decreased-volatility breakout pattern for ascending and descending
triangles has two distinctive requirements:

1. Both trendlines must be touched at least twice before the triangle is
   valid.
2. The first breakout attempt is ignored. Entry is allowed only after price
   re-enters the triangle and makes a second breakout.

The hypothesis is that the failed first break clears early breakout traders,
leaving the later break with better follow-through.

## Pattern Definitions

- Ascending triangle: approximately horizontal resistance with at least two
  touches and rising support with at least two touches.
- Descending triangle: approximately horizontal support with at least two
  touches and falling resistance with at least two touches.
- Detection uses ZigZag depth 8, deviation 8 pips, and backstep 3 over 30-200
  closed H1 bars.

## Entry Rules

1. Detect a valid two-touch triangle on closed H1 data.
2. Record and ignore the first close beyond either triangle boundary.
3. Require a close back inside the projected triangle within ten H1 bars.
4. For an ascending triangle, place a buy stop ten pips above resistance.
5. For a descending triangle, place a sell stop ten pips below support.
6. Expire the pending order after 50 H1 bars and consume each formation after
   one entry attempt.

## Exit Rules

- Stop at least ten pips beyond the opposite projected boundary.
- Target one full triangle height from the breakout entry.
- Close after 240 H1 bars if neither price exit has fired.
- Standard framework Friday close, news, and kill-switch gates remain active.

## Risk and Universe

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The approved universe is EURUSD.DWX, GBPUSD.DWX,
USDJPY.DWX, USDCAD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX,
GBPJPY.DWX, and AUDJPY.DWX on H1.

No ML, grid, martingale, averaging, pyramiding, or live setfile is authorized.

## Source

Grace Cheng, *7 Winning Strategies for Trading Forex*, Harriman House, 2007,
Strategy 5, "Decreased Volatility Breakout," chapter 9, ISBN
978-1905641192.
