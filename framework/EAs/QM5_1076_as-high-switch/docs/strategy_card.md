---
ea_id: QM5_1076
slug: as-high-switch
type: strategy
source_id: 2df06de7-6a3a-5b06-9e6d-446d1a01fab9
sources:
  - "[[sources/allocate-smartly-strategies]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/tactical-asset-allocation]]"
indicators:
  - "[[indicators/rolling-high]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
card_body_incomplete: true
card_body_missing: "source_citation,period"
g0_approval_reasoning: "R1 Faber Cambria 2024 white paper PASS; R2 monthly within-5% trailing-12mo-high deterministic PASS; R3 portable to SP500/NDX/WS30/GDAXI/XAUUSD PASS; R4 fixed lookback+threshold no ML PASS"
---

# Allocate Smartly 12-Month High Switch

## Quelle
- Source: [[sources/allocate-smartly-strategies]]
- Catalogue entry: Allocate Smartly "List of Strategies", line listing "12-Month High Switch" by Mebane Faber, https://allocatesmartly.com/list-of-strategies/
- Rule reference: Allocate Smartly, "Meb Faber's 12-Month High Switch", https://allocatesmartly.com/meb-fabers-12-month-high-switch/
- Author reference: Faber, M.T. (2024) "All Time Highs", Cambria Investments white paper, URL: https://www.cambriainvestments.com/wp-content/uploads/2024/02/Cambria-AllTimeHighs.pdf

## Timeframe / Bar Period
- Rebalance bar period: MN1 (monthly end-of-month evaluation).
- Underlying lookback: 12 month-end closes (computed on D1 closes resampled to month-end).
- Target symbols: SP500.DWX (backtest only), NDX.DWX, WS30.DWX, GDAXI.DWX, XAUUSD.DWX, XTIUSD.DWX (commodity proxy).

## Mechanik

### Entry
At the close on the last trading day of each month:
- For each risky sleeve, compute the highest dividend-adjusted month-end close over the current month-end plus the prior 11 month-ends.
- Original Allocate Smartly test universe: SPY, EFA, VNQ, GLD, PDBC.
- Allocate 20% to each sleeve whose current month-end close is within 5% of its 12-month high.
- Any unallocated sleeve goes to the defensive asset, originally IEF.
- DWX port: US equity via SP500.DWX backtest-only and/or NDX.DWX/WS30.DWX; international equity via GER40.DWX or broad index proxy; gold via XAUUSD.DWX; broad commodity via oil/gold proxy; REIT and IEF require proxy decision or flat/cash treatment.

### Exit
- Hold selected positions until the next month-end.
- At the next month-end, exit any risky sleeve that is no longer within 5% of its trailing 12-month high.
- Rebalance all sleeves monthly.

### Stop Loss
- Source uses monthly rotation/high-switch exit rather than an intramonth stop.
- Build default: no strategy stop beyond framework catastrophic protection if required.

### Position Sizing
- Equal 20% target sleeve allocation across the five risky sleeves.
- Defensive allocation receives the sum of failed sleeves.
- MT5 implementation must use explicit slot/magic allocation or a single-symbol port to preserve one-position-per-magic.

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
| R1 Track Record | PASS | Allocate Smartly catalogue and rule article cite the named strategy and Faber source. |
| R2 Mechanical | PASS | The 12-month-high threshold, month-end rebalance, and defensive allocation are deterministic. |
| R3 Data Available | UNKNOWN | SP500, gold, and index/commodity proxies are testable after porting; REIT and Treasury sleeves need deterministic proxy handling. |
| R4 ML Forbidden | PASS | Fixed lookback and fixed threshold; no ML, online adaptation, grid, or martingale. |

## R3
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-16, PENDING, drafted from Allocate Smartly catalogue batch 2.

## Verwandte Strategien
- [[strategies/QM5_1071_as-gtaa5-sma]] - Faber monthly tactical allocation using SMA trend instead of 12-month-high proximity.

## Lessons Learned (waehrend Pipeline-Lauf)
- TBD

