---
ea_id: QM5_1246
slug: miffre-comm-mom
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
concepts:
  - cross-sectional-momentum
  - commodity-momentum
indicators:
  - rate-of-change
  - atr-stop
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "Miffre-Rallis JBF 2007 commodity x-sec momentum on 3 DWX commodities; mechanical monthly rank + ATR stop; R1-R4 PASS"
---

# Miffre-Rallis Commodity Momentum Basket

## Quelle

- Source: ssrn-financial-economics-network
- URL: ssrn.com/abstract=702281
- Named source author: Joelle Miffre and Georgios Rallis, "Momentum Strategies in Commodity Futures Markets" (Journal of Banking and Finance, 2007).
- Location: SSRN abstract states that the article tests short-term continuation and long-term reversal in commodity futures, identifies profitable momentum strategies, and finds that momentum portfolios buy backwardated contracts and sell contangoed contracts.

## Mechanik

### Entry

1. Trade the available DWX commodity mini-basket: `XAUUSD.DWX`, `XAGUSD.DWX`, `XTIUSD.DWX`.
2. On the first trading day of each month, compute each symbol's trailing 6-month return using daily closes.
3. Rank symbols by trailing 6-month return.
4. Open LONG on the highest-ranked symbol if its trailing return is positive.
5. Open SHORT on the lowest-ranked symbol if its trailing return is negative.
6. If the top and bottom symbols are the same because only one symbol has valid data, stay flat.

### Exit

- Rebalance monthly; close positions that no longer occupy the top or bottom rank.
- Close any position if its 6-month trailing return crosses through zero against the trade direction.

### Stop Loss

- Hard stop at `3.0 * ATR(D1, 20)` from entry.
- No averaging down; one position per symbol/magic.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD per active leg.
- Live: `RISK_PERCENT = 0.25` per active leg.

### Zusätzliche Filter

- Require at least 130 valid daily bars.
- Optional P3 variant: long-only top rank if short commodity CFD carry/financing is punitive.
- P3 sweep: formation window `{3, 6, 12}` months; rebalance frequency `{monthly, quarterly}`.

## Related

- `QM5_1126_moskowitz-tsmom`
- `QM5_1217_zarattini-donchian-ensemble`
