# QM5_13001 XTI Export Flow Breakout

Implements `strategy-seeds/cards/xti-export-flow-brk_card.md`.

- Symbol/timeframe: `XTIUSD.DWX` D1.
- Runtime data: Darwinex MT5 OHLC, spread, broker calendar, ATR, and SMA only.
- Risk: backtest setfile uses `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Live boundary: no `T_Live`, AutoTrading, deploy manifest, portfolio gate, or live-risk artifact is touched.

## Logic

During the last business days of the broker month, enter only when the completed
D1 bar confirms a medium-term Donchian breakout with SMA trend and SMA slope.
Manage by ATR hard stop, opposite channel failure, SMA trend failure, and max
hold.
