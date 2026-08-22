---
ea_id: QM5_1583
slug: aa-sma10-tr4-risk
expected_trades_per_year_per_symbol: 100
type: strategy
source_id: ede348b4-0fa7-5be1-baa8-09e9089b67b7
sources:
  - "[[sources/alpha-architect-blog]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/risk-on-risk-off]]"
indicators:
  - "[[indicators/ten-month-sma]]"
  - "[[indicators/four-month-return]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS source URL/title present; R2 PASS fixed SMA10M and 4-month return monthly rules; R3 PASS testable on SP500.DWX with T6 NDX/WS30 caveat; R4 PASS fixed non-ML one-position logic"
---

# Alpha Architect SMA10M plus 4-Month Return Timing

## Quelle
- Source: [[sources/alpha-architect-blog]]
- Page / Timestamp: Raymond Micaletti, "The Smart Money Indicator: A New Risk Management Tool", 2019-02-08, https://alphaarchitect.com/relative-sentiment-a-unique-market-timing-tool-that-isnt-trend-following/

## Mechanik

The article compares the Smart Money Indicator against several tactical allocation benchmarks. One benchmark is a 10-month moving-average plus 4-month total-return variant: 100% equities if both signals are positive, 50% equities / 50% bonds if one signal is positive, and 100% bonds if both signals are negative.

### Entry
- Monthly rebalance using month-end data.
- Compute 10-month SMA on the selected equity-index close series.
- Compute 4-month total return on the selected equity-index close series.
- If close > SMA(10M) and 4-month return > 0, target 100% equity-index exposure.
- If exactly one of the two signals is positive, target 50% equity-index exposure and 50% defensive/cash proxy.
- If both signals are negative, target 0% equity-index exposure and 100% defensive/cash proxy.

### Exit
- Re-evaluate monthly.
- Reduce or close equity exposure when the monthly target falls from 100% to 50% or 0%.
- Increase or re-enter equity exposure when the monthly target rises.

### Stop Loss
- Initial SL = 3.0 x ATR(20,D1) on the traded equity-index CFD.
- Monthly signal change is the primary close/rebalance rule.

### Position Sizing
- P2-baseline: `RISK_FIXED = 1000`, scaled by the target equity fraction.
- T6-live: `RISK_PERCENT = 0.5`, scaled by the target equity fraction.

### Zusätzliche Filter
- Minimum 220 daily bars or 11 monthly closes before first signal.
- Use flat/cash behavior if defensive proxy is not approved.
- One position per symbol/magic; if 50% exposure is implemented as a half-size position, do not open a second slot.
- Standard spread and news filters.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/risk-on-risk-off]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full Alpha Architect URL with named author Raymond Micaletti and publication date. |
| R2 Mechanical | PASS | Fixed 10-month SMA and 4-month total-return signals map to deterministic 100/50/0 allocation. |
| R3 Data Available | PASS | Uses only equity-index OHLC-derived signals and can be tested on SP500.DWX; live validation can use NDX.DWX or WS30.DWX. |
| R4 ML Forbidden | PASS | Fixed lookbacks and allocation buckets; no ML, adaptive parameters, grid, martingale, or unbounded positions. |

## R3
SP500.DWX can support backtest research for S&P 500 timing. NDX.DWX and WS30.DWX are live-tradable index-CFD candidates for parallel validation.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: PENDING (Batch 6 draft 2026-05-19)
- P1: -
- P2: -

## Verwandte Strategien
- [[strategies/QM5_1551_aa-tom-sma10]] - related 10-month SMA equity-index timing.

## Lessons Learned (während Pipeline-Lauf)
- TBD
