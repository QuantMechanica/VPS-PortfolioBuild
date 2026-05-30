# QM5_1190_qp-index-double-bottom

## Intent

Deterministic V5 port of the approved Quantpedia index double-bottom breakout card.

## Mapping

- Universe: `SP500.DWX` research baseline, with `NDX.DWX` and `WS30.DWX` route variants for later live validation.
- Period: D1 only.
- Entry: long when the last closed D1 bar breaks above the neckline of two centered local lows separated by 5-60 sessions.
- Pattern constraints: second low within 1.0 ATR(20) of first low; neckline must stand at least 0.5 ATR(20) above the second low.
- Initial stop: second low minus 0.5 ATR(20).
- Exit: earliest of stop, 20 D1 bars after entry, or close below SMA(50).
- Positioning: one long position per symbol and magic; no pyramiding on the same detected pattern.

## Framework Alignment

- No-Trade: symbol/timeframe validation, parameter sanity, spread guard.
- Entry: local-low detection, neckline breakout, stop-distance validation, V5 risk sizing through framework request.
- Management: no trailing or partials specified by the card.
- Close: time stop or SMA(50) close-only exit; hard stop is broker-side SL.

## Scope Notes

No backtests or pipeline phases were run as part of this build.
