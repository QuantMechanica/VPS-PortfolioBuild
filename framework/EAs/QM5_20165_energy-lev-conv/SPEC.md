# QM5_20165_energy-lev-conv

**EA ID:** QM5_20165

## 1. Strategy Logic

Market-neutral D1 XTI/XNG convergence after a joint WTI-negative,
natural-gas-positive leverage-divergence shock. Canonical rules are in
`docs/strategy_card.md`.

## 2. Parameters

One-day returns, 120-day shock standardization, 2.0 entry z-score, 0.3 exit
z-score, beta 1.0, ATR(20) x 3 stops, and ten-day maximum hold.

## 3. Symbol Universe

Host `XTIUSD.DWX`; paired traded leg `XNGUSD.DWX`; magic slots 0 and 1.

## 4. Timeframe

D1 only.

## 5. Expected Behaviour

The EA runs on `XTIUSD.DWX` D1, trades slots 0 and 1 through
`QM_BasketOrder`, uses fixed-risk backtest sizing, closes convergence at
`abs(z)<0.3`, and enforces a ten-day maximum hold plus per-leg ATR stops.

## 6. Source Citation

Source: Kristoufek (2014), *Energy Economics* 45, 1-9,
DOI `10.1016/j.eneco.2014.06.009`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`; equal risk weight is split
across both legs. No live setfile is supplied.
