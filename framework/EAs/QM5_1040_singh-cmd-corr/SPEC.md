# QM5_1040 singh-cmd-corr

## Scope

Build of approved Strategy Card `SRC06_S13`, Singh Commodity Correlation, Part 1 only.

## Runtime

- Attach to `CADJPY.DWX`, `D1`.
- Reads `XTIUSD.DWX`, `D1`, as a leading signal series.
- Uses V5 fixed-risk sizing from `RISK_FIXED`.
- No portfolio-gate or live-manifest integration.

## Entry

Oil support/resistance breakout from a prior 30-bar D1 channel with two-touch confirmation triggers the next-bar CADJPY market entry.

## Exit

Initial SL is 2 x CADJPY ATR(14). TP is 3R. A 30-day maximum hold is enforced as an operational stale-trade guard, with framework Friday close still active.

