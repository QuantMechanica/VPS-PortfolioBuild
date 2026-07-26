# QM5_20165_energy-lev-conv

Market-neutral D1 XTI/XNG convergence after a joint WTI-negative,
natural-gas-positive leverage-divergence shock. Canonical rules:
`docs/strategy_card.md`.

The EA runs on `XTIUSD.DWX` D1, trades slots 0 and 1 through
`QM_BasketOrder`, uses fixed-risk backtest sizing, closes convergence at
`abs(z)<0.3`, and enforces a ten-day maximum hold plus per-leg ATR stops.

Source: Kristoufek (2014), *Energy Economics* 45, 1-9,
DOI `10.1016/j.eneco.2014.06.009`.
