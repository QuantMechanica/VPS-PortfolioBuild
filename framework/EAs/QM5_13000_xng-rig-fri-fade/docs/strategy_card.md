# Strategy Card Copy

Canonical card:
`strategy-seeds/cards/xng-rig-fri-fade_card.md`

This EA implements `QM5_13000_xng-rig-fri-fade`: a D1 `XNGUSD.DWX` Baker
Hughes rig-count Friday exhaustion fade. Runtime uses Darwinex MT5 OHLC,
spread, ATR, broker calendar, and V5 framework state only. Backtests use
`RISK_FIXED=1000`; no live manifest, AutoTrading setting, or portfolio gate is
touched by this build.
