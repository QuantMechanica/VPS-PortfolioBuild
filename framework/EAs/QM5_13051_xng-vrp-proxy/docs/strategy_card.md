---
ea_id: QM5_13046
slug: xti-vrp-proxy
status: APPROVED
source_id: TROLLE-SCHWARTZ-ENERGY-VRP-2008_XTI_PROXY
period: D1
target_symbols: [XTIUSD.DWX]
pipeline_phase: Q02
---

# XTI VRP Proxy

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/xti-vrp-proxy_card.md`.

The EA trades `XTIUSD.DWX` on D1 only. It uses energy variance-risk-premium
literature as structural lineage but does not read option chains, variance swap
rates, futures curves, EIA data, APIs, CSV files, or news feeds at runtime. It
computes D1 realized-volatility percentile from Darwinex OHLC, trades only in
top-quartile realized-volatility regimes, fades short-horizon return stretches
back toward a slow SMA, and exits by hard ATR stop, SMA mean-reversion,
realized-volatility normalization, time, standard news, and Friday close.

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy manifest,
T_Live, portfolio gate, or AutoTrading setting is touched. This is not a true
options VRP replication and not any existing WTI WPSR, EIA, OPEC, IEA, COT,
rig-count, seasonality, weekday, expiry, roll, carry, oil/gas, oil/metal, VCB,
TSMOM, or RSI commodity sleeve.

