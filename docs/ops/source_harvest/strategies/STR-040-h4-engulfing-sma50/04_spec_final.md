# STR-040 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_h4-engulf-sma50-stop` · TF H4 · Symbols (slots 0-1):
EURUSD.DWX, GBPUSD.DWX (test-design; aggregation caveat in card). Base:
EA_Skeleton.

## Inputs (group "Strategy")

```
input int strategy_sma_period = 50;
```

## Rules (closed H4 bars; own new-bar guard)

Setup LONG: close(2)<open(2) AND close(1)>open(2) AND close(1)>open(1) AND
close(1)>SMA50(1) (strict). → BUY STOP @ High(1), SL = Low(1), TP = 0.
SHORT mirror (SELL STOP @ Low(1), SL = High(1)).
Pending lifecycle (Manage, new-bar gated): cancel own pending when the
position-exit condition for its direction is true (close(1) beyond SMA
against it) OR when an opposite setup forms; a NEW same-direction setup
re-places at the new bar's levels (one pending max). Gap-through-entry at
placement → skip (no chase).
ExitSignal: long open AND close(1) < SMA50(1) → close (mirror short);
bar-gated level read.
One position; a filled position blocks new pendings.

## Hooks

1 Filter: H4/params/warmup 55+/handle. 2 Entry: setup+pending.
3 Manage: pending lifecycle. 4 ExitSignal: SMA-cross close.
5 News: default.

## Compliance

Registry magic (2 slots); RISK_FIXED off the engulfing-bar SL (variable);
≤1%/trade; frequency est. 30-80/yr/symbol.
