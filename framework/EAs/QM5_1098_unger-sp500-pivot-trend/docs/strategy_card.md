---
ea_id: QM5_1098
slug: unger-sp500-pivot-trend
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
sources:
  - "[[sources/unger-robbins-cup]]"
concepts:
  - "[[concepts/pivot-point-breakout]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/pivot-points]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; Unger Academy URL plus supporting book ISBN cited for lineage."
r2_mechanical: PASS
r2_reasoning: "Floor-pivot formula, fixed 10:30 check, S1/R1 threshold comparison, session-close time exit, and ATR stop are all deterministic."
r3_data_available: PASS
r3_reasoning: "SP500.DWX available for backtest; NDX.DWX and WS30.DWX listed as live-routable ports per R3 porting policy."
r4_ml_forbidden: PASS
r4_reasoning: "One position per magic; fixed pivot/ATR rules; no ML, adaptive parameters, grid, or martingale."
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 source URL/book present; R2 pivot formula, fixed 10:30 entry, session/opposite exits and ATR stop mechanical; R3 SP500.DWX backtest-only with NDX/WS30 live caveat; R4 no ML/adaptive/grid and one position per magic."
expected_trades_per_year_per_symbol: 150
---

# Unger S&P Pivot-Point Trend Following - SP500 / NDX / WS30

## Quelle
- Source: [[sources/unger-robbins-cup]] - Unger Academy S&P 500 trend-following portfolio lesson.
- Article: "Here Are the Strategies We Use to Make Money When the S&P 500 Falls (Trend Following!)" - https://ungeracademy.com/blog/here-are-the-strategies-we-use-to-make-money-when-the-s-and-p-500-falls-trend-following
- Supporting source: *The Unger Method - Andrea Unger's Trading Method* (Unger Academy Publishing, 2nd ed. 2021, ISBN 978-8896590164).
- The article describes a trend-following system that goes long when Resistance 1 is crossed and short when Support 1 is crossed downward, with pivot levels calculated from the U.S. cash session.

## Mechanik

Universe: SP500.DWX primary for backtest-only S&P replication; NDX.DWX and WS30.DWX as live-routable parallel-validation ports. Execution timeframe M30.

### Entry
At 10:30 New York cash-session time, after the first two hours of regular trading:
1. Compute previous cash-session floor pivots:
   - `P = (High_prev_cash + Low_prev_cash + Close_prev_cash) / 3`
   - `R1 = 2 * P - Low_prev_cash`
   - `S1 = 2 * P - High_prev_cash`
2. LONG if `Close_current_M30 > R1`.
3. SHORT if `Close_current_M30 < S1`.
4. If price is between S1 and R1, no trade.
5. One position per symbol per day.

### Exit
- Time exit at U.S. cash-session close.
- Exit immediately if opposite pivot condition appears after entry.

### Stop Loss
- `SL = 1.5 * ATR(14,M30)` from entry.
- Optional P3 target: `TP = 2.0R`; default no TP, session-close exit.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25%`.

### Zusätzliche Filter
- Trade only U.S. cash-session days.
- Skip FOMC/CPI/NFP high-impact windows unless P8 later assigns `news_only` or `news_skip` mode.
- Skip if spread > 2x 20-day median.
- Use separate magic per symbol; no pyramiding.

## Concepts (was ist das für eine Strategie)
- [[concepts/pivot-point-breakout]] - primary
- [[concepts/trend-following]] - primary
- [[concepts/session-based]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Official Unger Academy article URL plus book ISBN. |
| R2 Mechanical | UNKNOWN | Pivot formula, fixed 10:30 check, S1/R1 breakout direction, session-close exit, ATR stop. |
| R3 Data Available | UNKNOWN | SP500.DWX is available for backtest-only; NDX.DWX/WS30.DWX are live-routable ports. |
| R4 ML Forbidden | UNKNOWN | No ML, no adaptive params, no grid/martingale, one position per magic. |

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1099_unger-sp500-atr8-extension]] - same source, ATR-extension trigger instead of pivot trigger.
- [[strategies/QM5_1045_zarattini-spy-intraday-momentum]] - SP500 intraday momentum from different source.

## Lessons Learned (während Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`.*
