# STR-073 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_sisyphus-2ma-rsi2-d1` · TF D1 · Symbols (slots 0-6):
EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, NZDUSD.DWX, USDJPY.DWX, USDCHF.DWX,
USDCAD.DWX. Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input int    strategy_ma_slow            = 200;
input int    strategy_ma_fast            = 5;
input int    strategy_rsi_period         = 2;
input double strategy_buy_level          = 5.0;
input double strategy_sell_level         = 95.0;
input int    strategy_atr_period         = 14;
input double strategy_emergency_atr_mult = 4.0;  // house catastrophe stop (unsourced, separately tagged)
```

## Rules

LONG iff Close(1) > SMA200(1) AND Close(1) < SMA5(1) AND RSI2(1) < 5
(strict; SMA = default MA type, flagged). SHORT mirror (>95). Entry at
market on the new D1 bar (own guard); SL = entry ∓ 4×ATR(1) (catastrophe
only, never moved); TP none. One position.
ExitSignal (bar-gated): long open AND High(1) >= SMA5(1) → close (the
option-1 touch exit, next-open approximation, flagged); short mirror
(Low(1) <= SMA5(1)).

## Hooks

1 Filter: D1/params/warmup ≥ 205/handles (2×iMA, iRSI, iATR). 2 Entry:
above. 3 Manage: empty. 4 ExitSignal: touch exit. 5 News: default.

## Compliance

Registry magic (7 slots); RISK_FIXED off the catastrophe stop;
≤1%/trade; frequency ~10-30/yr/symbol × 7 (diversification per source);
prior QM5_10002 not transferable.
