---
ea_id: QM5_1071
slug: as-gtaa5-sma
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
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
card_body_incomplete: true
card_body_missing: "period"
g0_approval_reasoning: "AS Faber GTAA5 10mo SMA - R1 Allocate Smartly catalogue + Faber 2007 SSRN paper attributed; R2 monthly D1-close vs SMA(10) deterministic; R3 testable on SP500/NDX/WS30 + GER40 + XAUUSD after porting (bond/REIT legs default flat/cash); R4 fixed lookback no ML no adaptive"
---

# Allocate Smartly GTAA5 10-Month SMA

## Quelle
- Source: [[sources/allocate-smartly-strategies]]
- Catalogue entry: Allocate Smartly "List of Strategies", lines listing "Global Tactical Asset Allocation 5" by Mebane Faber, https://allocatesmartly.com/list-of-strategies/
- Rule reference: Mebane Faber, "A Quantitative Approach to Tactical Asset Allocation", https://mebfaber.com/wp-content/uploads/2016/05/SSRN-id962461.pdf
- Public implementation reference: EdgeTools GTAA5, https://www.edgetools.org/portfolio-models/gtaa5-live/

## Mechanik

### Entry
- Timeframe: D1 (monthly rebalance evaluated on the D1 close of the last trading day of the month).

Monthly close evaluation per asset proxy:
- Compute 10-month SMA from month-end closes.
- If month-end close > SMA(10), asset sleeve is risk-on.
- Original GTAA5 uses five sleeves: US stocks, foreign stocks, US bonds, commodities, real estate.
- DWX port: test each sleeve as a CFD proxy where available: US equity via SP500.DWX backtest-only / NDX.DWX / WS30.DWX, foreign equity via GER40.DWX or EU index proxy, commodities via XAUUSD.DWX and/or oil CFD if available. Bond and real-estate sleeves require proxy decision; default to flat/cash for unavailable sleeves.

### Exit
- At next monthly close, if close <= SMA(10), exit that sleeve to cash/flat.
- Rebalance all active sleeves monthly.

### Stop Loss
- Source uses monthly trend exit rather than intramonth stop.
- Build default: no intramonth SL for G0 draft; P1/P2 may add framework catastrophic stop only if required by risk conventions.

### Position Sizing
- Original: equal 20% sleeve allocation for each of five assets when invested, sleeve goes to cash when not invested.
- DWX implementation must use explicit slot allocation or a single-symbol port to satisfy one-position-per-magic.

### Zusätzliche Filter
- Month-end only.
- Spread filter: framework default.
- News filter: framework default.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/tactical-asset-allocation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Allocate Smartly catalogue names the strategy and developer; Faber paper and public GTAA5 implementation are linked. |
| R2 Mechanical | PASS | Price-vs-10-month-SMA entry and monthly exit are deterministic. |
| R3 Data Available | UNKNOWN | Equity/commodity proxies are available after porting; bond/REIT sleeves need a DWX-safe proxy or flat-sleeve treatment. SP500.DWX backtest-only caveat applies for the US equity leg. |
| R4 ML Forbidden | PASS | Fixed SMA rule, no ML, no adaptive parameter updates, no grid/martingale. Multi-sleeve version requires explicit magic-slot allocation. |

## R3
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-16, PENDING, drafted from Allocate Smartly catalogue batch.

## Verwandte Strategien
- [[strategies/QM5_1072_as-gem-dualmom]] - dual momentum monthly rotation variant

## Lessons Learned (während Pipeline-Lauf)
- TBD
