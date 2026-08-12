# STR-079 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_channel-ma-m15` · TF M15 · Symbols (slots 0-1): EURUSD.DWX,
GBPUSD.DWX. Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input int    strategy_ch_period  = 55;
input int    strategy_sig_period = 33;
input double strategy_delay_pips = 40.0;
input double strategy_sl_pips    = 40.0;  // author range 40-50; 40 = channel-barrier coherence
```

## Signals / entries

Handles: iMA(55, PRICE_HIGH), iMA(55, PRICE_LOW), iMA(33, PRICE_CLOSE).
LONG signal: sig crosses above the HIGH-channel on the closed bar
(strict edge); SHORT: below the LOW-channel. Signal VALID until the
opposite cross.
Entry mode at signal: distance = |close(1) − nearer channel line|;
<= delay_pips → MARKET entry next bar; else DELAYED: pending LIMIT at
the current EMA33 value, refreshed to the new EMA33 each closed bar
while the signal stays valid (Manage lifecycle), cancelled on signal
invalidation. SL 40 pips; TP none. One position.

## Exit / reverse

ExitSignal (bar-gated): opposite signal confirmed → close. After the
close, the reverse routes through the SAME normal/delayed workflow
(market if normal-class, armed pending if delayed-class) — implemented
as the new signal state simply being active for EntrySignal/Manage.

## Hooks

1 Filter: M15/params/warmup >= 60/handles. 2 Entry: signal+mode.
3 Manage: delayed-pending refresh/cancel. 4 ExitSignal: opposite-signal
close. 5 News: default.

## Compliance

Registry magic (2 slots); RISK_FIXED off the 40-pip SL; <=1%/trade;
fixed-40/BE and 210/session modes = card variants; frequency est.
100-200/yr/symbol.
