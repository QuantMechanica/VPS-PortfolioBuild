---
ea_id: QM5_13091
slug: xbr-vrp-proxy
status: APPROVED
source_id: TROLLE-SCHWARTZ-ENERGY-VRP-2008_XBR_PROXY
period: D1
target_symbols: [XBRUSD.DWX]
pipeline_phase: Q02
---

# XBR VRP Proxy

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/xbr-vrp-proxy_card.md`.

The EA trades `XBRUSD.DWX` on D1 only. It uses energy
variance-risk-premium literature as structural lineage but does not read option
chains, variance swap rates, futures curves, EIA data, APIs, CSV files, or news
feeds at runtime. It computes D1 realized-volatility percentile from Darwinex
OHLC, trades only in top-quartile realized-volatility regimes, fades
short-horizon return stretches back toward a slow SMA, and exits by hard ATR
stop, SMA mean-reversion, realized-volatility normalization, time, standard
news, and Friday close.

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy manifest,
T_Live, portfolio gate, or AutoTrading setting is touched. This is not a true
options VRP replication and not the existing XTI/XNG VRP proxy, Brent calendar,
Brent TSMOM/anchor/reversal, WTI event, XTI/XNG, oil-metal, XNG, index, or
commodity-RSI sleeve.

