# Strategy Card Copy - QM5_12849_brent-tsmom12m

Canonical approved card:
`strategy-seeds/cards/brent-tsmom12m_card.md`

This EA mechanises the Moskowitz-Ooi-Pedersen time-series-momentum premise on
the Brent CFD proxy `XBRUSD.DWX` at D1. It trades only on the first D1 bar of
each broker-calendar month, uses the sign of the prior 12-month log return for
direction, exits on monthly rebalance or a 31-day stale-position guard, uses a
per-position ATR hard stop, and keeps Q02 backtests in `RISK_FIXED` mode.
