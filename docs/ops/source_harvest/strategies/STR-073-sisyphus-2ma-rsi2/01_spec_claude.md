# STR-073 — Claude independent spec (pre-reconciliation)

Source: thread 574065 (Sis.yphus, ~2015). Exec TF D1. Cohort: the
source's seven USD majors — EURUSD, GBPUSD, AUDUSD, NZDUSD, USDJPY,
USDCHF, USDCAD (.DWX; source-explicit).

## Rules (option-1 exit = the results basis)

1. MA(200) and MA(5) on D1 close (type unstated → SMA default, flagged);
   RSI(2, close).
2. LONG iff Close(1) > SMA200(1) AND Close(1) < SMA5(1) AND RSI2(1) < 5
   (strict). SHORT mirror (Close < SMA200, Close > SMA5, RSI2 > 95).
3. Entry at market on the new D1 bar. One position.
4. EXIT (option 1): at the close of the candle that touches the SMA5 —
   mechanized: on a new D1 bar, if the just-closed bar touched the SMA5
   (long: High(1) >= SMA5(1); short: Low(1) <= SMA5(1)) → close at market
   (next-open approximation of the touching candle's close; flagged).
5. NO source SL/TP → HOUSE emergency stop 4×ATR(14) at entry (mandatory
   protection; 20103/20122 pattern; flagged unsourced).
6. Exit options 2+ (later pages) = variants, unbuilt.

Prior-build deltas (QM5_10002, codex T6): high-vol veto, 2.5ATR stop,
15-day time exit added — absent here.

## Inputs

```
strategy_ma_slow   = 200
strategy_ma_fast   = 5
strategy_rsi_period = 2
strategy_buy_level  = 5.0
strategy_sell_level = 95.0
strategy_atr_period = 14
strategy_emergency_atr_mult = 4.0
```

## Hooks sketch

Filter: D1/params/warmup ≥ 205/handles (2×iMA, iRSI, iATR). Entry: rules
(own new-D1 guard). Manage: empty. ExitSignal: touch-exit (bar-gated).
News: default.

## Notes

D1 mean-reversion, 7 symbols; frequency ~10-30/yr/symbol (floor safe on
most); diversification is the source's own variance argument.
