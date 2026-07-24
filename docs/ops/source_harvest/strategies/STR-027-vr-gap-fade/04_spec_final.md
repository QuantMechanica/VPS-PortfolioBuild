# STR-027 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_vr-gap-fade-d1` · TF D1 · Symbols (slots 0–1): NDX.DWX,
GDAXI.DWX. Base: EA_Skeleton. Distinct market/TF application vs QM5_10044
(H1 FX, Q04-FAIL).

## Inputs (group "Strategy")

```
input int strategy_min_gap_points = 100;  // provisional, NOT authorial (flagged); Q03 domain
input int strategy_sl_points      = 300;  // provisional, NOT authorial (flagged)
```

## Entry (once per new D1 bar; own static guard)

gap = Close(1) − Open(0) (Open(0) = immutable new-bar open — the only
shift-0 read, perf-allowed). |gap| > min_gap × _Point strictly, else false.
gap > 0 (open below prior close, down-gap) → BUY; gap < 0 → SELL. Market
order; req.sl = entry ∓ sl_points × _Point (AT ENTRY — house deviation from
the source's fully-deferred protection; never unprotected); req.tp = 0.
Cache the gap-closure target (= Close(1)) in a static keyed to the position.
One position; no filters.

## Manage (dynamic TP attach — 20098 pattern)

If own position with TP == 0: target = cached gap-closure level (restart
fallback: recompute from the entry deal's bar via deal history — if
unavailable, leave TP unset and log once). If market already at/beyond
target → close at market (STRATEGY_EXIT reason=gap_closed_pre_tp). Else
QM_TM_MoveTP(target) with per-bar retry latch on rejection.

## Hooks

1 NoTradeFilter: D1; params>0; ≥3 D1 bars. 2 EntrySignal: above. 3 Manage:
above. 4 ExitSignal: false. 5 NewsFilterHook: default.

## Compliance

Registry magic (2 slots); RISK_FIXED off the fixed-point SL; ≤1%/trade;
price-unit demonstration of 100/300 points per symbol goes in the card
evidence; near-continuous daily-bar gap-frequency floor risk documented
(Q02 floor rules apply).
