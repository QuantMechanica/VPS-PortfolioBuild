# STR-067 — Claude independent spec (pre-reconciliation)

Source: thread 506226 (StingrayEA, ~2014). Exec TF H1 ("Any Currency" →
cohort EURUSD.DWX, GBPUSD.DWX test-design, flagged).

## Variant-split resolution (the ledger's open suspect)

The author's p.3 explanation resolves the ambiguity: he uses the bands as
support/RESISTANCE — "if the price cross the upper band from below, for
me the price breakout the resistant". The entry table therefore defines
BOTH families per band, coherently:
- Upper band, cross from BELOW (breakout) → BUY (with confirms).
- Upper band, cross from ABOVE (back inside) → SELL.
- Lower band mirror ("do the same for lowerband"): cross from ABOVE
  (breakdown) → SELL; cross from BELOW (back inside) → BUY.
The prior build QM5_10015 implemented only a fade reading → rebuild
justified with the full four-case table.

## Rules (closed bars; signal candle = shift 1, band-crossing candle =
## shift 2; entry next bar)

BB(20, 2.0, close), Stochastic(14,3,3).
BUY (upper breakout): Close(3)/candle-2 path crosses BB-upper — mechanize:
bar 2 CLOSES above the upper band while bar 3 closed below it; Stoch
main(1) > signal(1); bar 1 bullish (close>open); Stoch main(1) < 80.
SELL (upper re-entry): bar 2 closes back below the upper band from above
(bar 3 closed above); main(1) < signal(1); bar 1 bearish; main(1) > 20.
LOWER-band mirror for both.
TP 50 pips; SL 50 pips; trailing stop 15 pips (MT4-style ratchet: once
profit > 15 pips, SL = price − 15 pips, never widening; per-tick with
1-pip min-step; flagged mechanization). One position.

## Inputs

```
strategy_bb_period   = 20
strategy_bb_dev      = 2.0
strategy_stoch_k     = 14
strategy_stoch_d     = 3
strategy_stoch_slow  = 3
strategy_tp_pips     = 50.0
strategy_sl_pips     = 50.0
strategy_trail_pips  = 15.0
```

## Hooks sketch

Filter: H1/params/warmup ≥ 30/handles (iBands, iStochastic). Entry:
four-case table (own guard). Manage: MT4-style trail (per-tick ratchet,
stops-level-legal, never widen). Exit: false. News: default.

## Notes

- "The current candle is bullish AND stochastic below 80" — current =
  the just-closed confirm candle (shift 1); mechanization flagged.
- Engulfing-pattern musings = discretionary, not built.
- Frequency est. 100-250/yr/symbol.
