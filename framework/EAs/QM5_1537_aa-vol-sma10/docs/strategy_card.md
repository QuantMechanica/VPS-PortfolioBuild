---
ea_id: QM5_1537
slug: aa-vol-sma10
expected_trades_per_year_per_symbol: 100
type: strategy
source_id: ede348b4-0fa7-5be1-baa8-09e9089b67b7
sources:
  - "[[sources/alpha-architect-blog]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/high-volatility-timing]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/realized-volatility]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS Alpha Architect URL; R2 PASS deterministic high-volatility sleeve plus SMA10 entry/exit; R3 PASS daily OHLC/volatility portable to DWX CFDs incl SP500.DWX T6 caveat; R4 PASS fixed non-ML 1-pos rules."
---

# Alpha Architect High-Volatility 10-Day SMA Timing

## Quelle
- Source: [[sources/alpha-architect-blog]]
- Page / Timestamp: Wesley Gray, PhD, "Technical Analysis may actually work!", 2010-05-19, https://alphaarchitect.com/technical-analysis-may-actually-work/

## Mechanik

The article summarizes Han, Yang, and Zhou's simple moving-average timing result: high-volatility portfolios are held when price is above a 10-day SMA and moved to cash when below it. For DWX this becomes a high-realized-volatility symbol sleeve with a 10-day SMA risk-on/risk-off rule.

### Entry
- At each daily close, compute prior-year realized volatility for each candidate DWX symbol using 252 daily returns.
- Select the top volatility decile, or top 3 symbols for a smaller DWX universe.
- For selected high-volatility symbols, compute SMA(10,D1) of close.
- Long entry: if D1 close crosses above SMA(10), buy at next daily open.
- Optional short test variant: if D1 close crosses below SMA(10), sell at next daily open. Default card mode is long/cash to match source.

### Exit
- Long exit: close at next daily open after D1 close crosses below SMA(10).
- Short-variant exit: close short at next daily open after D1 close crosses above SMA(10).
- Recompute volatility sleeve monthly; close symbols that leave the high-volatility sleeve.

### Stop Loss
- Initial SL = 2.5 x ATR(14,D1).
- No trailing stop in source; optional P3 sweep can test ATR trailing after source-faithful baseline.

### Position Sizing
- P2-baseline: `RISK_FIXED = 1000` per active symbol.
- T6-live: `RISK_PERCENT = 0.5`, divided by number of active selected symbols.

### Zusätzliche Filter
- Daily-bar strategy only.
- Minimum 270 daily bars before symbol eligibility.
- Standard QM spread and news filters.
- One position per symbol/magic; no pyramiding.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/high-volatility-timing]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full Alpha Architect URL, named author Wesley Gray, named academic authors Yufeng Han, Ke Yang, and Guofu Zhou. |
| R2 Mechanical | PASS | Prior-year volatility sort plus 10-day SMA cross entry/exit are deterministic. |
| R3 Data Available | PASS | Uses daily OHLC closes and realized volatility; portable to DWX FX, metals, oil, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed volatility ranking and SMA timing; no ML, adaptive learning, martingale, or grid. |

## R3
Original universe is NYSE/AMEX stocks sorted into volatility portfolios. DWX port replaces individual stocks with a multi-asset CFD universe and uses the same high-realized-volatility selection plus SMA(10) timing.

If SP500.DWX appears in the high-volatility sleeve, live promotion T6 gate applies: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: PENDING (Batch 2 draft 2026-05-19)
- P1: -
- P2: -

## Verwandte Strategien
- [[strategies/QM5_1087_aa-spx-20-252-ma]] - prior Alpha Architect moving-average timing card.

## Lessons Learned (während Pipeline-Lauf)
- TBD
