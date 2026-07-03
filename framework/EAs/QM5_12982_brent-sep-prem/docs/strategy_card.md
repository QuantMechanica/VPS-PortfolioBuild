---
ea_id: QM5_12982
slug: brent-sep-prem
type: strategy
strategy_id: ARENDAS-OIL-SEASON-2018_BRENT_SEP_S04
source_id: ARENDAS-OIL-SEASON-2018
source_citation: "Arendas, P., Tkacova, D. and Bukoven, J. Seasonal patterns in oil prices and their implications for investors. Journal of International Studies, 11(2), 180-192. DOI 10.14254/2071-8330.2018/11-2/12."
target_symbols: [XBRUSD.DWX]
period: D1
g0_status: APPROVED
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-03
---

# Brent September Calendar Premium

Build-time reference for `strategy-seeds/cards/brent-sep-prem_card.md`.

The EA trades only `XBRUSD.DWX` D1. It enters long during broker-calendar
September, uses a hard ATR stop, and exits on the next D1 bar, outside
September, max-hold expiry, Friday close, or the stop. Backtests use
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

No runtime external feed, ML, grid, martingale, live manifest, AutoTrading, or
portfolio gate change is part of this build.
