---
ea_id: QM5_1079
slug: as-ivy-taa
type: strategy
source_id: 2df06de7-6a3a-5b06-9e6d-446d1a01fab9
sources:
  - "[[sources/allocate-smartly-strategies]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/tactical-asset-allocation]]"
indicators:
  - "[[indicators/monthly-sma]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: UNKNOWN
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 Faber 2007 SSRN-id962461 TAA paper PASS; R2 5-sleeve 10mo-SMA cash-switch deterministic PASS; R3 portable to DWX index+metals+oil basket PASS; R4 fixed SMA+monthly rebalance no ML PASS"
---

# Allocate Smartly Ivy Portfolio Tactical Overlay

## Quelle
- Source: [[sources/allocate-smartly-strategies]]
- Catalogue entry: Allocate Smartly "List of Strategies", line listing "Ivy Portfolio" by Mebane Faber, https://allocatesmartly.com/list-of-strategies/
- Author reference: Faber, M.T. (2007) "A Quantitative Approach to Tactical Asset Allocation", SSRN id962461, URL: https://mebfaber.com/wp-content/uploads/2016/05/SSRN-id962461.pdf
- Public implementation reference: BestFolio (2023) "Ivy Portfolio Strategy by Meb Faber & Eric Richardson", URL: https://bestfolio.app/strategies/ivy

## Timeframe / Bar Period
- Rebalance bar period: MN1 (monthly).
- Trend filter: 10-month SMA computed on D1 closes resampled monthly (equivalent to 200-day SMA reference).
- Target symbols: NDX.DWX, WS30.DWX, GDAXI.DWX, XAUUSD.DWX, XTIUSD.DWX, SP500.DWX (backtest only).

## Mechanik

### Entry
At each monthly rebalance:
- Define the five Ivy sleeves: US equity, international equity, REITs, US aggregate bonds, and commodities.
- Each sleeve has a 20% target allocation.
- For each sleeve, compute the 200-day SMA or monthly equivalent 10-month SMA.
- Hold the sleeve if current close is above the SMA.
- Move the sleeve to cash/flat if current close is below the SMA.
- DWX port: US equity via SP500.DWX backtest-only and/or NDX.DWX/WS30.DWX; international equity via GER40.DWX or index proxy; commodities via XAUUSD.DWX and/or oil; REIT and bond sleeves require proxy decision or flat/cash handling.

### Exit
- At the next monthly rebalance, exit any sleeve whose close is below the SMA.
- Re-enter a sleeve when it closes back above the SMA at a later monthly rebalance.

### Stop Loss
- Source uses monthly trend exit rather than an intramonth stop.
- Build default: no strategy stop beyond framework catastrophic protection if required.

### Position Sizing
- Equal 20% target per sleeve.
- Sleeve allocation is either active or cash/flat based on the trend filter.
- Multi-sleeve MT5 implementation requires explicit slot/magic allocation.

### Zusaetzliche Filter
- Month-end only.
- Spread filter: framework default.
- News filter: framework default.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/tactical-asset-allocation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Allocate Smartly catalogue names the Ivy Portfolio; public Faber paper and implementation summary are linked. |
| R2 Mechanical | PASS | Five equal sleeves with an SMA trend/cash switch are deterministic. |
| R3 Data Available | UNKNOWN | Several sleeves port to DWX proxies; REIT and bond sleeves need explicit proxy or flat-sleeve treatment. |
| R4 ML Forbidden | PASS | Fixed SMA rule and fixed rebalance schedule; no ML, adaptive parameters, grid, or martingale. |

## R3
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-16, PENDING, drafted from Allocate Smartly catalogue batch 2.

## Verwandte Strategien
- [[strategies/QM5_1071_as-gtaa5-sma]] - near-equivalent Faber timing model with similar sleeve logic.

## Lessons Learned (waehrend Pipeline-Lauf)
- TBD

