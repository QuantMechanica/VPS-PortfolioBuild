# QM5_13075_xti-inside-week-brk — Strategy Spec

- EA ID: `QM5_13075`
- Source: `CRABEL-WTI-WEEK-ORB-2026_S02`
- Symbol/timeframe: `XTIUSD.DWX` / D1
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`

This EA implements the approved low-frequency WTI inside-week compression
breakout. The immediately completed broker week must be contained within its
parent week. A subsequent D1 close beyond that range, with ATR buffer, SMA
trend confirmation, and close-location confirmation, opens one position per
broker week.

Positions carry broker-side ATR stop and target. They also close on a completed
D1 failed breakout, SMA failure, eight-calendar-day maximum hold, or the V5
Friday-close rule. Runtime inputs are MT5-native OHLC, ATR, SMA, spread, and
broker calendar only.

Canonical strategy rules, parameter ranges, source citation, dedup analysis,
and framework alignment are in
`strategy-seeds/cards/xti-inweek-brk_card.md`.

No live setfile or deployment artifact is part of this build.
