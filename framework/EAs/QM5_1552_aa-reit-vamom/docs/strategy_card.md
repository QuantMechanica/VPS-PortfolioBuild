---
ea_id: QM5_1552
slug: aa-reit-vamom
type: strategy
source_id: ede348b4-0fa7-5be1-baa8-09e9089b67b7
sources:
  - "[[sources/alpha-architect-blog]]"
concepts:
  - "[[concepts/cross-sectional-momentum]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/volatility-adjusted-momentum]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id UUID present; Alpha Architect URL with named author Wesley Gray PhD and named academic paper authors satisfies R1."
r2_mechanical: PASS
r2_reasoning: "Monthly volatility-adjusted momentum ranking, top-N selection, and fixed positive-trend gate are fully deterministic; no discretionary steps."
r3_data_available: PASS
r3_reasoning: "Porting country REIT concept to DWX equity index CFD proxies (SP500.DWX, NDX.DWX, WS30.DWX, GDAXI, UK100) is explicitly permitted under R3; at least one live-tradable DWX symbol is available."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed ranking and trend rules derived solely from price history; no ML, adaptive learning, grid, or martingale; 1-pos-per-magic with slot allocation."
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 Alpha Architect URL Wesley Gray PhD+Moss/Clare/Thomas/Seaton named academic paper, R2 monthly vol-adjusted-momentum ranking top-N selection positive-trend gate fully mechanical, R3 country-REIT port to DWX equity index CFD proxies SP500/NDX/WS30/GDAXI/FCHI/UK100/JPN225 relaxed-R3 PASS, R4 fixed r"
expected_trades_per_year_per_symbol: 100
---

# Alpha Architect REIT Vol-Adjusted Momentum With Trend Filter

## Quelle
- Source: [[sources/alpha-architect-blog]]
- Page / Timestamp: Wesley Gray, PhD, "Trend Following and Momentum Strategies for Global REITs", 2015-11-20, https://alphaarchitect.com/trend-following-momentum-strategies-global-reits/

## Mechanik

The article summarizes Moss, Clare, Thomas, and Seaton's global REIT study. It ranks country REIT markets by volatility-adjusted 12-month momentum, selects top 3 or top 5 winners, and applies a trend filter so a momentum winner is held only when its own trend is positive.

### Entry
- Monthly rebalance after final daily close.
- Source universe: 15 country-level REIT indices.
- DWX port universe: major equity index CFDs as country/region risk proxies: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `FCHI.DWX`, `UK100.DWX`, `JPN225.DWX` where available.
- For each candidate, compute 12-month total return and realized volatility over the same daily window.
- Score = 12-month return / 12-month realized volatility.
- Rank descending by score.
- Select top 3 in baseline.
- For each selected symbol, compute trend = 12-month return.
- Enter long selected symbols with trend > 0.
- Hold cash for selected symbols with trend <= 0.

### Exit
- Rebalance monthly.
- Close positions that drop out of the top 3.
- Close positions whose own 12-month trend turns non-positive.
- Replace with newly selected symbols only at rebalance.

### Stop Loss
- Initial SL = 3.0 x ATR(20,D1).
- Monthly revalidation is the time stop.

### Position Sizing
- P2-baseline: `RISK_FIXED = 1000` divided across active symbols.
- T6-live: `RISK_PERCENT = 0.5` total sleeve risk, divided across active symbols.

### Zusätzliche Filter
- Minimum 260 daily bars.
- One position per symbol/magic.
- Standard spread and news filters.
- Top 5 selection is a P3 variant; top 3 is baseline.

## Concepts (was ist das für eine Strategie)
- [[concepts/cross-sectional-momentum]] - primary
- [[concepts/trend-following]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full Alpha Architect URL with named author Wesley Gray and named academic paper authors Moss, Clare, Thomas, and Seaton. |
| R2 Mechanical | PASS | Monthly volatility-adjusted momentum ranking, top-N selection, and fixed positive-trend gate. |
| R3 Data Available | UNKNOWN | Direct country REIT indices are unavailable on DWX; card proposes country index CFD proxies for a port test. |
| R4 ML Forbidden | PASS | Fixed ranking and trend rules; no ML, adaptive learning, grid, martingale, or multiple positions per magic. |

## R3
This is a port candidate. The original REIT universe is unavailable, so the test is whether the country-level volatility-adjusted momentum plus trend mechanism transfers to DWX equity index CFDs.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: PENDING (Batch 3 draft 2026-05-19)
- P1: -
- P2: -

## Verwandte Strategien
- [[strategies/QM5_1538_aa-tsmom-1-3-12]] - related monthly momentum/trend rule across broad markets.

## Lessons Learned (während Pipeline-Lauf)
- TBD
