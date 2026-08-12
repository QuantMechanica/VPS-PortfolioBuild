# STR-012 — Claude independent spec (pre-reconciliation)

Source: thread 1233107 "Your EA v3" (rockzz, 2023; exact EA rules restated in
post #1; ChatGPT-built MQ4 attached). Exec TF D1. Symbols: majors the thread
backtested — EURUSD, GBPUSD, AUDUSD, USDJPY, EURAUD (.DWX).

## Core rules (from the OP's 12-point restatement)

1. On each new D1 bar (one action per day):
   - wick_buy = prevOpen − prevLow (lower shadow of previous D1 candle)
   - wick_sell = prevHigh − prevOpen (upper shadow)
2. If wick_buy > wick_sell → place BUY STOP at prevHigh + pips_above_high;
   SL = prevHigh − sl_pips; TP = entry + tp_pips.
3. If wick_sell > wick_buy → SELL STOP at prevLow − pips_below_low;
   SL = prevLow + sl_pips; TP = entry − tp_pips.
4. Equality (wick_buy == wick_sell) → no order (mechanization: strict >).
5. One pending per day; at day roll, cancel an unfilled pending before
   placing the new one (mechanization decision — the MQ4's behaviour is not
   fully stated; cancel-at-roll is the conservative reading of "reset
   orderPlaced", prevents stacking; framework pending-guard covers dupes).
6. An open POSITION blocks new pendings (no pyramiding; one exposure).
7. Defaults: TP 100 pips / SL 30 pips (author's "profitable settings");
   pips_above_high / pips_below_low NOT stated in text → default 2 pips
   (smallest house-conventional breakout offset; FLAGGED unsourced).

## Inputs

```
strategy_tp_pips = 100.0
strategy_sl_pips = 30.0
strategy_pips_above_high = 2.0   // unsourced mechanization, flagged
strategy_pips_below_low  = 2.0   // unsourced mechanization, flagged
```

## Day anchor

Broker D1 bars (NY-close house convention; the author's MT4 D1 was also
broker-daily). prevHigh/prevLow/prevOpen from D1 shift 1.

## Hooks sketch

- NoTradeFilter: params sane (tp>0, sl>0, offsets>=0); >= 2 closed D1 bars.
- EntrySignal: on new D1 bar (own static guard): if own position → skip
  (keep pending management to Manage); compute wicks; place the stop order
  via the framework pending path (QM_EntryRequest with pending type BUY_STOP/
  SELL_STOP, absolute SL/TP from the rule — note SL is anchored to the LEVEL
  (prevHigh/prevLow), not the fill; expiration = next day roll (set
  req.expiration_seconds to time-to-day-roll; belt: Manage cancels at roll).
- Manage: at day roll (new D1 bar), cancel own unfilled pending
  (TM_REMOVE_PENDING reason=day_roll) BEFORE EntrySignal places the new one
  (ordering: Manage runs first in OnTick — fits).
- ExitSignal: false. NewsFilterHook: framework default.

## Risks / notes

- R1 honesty: OP admits live "hits stop loss everytime" and warns tester
  results diverge; thread flags control-point backtests + overfit. Built for
  faithful falsification on real ticks; expect harsh Q02/Q04.
- SL anchored at level ± 30 pips means initial risk varies with the breakout
  offset fill (slippage) — risk sizing uses the actual request SL (framework).
- Frequency: up to ~250 pendings/yr/symbol, fill fraction unknown — floor
  safe.
- Overlap QM5_9959 (ledger): prior build from this thread family — verify
  distinction in reconciliation (9959 SPEC check: likely different direction
  rule or added filters).
