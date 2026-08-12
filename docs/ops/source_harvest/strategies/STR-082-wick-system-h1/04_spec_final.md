# STR-082 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_wick-latest-h1` · TF H1 · Symbols (slots 0-1): EURUSD.DWX,
GBPUSD.DWX. Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input double strategy_tp_pips = 50.0;
input double strategy_sl_pips = 50.0;
```

## Rules (latest-signal projection — labeled deviation
## `single_position_latest_signal`)

Per new H1 bar (own guard): lower = min(O,C)−L, upper = H−max(O,C) of
shift 1; desired = LONG if lower > upper, SHORT if lower < upper, NONE
on tie.
- Flat: enter desired at market (TP/SL 50/50 server-side).
- Position same direction as desired or desired NONE: hold unchanged
  (no add/resize/reset).
- Position opposite to desired: close, then enter desired (close-and-
  reverse; ExitSignal closes, the fresh desired state enters next
  evaluation — no same-tick reversal).

## Hooks

1 Filter: H1/params/warmup >= 3. 2 Entry: flat-path. 3 Manage: empty.
4 ExitSignal: opposite-desired close (bar-gated). 5 News: default.

## Compliance

Registry magic (2 slots); RISK_FIXED/RISK_PERCENT; <=1%/trade; the
stacked source mode documented-unbuilt; frequency moderate (~150/yr).
