# STR-042 — Claude independent spec (pre-reconciliation)

Source: thread 297661 (Radu_C, complete single post). EURUSD.DWX M15 only
(source: "optimized specifically for EUR/USD and the 15 min timeframe").

## Indicators

green = iStochastic(72, 1, 1) %K (buffer 0); red = iStochastic(285, 1,
246) %K. Levels 24/76. Warmup ≥ 285+246+10 bars.

## Rules (verbatim; all closed-bar shifts 1/2; enter/close at next open)

- LONG: green(1) > red(1) AND green(1) > 24 AND close(1)<open(1) AND
  close(2)<open(2) (two consecutive bearish) → market buy next bar.
- CLOSE LONG: green(1) < red(1) AND two consecutive bullish → close.
- SHORT: green(1) < red(1) AND green(1) < 76 AND two consecutive bullish →
  market sell.
- CLOSE SHORT: green(1) > red(1) AND two consecutive bearish → close.
- One position; opposite entry never opens while a position exists (close
  first via the close rule; no same-evaluation reversal).
- Source has NO SL/TP ("open system") → HOUSE: mandatory emergency stop =
  4×ATR(14) at entry (20103 pattern; flagged unsourced).

## Inputs

```
strategy_green_k = 72
strategy_red_k = 285
strategy_red_slowing = 246
strategy_level_low = 24.0
strategy_level_high = 76.0
strategy_atr_period = 14
strategy_emergency_atr_mult = 4.0
```

## Hooks sketch

Filter: M15/params/warmup/handles. Entry: rules above (own guard).
Manage: empty. ExitSignal: close rules (bar-gated level reads; doji bars
(close==open) count as NEITHER bullish nor bearish — flagged
mechanization). News: default.

## Notes

- Author-stated robustness claims unaudited; teaching-example provenance.
- Doji handling + "candles" = strict inequality — reconciliation point.
- Frequency: M15 pullback pattern ~150-300/yr.
