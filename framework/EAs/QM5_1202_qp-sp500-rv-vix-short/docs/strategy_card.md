---
ea_id: QM5_1202
slug: qp-sp500-rv-vix-short
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/volatility-filter]]"
  - "[[concepts/market-timing]]"
indicators:
  - "[[indicators/realized-volatility]]"
  - "[[indicators/vix-moving-average]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 verifiable Quantpedia URL; R2 deterministic RV vs VIX-SMA short/flat rules; R3 SP500.DWX backtest-only PASS with T6 NDX/WS30 caveat and deterministic VIX CSV; R4 fixed non-ML one-position rule."
---

# Quantpedia SP500 Realized-Vol-vs-VIX Short Hedge

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Leveraged ETFs in Low-Volatility Environments"
- Source citation: 2026 URL reference - quantpedia.com/leveraged-etfs-in-low-volatility-environments/
- Named source author: Sona Beluska, Junior Quant Analyst, Quantpedia.
- Location: SPXU in Low-Volatility Environment; source rule uses the opposite volatility condition from the SPXL rule as a selective hedge.

## Mechanik

### Entry
At each SP500.DWX D1 close:
1. Compute SP500.DWX daily returns over the last 10 trading days.
2. Annualize the 10-day realized volatility with `stdev(daily_returns_10) * sqrt(252) * 100`.
3. Read the most recent available VIX close from a versioned local CSV and compute `SMA(VIX, 60)`.
4. If `SMA(VIX, 60) < SP500_realized_vol_10d`, open or maintain SHORT SP500.DWX at the next D1 open.

### Exit
- If `SMA(VIX, 60) >= SP500_realized_vol_10d`, close any SHORT SP500.DWX at the next D1 open.
- Otherwise hold for one trading day and recompute the signal after the next close.

### Stop Loss
- Hard stop at 2.5x D1 ATR(20) from entry.
- Time/signal exit takes precedence at the next daily rebalance.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.
- This card ports the source's SPXU exposure to a direct unlevered short SP500.DWX position; no inverse ETF or 3x leverage is used.

### Zusaetzliche Filter
- Require at least 80 valid VIX observations and 40 valid SP500.DWX D1 bars before first trade.
- VIX must be read from a deterministic local CSV; EA must not call web/API live.
- Optional P3 sweep: realized-vol lookback `{5, 10}` and VIX SMA `{20, 60}`.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | UNKNOWN | Quantpedia article URL is verifiable and names Sona Beluska / Quantpedia. |
| R2 Mechanical | UNKNOWN | Daily realized-vol vs VIX-SMA comparison and short/flat action are deterministic. |
| R3 Data Available | UNKNOWN | SP500.DWX is backtest-only and VIX requires deterministic local CSV input. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. |
| R4 ML Forbidden | UNKNOWN | Fixed volatility-threshold hedge rule; no ML, neural net, online learning, grid, martingale, or PnL-adaptive parameter. |

## Pipeline-Verlauf
- G0: 2026-05-18, PENDING, awaiting QB verdict.
