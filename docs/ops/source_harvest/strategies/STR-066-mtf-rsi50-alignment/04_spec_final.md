# STR-066 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_mtf-rsi2-align-m15` · TF M15 · Symbols (slots 0-1):
EURUSD.DWX, GBPUSD.DWX. Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input int    strategy_rsi_period = 2;
input double strategy_level      = 50.0;
input double strategy_tp_pips    = 30.0;
input double strategy_sl_pips    = 20.0;
```

## Rules

Six iRSI handles: {H4, H1, M30, M15, M5, M1}, each read at its OWN shift
1 (closed bars; D1 excluded — source-optional, variant). On each new M15
bar (own guard): LONG alignment = all six RSI(2) > 50 strict; SHORT = all
< 50. Edge trigger: aligned now AND NOT aligned at the previous M15
evaluation (cached truth). Entry next bar; SL 20 / TP 30 pips
server-side; one position; no reversal.

## Hooks

1 Filter: M15/params/per-TF warmup (each TF >= period+5 closed bars) +
6 handles/BarsCalculated. 2 Entry: alignment edge. 3 Manage: empty.
4 Exit: false. 5 News: default.

## Compliance

Registry magic (2 slots); RISK_FIXED/RISK_PERCENT; <=1%/trade; pre-edit
martingale MM excluded (hard rule); frequency est. 100-300/yr.
