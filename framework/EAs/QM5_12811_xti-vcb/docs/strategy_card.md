# XTI Volatility-Contraction Breakout Card

See `strategy-seeds/cards/approved/QM5_12811_xti-vcb_card.md` for the approved
source card. This in-EA copy exists to keep the build package self-contained.

## Identity

- EA: `QM5_12811_xti-vcb`
- Source: `BOLLINGER-BB-SQUEEZE-2001_XTI`
- Symbol/timeframe: `XTIUSD.DWX`, `D1`
- Risk mode for Q02: `RISK_FIXED`

## Mechanical Summary

Trade only after a completed D1 bar. Rank Bollinger BandWidth over a rolling
lookback; if WTI is in a low-BandWidth state, enter on a close-confirmed
Bollinger envelope breakout aligned with slow SMA slope and signal-bar close
location. Manage with fixed ATR stop/target, middle-band/trend failure exit,
and a max-hold guard.

## Non-Duplicate Summary

This is not the WTI month-opening range, expiry, EIA, OPEC, refinery, WPSR,
fixed-month, 52-week anchor, Williams box, XNG, commodity RSI, index, metal, or
ratio-basket logic already present in the V5 book.
