---
ea_id: QM5_1106
slug: unger-nasdaq-pullback-tf
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
sources:
  - "[[sources/unger-robbins-cup]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/pullback]]"
indicators:
  - "[[indicators/bar-high-breakout]]"
  - "[[indicators/session-close]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Unger Academy nasdaq pullback-TF: R1 article+book-ISBN, R2 fixed M5 uptrend+pullback+ATR-stop+session-close exit, R3 NDX/WS30.DWX live-routable, R4 no ML/grid/adaptive"
---

# Unger Nasdaq Pullback Trend Following - Five-Minute Long-Only Retracement

## Quelle
- Source: [[sources/unger-robbins-cup]] - Unger Academy Nasdaq high-volatility strategy lesson.
- Article: "Winning Strategies on the Nasdaq 100: The Intraday Trend Following Approach During High Volatility" - https://ungeracademy.com/blog/trend-following-nasdaq-volatility
- Location: section "Strategy 2 - Long-Only Trend Following with Pullback on a 5-Minute Time Frame".
- Supporting source: *The Unger Method - Andrea Unger's Trading Method* (Unger Academy Publishing, 2nd ed. 2021, ISBN 978-8896590164).
- The article states that the strategy identifies an uptrend when the current high is higher than the high of a prior lookback, then waits for the following bar to close lower before entering long; all positions close intraday.

## Mechanik

Universe: NDX.DWX primary; optional SP500.DWX backtest-only and WS30.DWX live-routable robustness port. Execution timeframe M5.

### Entry
At every closed M5 bar during the U.S. cash session:
1. Compute `UPTREND = High[1] > Highest(High[2..LOOKBACK+1])`.
2. If `UPTREND` is true, arm a one-bar pullback setup for the next M5 bar.
3. LONG at market when the next closed bar has `Close[1] < Close[2]`.
4. Default `LOOKBACK = 12` bars, matching the one-hour short-term trend horizon used in related Unger Nasdaq lessons. P3 sweep `LOOKBACK in {6, 12, 18, 24}`.
5. Long-only; one trade per symbol per day; no same-day re-entry after exit.

### Exit
- Session-close exit at the last M5 bar of the U.S. cash session.
- Protective close if `Close[1] < EntryPrice - 1.5 * ATR(14,M5)`.
- Optional profit target `TP = 2.5R`; default disabled for first build.

### Stop Loss
- Hard stop `SL = 1.5 * ATR(14,M5)` from entry.
- If ATR stop is tighter than broker minimum stop distance, skip the trade.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25%`.

### Zusaetzliche Filter
- U.S. cash session only; skip first 15 minutes and final 10 minutes.
- Trade only if `ATR(14,D1) / Close` is above its 60-day median.
- Standard V5 spread and news filters.
- One position per magic.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/pullback]] - primary
- [[concepts/intraday-index]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Official Unger Academy article URL plus book ISBN. |
| R2 Mechanical | UNKNOWN | Fixed M5 uptrend condition, one-bar pullback entry, ATR stop, session exit. |
| R3 Data Available | UNKNOWN | NDX.DWX and WS30.DWX are DWX index symbols; SP500.DWX is optional backtest-only. |
| R4 ML Forbidden | UNKNOWN | No ML, no adaptive online parameters, no grid/martingale, one position per magic. |

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1099_unger-sp500-atr8-extension]] - same index trend family, but direct ATR extension instead of pullback entry.
- [[strategies/QM5_1107_unger-nasdaq-3pm-breakout]] - same Nasdaq universe, different final-hour breakout trigger.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
