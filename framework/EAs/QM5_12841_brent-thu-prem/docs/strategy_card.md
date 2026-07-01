# Strategy Card Copy - QM5_12841_brent-thu-prem

Canonical approved card:
`strategy-seeds/cards/approved/QM5_12841_brent-thu-prem_card.md`

This EA mechanises the Quayyum et al. crude-oil day-of-week Thursday premium
on the Brent CFD proxy `XBRUSD.DWX` at D1. It buys only on the
broker-calendar Thursday D1 bar, closes on the first subsequent D1 bar or a
one-day stale-position guard, uses a per-position ATR hard stop, and keeps
Q02 backtests in `RISK_FIXED` mode.
