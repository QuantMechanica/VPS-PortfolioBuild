# STR-071 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_rsi2-obos-scalp-m15` · TF M15 · Symbols (slots 0-1):
EURUSD.DWX, GBPUSD.DWX. Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input int    strategy_rsi_period      = 2;
input double strategy_buy_level       = 30.0;
input double strategy_sell_level      = 70.0;
input double strategy_sl_pips         = 25.0;
input double strategy_tp_pips         = 10.0;
input double strategy_be_trigger_pips = 5.0;
input double strategy_be_plus_pips    = 1.0;
```

## Rules

BUY iff RSI(1) < 30 strict; SELL iff RSI(1) > 70 (persistence valid; one
decision per closed bar via own guard; no same-bar re-entry after an
intrabar close — earliest next bar). Entry next bar; SL 25 / TP 10
server-side. Manage: at +5 pips profit move SL to entry ± 1 pip (once per
position, initial-detection latch, per-bar retry on rejection). One
position.

## Hooks

1 Filter: M15/params/warmup ≥ 10/handle. 2 Entry: above. 3 Manage: BE.
4 Exit: false. 5 News: default.

## Compliance

Registry magic (2 slots); RISK_FIXED/RISK_PERCENT; ≤1%/trade; inverted
R:R (25/10) high-WR profile + churn — Q02 judges; author 600%-claims
unaudited (card).
