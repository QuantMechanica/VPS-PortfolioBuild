# Build-time strategy card

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20094_xng-fri-short_card.md`.

The implementation is locked to XNGUSD.DWX D1, broker Friday
`day_of_week == 5`, SELL, next-D1/one-day exit, ATR(20) x 2.75 hard stop,
2500-point spread cap, one persisted attempt per day, and RISK_FIXED backtest
sizing.
