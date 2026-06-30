---
ea_id: QM5_12826
slug: cme-gassilver-ratio
type: strategy
source_id: CME-GAS-SILVER-RELVAL-2026
source_citation: "CME Group. Henry Hub Natural Gas Futures Overview. URL https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.html; CME Group. Silver Futures Overview. URL https://www.cmegroup.com/markets/metals/precious/silver.html"
target_symbols: [XNGUSD.DWX, XAGUSD.DWX]
logical_symbol: QM5_12826_XNG_XAG_RATIO_D1
period: D1
g0_status: APPROVED
pipeline_phase: Q02
last_updated: 2026-06-30
---

# CME Natural Gas / Silver Ratio Reversion

Canonical card: `strategy-seeds/cards/cme-gassilver-ratio_card.md`.

Implementation summary: D1 two-leg basket on `XNGUSD.DWX` host and
`XAGUSD.DWX` hedge leg. The EA computes `ln(XNGUSD) - beta * ln(XAGUSD)`,
opens opposite legs at z-score extremes, exits on mean reversion, applies ATR
hard stops to each leg, and closes broken packages. Runtime data is MT5 OHLC
only; no external CME/API/runtime data.
