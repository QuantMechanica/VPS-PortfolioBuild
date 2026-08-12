# STR-058 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_simple-daily-3rise` · TF D1 · Symbols (slots 0-1):
GBPUSD.DWX, EURUSD.DWX. Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input double strategy_sl_buffer_pips = 2.0;
input double strategy_sl_max_pips    = 90.0;
input double strategy_p1_tp_pips     = 30.0;
input double strategy_p2_tp_pips     = 100.0;
```

## Entry (new-D1 evaluation; own guard; NO indicators — codex-resolved
## baseline per the author's later clarifications)

LONG iff for n in {1,2,3}: Open(n) > Open(n+1) AND Close(n) > Close(n+1)
(three consecutive candles with HIGHER opens and closes — the author's
p.16 relative definition; strict). SHORT mirror (lower opens and closes).
Entry at market on the new bar. SL distance = min(|entry −
(prev-candle extreme ∓ 2 pips)|, 90 pips) applied on the correct side;
TP = entry ± 100 pips server-side (P2). One campaign; one evaluation/day.

## Manage

Half-close at +30 pips touch + BE move (initial-volume based, once;
per-bar retry latch). Runner exits at +100 TP or BE stop.

## Hooks

1 Filter: D1/params/warmup ≥ 6 bars. 2 Entry: above. 3 Manage: half/BE.
4 Exit: false. 5 News: default.

## Compliance

Registry magic (2 slots); RISK_FIXED off the min-rule SL; ≤1%/trade;
EMA-gated p.1 variant documented-unbuilt; prior-build (9966) deltas per
G0_REVIEW_T6. Frequency est. 15-40/yr/symbol.
