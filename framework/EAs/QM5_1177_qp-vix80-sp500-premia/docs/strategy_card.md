---
ea_id: QM5_1177
slug: qp-vix80-sp500-premia
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/market-timing]]"
  - "[[concepts/volatility-regime]]"
indicators:
  - "[[indicators/vix-threshold]]"
  - "[[indicators/monthly-rebalance]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Quantpedia 2024 Bansal-Stivers high-VIX equity-premia timing; R1 Bansal/Stivers 2010 SSRN URL + QP URL named-author PASS; R2 month-end VIX vs frozen 80th-percentile threshold + LONG SP500.DWX + 1mo (3mo/6mo P3 variants) holding + ATR(20)*2.5 + 10% safety-stop deterministic PASS; R3 trade leg SP500.D"
---

# Quantpedia High-VIX Equity Premia Timing

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia 2024 "Time-Varying Equity Premia with a High-VIX Threshold"
- URL: quantpedia.com/time-varying-equity-premia-with-a-high-vix-threshold/
- Named source authors: Naresh Bansal and Chris T. Stivers 2010 "Time-varying Equity Premia with a High-VIX Threshold and Sentiment", SSRN abstract 1577541; Quantpedia article (2024).
- Location: article summary and quoted paper abstract.

## Mechanik

### Entry
On the last completed trading day of each month:
1. Read a checked-in monthly VIX CSV with end-of-month VIX closes.
2. Compute whether the most recent completed month-end VIX close is above a fixed high-VIX threshold. Default: 80th percentile of the P2 in-sample VIX distribution, frozen before the backtest run.
3. If VIX is above the threshold, open LONG `SP500.DWX` on the next month open.
4. If already long, keep the position for the scheduled holding window.

### Exit
- Primary holding period: 1 calendar month; close at the next month-end if the high-VIX signal is no longer active.
- P3 variants: 3-month and 6-month holding windows, matching the source paper horizons.
- If the signal remains active at rebalance, roll the position without adding size.

### Stop Loss
- Initial stop: 2.5x ATR(20) on D1.
- Safety stop: close if SP500.DWX loses 10% from entry before scheduled exit.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter
- This draft uses the source's VIX-threshold component only. It excludes Baker-Wurgler sentiment to keep the EA deterministic and R4-compliant.
- VIX data must be a local CSV input; no live web calls.
- Threshold must be frozen per backtest configuration; no online re-optimization.

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.
