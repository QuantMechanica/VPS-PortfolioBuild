---
ea_id: QM5_1077
slug: as-sector-rs
type: strategy
source_id: 2df06de7-6a3a-5b06-9e6d-446d1a01fab9
sources:
  - "[[sources/allocate-smartly-strategies]]"
concepts:
  - "[[concepts/relative-momentum]]"
  - "[[concepts/sector-rotation]]"
indicators:
  - "[[indicators/rate-of-change]]"
  - "[[indicators/monthly-sma]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: UNKNOWN
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 Faber SSRN 2010 RS paper PASS; R2 monthly rank top-N + optional SMA filter deterministic PASS; R3 portable to DWX index+metals+oil basket PASS; R4 fixed rank+rebalance no ML PASS"
---

# Allocate Smartly Sector Relative Strength

## Quelle
- Source: [[sources/allocate-smartly-strategies]]
- Catalogue entry: Allocate Smartly "List of Strategies", line listing "Sector Relative Strength" by Mebane Faber, https://allocatesmartly.com/list-of-strategies/
- Rule reference: Faber, M.T. (2010) "Relative Strength Strategies for Investing", SSRN-id1585517, URL: https://mebfaber.com/wp-content/uploads/2018/12/SSRN-id1585517-Relative-Strength-Strategies-for-Investing.pdf
- Public implementation reference: StockCharts ChartSchool (2018) "Faber's Sector Rotation Trading Strategy", URL: https://chartschool.stockcharts.com/table-of-contents/trading-strategies-and-models/trading-strategies/fabers-sector-rotation-trading-strategy

## Timeframe / Bar Period
- Rebalance bar period: MN1 (monthly).
- Ranking lookback: 1, 3, 6, 9, or 12 month-end total returns (D1 closes resampled monthly).
- Target symbols: NDX.DWX, WS30.DWX, GDAXI.DWX, UK100.DWX, XAUUSD.DWX, XTIUSD.DWX, SP500.DWX (backtest only).

## Mechanik

### Entry
At each monthly rebalance:
- Define a sector or sector-proxy universe.
- Compute each asset's trailing total return over a fixed lookback; Faber tests 1, 3, 6, 9, and 12-month ranking intervals.
- Rank assets by trailing return from strongest to weakest.
- Buy the top N ranked assets; default draft setting: top 3 equal weight, with N exposed for P3 sweep.
- Optional trend filter from the public implementation: only hold a selected asset if it is above its long-term SMA; otherwise allocate that sleeve to cash/flat.
- DWX port: because US sector ETFs are not native DWX instruments, test the same relative-strength mechanism on available broad indices, metals, oil, and major FX/CFD proxies.

### Exit
- At the next monthly rebalance, sell any held asset that falls out of the top N rank set or fails the trend filter.
- Rebalance surviving selected assets back to equal weight.

### Stop Loss
- Source uses monthly rank/rotation exit rather than an intramonth stop.
- Build default: no strategy stop beyond framework catastrophic protection if required.

### Position Sizing
- Equal weight across selected top-N assets.
- If no asset passes the optional trend filter, hold cash/flat.
- Multi-asset MT5 build requires explicit slot/magic allocation.

### Zusaetzliche Filter
- Monthly rebalance only.
- Spread filter: framework default.
- News filter: framework default.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/relative-momentum]] - primary
- [[concepts/sector-rotation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Allocate Smartly catalogue names the strategy and developer; Faber paper and StockCharts rule summary are linked. |
| R2 Mechanical | PASS | Monthly ranking, top-N selection, and monthly exit are deterministic. |
| R3 Data Available | UNKNOWN | Original sector ETF universe is not directly DWX-routable, but the relative-strength mechanism can be ported to DWX indices/CFDs for testing. |
| R4 ML Forbidden | PASS | Fixed ranking rules and fixed rebalance schedule; no ML, adaptive parameters, grid, or martingale. |

## R3
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-16, PENDING, drafted from Allocate Smartly catalogue batch 2.

## Verwandte Strategien
- [[strategies/QM5_1075_as-accel-dualmom]] - monthly relative momentum rotation with a smaller offensive universe.

## Lessons Learned (waehrend Pipeline-Lauf)
- TBD
