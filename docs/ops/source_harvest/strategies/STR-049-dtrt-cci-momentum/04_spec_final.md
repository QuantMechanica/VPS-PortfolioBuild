# STR-049 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_dtrt-cci-h1` · TF H1 · Symbols (slots 0-1): EURUSD.DWX,
GBPUSD.DWX. Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input int    strategy_cci_period    = 20;
input double strategy_trigger_level = 100.0;
```

## State (replay-derived; own new-bar guard)

Excursion machine per side: track whether CCI is inside a >+100 (long
side) excursion; on exit below +100, prior_peak_long := excursion peak.
Restart: replay CCI over the last 400 closed bars to rebuild prior peaks
and the in-excursion flags (bounded, perf-allowed).

## Entry

LONG iff CCI(1) > +100 (strict) AND CCI(1) > prior_peak_long AND the
current excursion has not already fired. Mirror short (CCI(1) < −100 AND
< prior_trough). Market entry; SL = Low(1) (mirror High(1)); TP =
entry + 2R server-side (R = entry − SL). Invalid geometry → skip + log.
One campaign; mark the excursion fired.

## Manage (netted half realization — 20101/20111 machinery)

Full volume + market ≥ entry + R (long; bid) → close HALF (initial-volume
based, once), move SL to breakeven (entry); per-bar retry latch on
rejection. Runner exits at the server TP (+2R) or BE stop.

## Hooks

1 Filter: H1/params/warmup ≥ 40 + handle (iCCI). 2 Entry: above.
3 Manage: above. 4 Exit: false. 5 News: default.

## Compliance

Registry magic (2 slots); RISK_FIXED off the signal-bar SL; ≤1%/trade;
frequency est. 40-100/yr/symbol.
