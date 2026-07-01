# WTI-Brent Return-Shock Fade

Approved card: `strategy-seeds/cards/wti-brent-rshock_card.md`.

This EA implements `CME-WTI-BRENT-SPREAD-2026_S03`: a D1 market-neutral
Brent/WTI basket that fades short-horizon relative-return shocks. It uses only
Darwinex MT5 OHLC and broker calendar data at runtime. Backtests use
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and the logical basket setfile.
