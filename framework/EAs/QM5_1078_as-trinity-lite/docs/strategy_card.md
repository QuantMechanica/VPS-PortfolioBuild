---
ea_id: QM5_1078
slug: as-trinity-lite
type: strategy
source_id: 2df06de7-6a3a-5b06-9e6d-446d1a01fab9
sources:
  - "[[sources/allocate-smartly-strategies]]"
concepts:
  - "[[concepts/relative-momentum]]"
  - "[[concepts/trend-following]]"
  - "[[concepts/tactical-asset-allocation]]"
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
g0_approval_reasoning: "R1 Faber Cambria 2016 Trinity white paper PASS; R2 composite 1/3/6/12mo momentum + 10mo SMA filter deterministic PASS; R3 portable to DWX index+metals+oil basket PASS; R4 fixed lookbacks no ML PASS"
---

# Allocate Smartly Trinity Portfolio Lite

## Quelle
- Source: [[sources/allocate-smartly-strategies]]
- Catalogue entry: Allocate Smartly "List of Strategies", line listing "The Trinity Portfolio" by Mebane Faber, https://allocatesmartly.com/list-of-strategies/
- Rule reference: Allocate Smartly, "Meb Faber's Trinity Portfolio (Lite)", URL: https://allocatesmartly.com/meb-fabers-trinity-portfolio-lite/
- Author reference: Faber, M.T. / Cambria (2016) "The Trinity Portfolio", Cambria white paper, URL: https://mebfaber.com/wp-content/uploads/2017/10/Trinity_WP_122816_A.pdf

## Timeframe / Bar Period
- Rebalance bar period: MN1 (monthly).
- Momentum lookbacks: 1, 3, 6, 12 month-end total returns (averaged); SMA filter: 10-month SMA on D1 closes resampled monthly.
- Target symbols: NDX.DWX, WS30.DWX, GDAXI.DWX, XAUUSD.DWX, XTIUSD.DWX, SP500.DWX (backtest only).

## Mechanik

### Entry
At each month-end:
- Define the tactical universe from the Trinity Lite implementation.
- Compute relative momentum as the average of 1, 3, 6, and 12-month total returns.
- Rank the universe by this composite momentum score.
- Select the strongest assets up to the configured concentration count.
- For each selected asset, require price above its 10-month simple moving average; if below trend, that sleeve moves to cash/flat.
- DWX port: test the same composite momentum plus 10-month SMA filter on available index, commodity, gold, and FX/CFD proxies.

### Exit
- At the next monthly rebalance, exit assets that fall out of the selected rank set or close below the 10-month SMA.
- Rebalance active sleeves monthly.

### Stop Loss
- Source uses monthly trend/rotation exit rather than an intramonth stop.
- Build default: no strategy stop beyond framework catastrophic protection if required.

### Position Sizing
- Equal weight across selected active tactical sleeves.
- Static/core sleeves in the full Trinity framework should be excluded from the first EA build unless CTO explicitly chooses a multi-sleeve allocation model.
- Multi-asset version requires explicit slot/magic allocation.

### Zusaetzliche Filter
- Month-end only.
- Spread filter: framework default.
- News filter: framework default.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/relative-momentum]] - primary
- [[concepts/trend-following]] - secondary
- [[concepts/tactical-asset-allocation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Allocate Smartly catalogue names the strategy; Allocate Smartly article and Cambria white paper are linked. |
| R2 Mechanical | PASS | Composite 1/3/6/12 momentum, rank selection, and 10-month SMA filter are deterministic. |
| R3 Data Available | UNKNOWN | Tactical sleeves can be ported to DWX index/commodity/FX proxies; exact ETF sleeve mapping needs build-time decisions. |
| R4 ML Forbidden | PASS | Fixed momentum lookbacks and fixed SMA filter; no ML, online learning, grid, or martingale. |

## R3
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-16, PENDING, drafted from Allocate Smartly catalogue batch 2.

## Verwandte Strategien
- [[strategies/QM5_1071_as-gtaa5-sma]] - Faber trend-following base model.
- [[strategies/QM5_1077_as-sector-rs]] - relative-momentum rank selection without the Trinity structure.

## Lessons Learned (waehrend Pipeline-Lauf)
- TBD

