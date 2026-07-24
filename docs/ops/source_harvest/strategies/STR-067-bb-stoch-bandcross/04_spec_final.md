# STR-067 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_bb-stoch-bandcross-h1` · TF H1 · Symbols (slots 0-1):
EURUSD.DWX, GBPUSD.DWX. Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input int    strategy_bb_period  = 20;
input double strategy_bb_dev     = 2.0;
input int    strategy_stoch_k    = 14;
input int    strategy_stoch_d    = 3;
input int    strategy_stoch_slow = 3;
input double strategy_tp_pips    = 50.0;
input double strategy_sl_pips    = 50.0;
input double strategy_trail_pips = 15.0;
```

## Entry (four-case table; closed bars: confirm = shift 1, crossing bar =
## shift 2, prior = shift 3; entry next bar; one position)

Bands on close. Cross-out upper (BUY): Close(3) <= Upper(3) AND Close(2) >
Upper(2); confirms: StochMain(1) > StochSignal(1), bar 1 bullish
(close>open), StochMain(1) < 80.
Cross-back upper (SELL): Close(3) >= Upper(3)... NO — cross from above =
Close(3) > Upper(3) AND Close(2) < Upper(2); confirms: main(1) <
signal(1), bar 1 bearish, main(1) > 20.
Lower-band mirror: cross-out lower (SELL; main<signal, bearish, main>20);
cross-back lower (BUY; main>signal, bullish, main<80).
Only one case may fire per bar (first match in fixed order out-upper,
out-lower, back-upper, back-lower); equality never signals.

## Order / Manage

SL 50 / TP 50 pips server-side. Trailing (Manage, per tick): once profit
> trail_pips, candidate SL = price ∓ trail_pips; modify only if it
tightens by >= 1 pip (min-step) and is stops-level-legal; never widen.

## Hooks

1 Filter: H1/params/warmup >= 30/handles (iBands, iStochastic). 2 Entry:
table. 3 Manage: trail. 4 Exit: false. 5 News: default.

## Compliance

Registry magic (2 slots); RISK_FIXED/RISK_PERCENT; <=1%/trade;
engulfing-pattern musings not built; frequency est. 100-250/yr/symbol.
