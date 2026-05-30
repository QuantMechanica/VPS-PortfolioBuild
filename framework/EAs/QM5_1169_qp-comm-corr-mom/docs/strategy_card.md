---
ea_id: QM5_1169
slug: qp-comm-corr-mom
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
concepts:
  - commodity-momentum
  - cross-sectional-ranking
indicators:
  - correlation-filter
  - twelve-month-return-rank
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
card_body_incomplete: true
card_body_missing: source_citation,target_symbols
---

# Quantpedia Commodity Momentum With Correlation Filter

## Source

- Quantpedia encyclopedia article: How to Improve Commodity Momentum Using Intra-Market Correlation.
- Named source author: Margareta Pauchlyova, Quant Analyst, Quantpedia.
- Location: Step 3 proposed strategy.
- Lineage: Erb-Harvey 2006 Financial Analysts Journal and Miffre-Rallis 2007 Journal of Banking and Finance commodity-momentum work.

## DWX Target Symbols

- Universe on D1 monthly rebalance: `XAUUSD.DWX`, `XAGUSD.DWX`, `XTIUSD.DWX`, `XNGUSD.DWX`.
- Top and bottom ranks are traded from the DWX commodity matrix.

## Mechanics

### Entry

At each month-end:

1. Use the four-symbol DWX commodity universe.
2. Compute average pairwise 20-day daily-return correlation across the universe.
3. Compute average pairwise 250-day daily-return correlation across the universe.
4. If the 20-day average correlation is greater than the 250-day average correlation, rank symbols by 12-month return.
5. Open long the top-ranked symbols and short the bottom-ranked symbols using the card baseline of two slots per side for the four-symbol universe.

### Exit

- Close and rebalance all positions at the next month-end.
- If the correlation filter is false at rebalance, close all positions and stay flat for the next month.

### Stop Loss

- Hard stop at `5.0 * ATR(D1,20)` per leg.

### Position Sizing

- Backtest: `RISK_FIXED=1000` per active slot.
- Live: `RISK_PERCENT=0.25` per active slot.

### Additional Filters

- Require at least 270 valid D1 bars for each ranked symbol.
- Minimum universe size: 4 symbols.
- Skip symbols with spread greater than `3 * median(D1 spread, 20 days)`.

## Pipeline

- G0: approved before build.

## Build Note

This local copy removes external URL syntax so `build_check.ps1` stays inside the V5 no-external-runtime boundary. The approved source card remains unchanged.
