---
ea_id: QM5_1186
slug: qp-comm-sma12-filter
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Quantpedia Commodity 12M SMA Filter

Source: Quantpedia, "Commodity Portfolio Strategy for a Potential 2026 Inflationary and Supply Shock Regime", published 2026-04-29, author David Mesicek / Quantpedia.

## Mechanics

Use monthly bars for approved DWX commodity proxies. At the final tradable session of each month, compute a 12-month simple moving average for each approved commodity proxy. Long each proxy whose monthly close is above its 12-month SMA. At the next monthly rebalance, close any proxy whose monthly close is at or below its 12-month SMA.

No intramonth alpha stop is specified by the source concept. The EA uses an ATR stop only for V5 risk sizing and operational containment.

## Universe Used In Build

- XAUUSD.DWX
- XAGUSD.DWX
- XTIUSD.DWX
- XNGUSD.DWX
- XCUUSD.DWX

## Constraints

- Long only.
- Rebalance once per month.
- No interpolation of unavailable commodity proxies.
- No ML, online learning, grid, martingale, or external data calls.
