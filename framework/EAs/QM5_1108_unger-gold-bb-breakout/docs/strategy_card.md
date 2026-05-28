---
ea_id: QM5_1108
slug: unger-gold-bb-breakout
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
sources:
  - "[[sources/unger-robbins-cup]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/volatility-breakout]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/moving-average]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Unger Jan 2025 SoM gold BB(40,2) upper-band breakout long-only H1 with middle-band exit + ATR(14) stop + 7-session cap: R1 article+book-ISBN, R2 fully mechanical, R3 XAUUSD.DWX present, R4 fixed parameters no ML"
---

# Unger Gold Bollinger Breakout - Long-Only Upper Band Trend

## Quelle
- Source: [[sources/unger-robbins-cup]] - Unger Academy Strategy of the Month article.
- Article: "Strategy of the Month (January 2025): A Trend-Following Strategy for Gold Wins" - https://ungeracademy.com/blog/strategy-of-the-month-january-2025-a-trend-following-strategy-for-gold-wins
- Location: section "Strategy of the Month for January 2025: Trend Following on Gold Futures (GC)".
- Supporting source: *The Unger Method - Andrea Unger's Trading Method* (Unger Academy Publishing, 2nd ed. 2021, ISBN 978-8896590164).
- The article describes an intraday/short-hold gold trend-following strategy on 60-minute bars: long only when price breaks above the upper Bollinger Band, with a 40-period/2-sigma source variant and a classic 20-period/2-sigma test.

## Mechanik

Universe: XAUUSD.DWX primary. Execution timeframe H1.

### Entry
At every closed H1 bar:
1. Compute Bollinger Bands on close with `BB_PERIOD` and `BB_STD`.
2. LONG if `Close[1] > UpperBand[1]`.
3. Default source variant: `BB_PERIOD = 40`, `BB_STD = 2.0`.
4. P3 sweep also tests classic Unger/Bollinger setting `BB_PERIOD = 20`, `BB_STD = 2.0`.
5. Long-only; one position per magic.

### Exit
- Close if price retraces to or below the Bollinger middle band after the entry session: `Close[1] <= MiddleBand[1]` and `BarsSinceEntry >= 2`.
- Close on stop loss or take profit if reached.
- Time cap: close after 7 sessions, matching the source's statement that the longest trade stayed within seven sessions.

### Stop Loss
- Hard stop `SL = 2.0 * ATR(14,H1)` from entry.
- Optional `TP = 3.0R`; default enabled for P2 baseline because source describes both stop loss and take profit exits.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25%`.

### Zusaetzliche Filter
- Source mentions a PatternFast/Daily Factor compression filter. First build uses deterministic replacement: trade only if previous session range is below the 40-day median session range.
- No same-session middle-band exit on the entry session.
- Standard V5 spread/news filters.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/volatility-breakout]] - primary
- [[concepts/gold]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Official Unger Academy article URL plus book ISBN. |
| R2 Mechanical | UNKNOWN | Upper Bollinger Band entry, middle-band exit, ATR stop, time cap. |
| R3 Data Available | UNKNOWN | XAUUSD.DWX is present in the DWX symbol matrix. |
| R4 ML Forbidden | UNKNOWN | No ML, fixed Bollinger/ATR parameters, no adaptive running-PnL logic, one position per magic. |

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1063_unger-bollinger-fx-meanrev]] - Bollinger mean reversion on FX; this card is gold trend-following breakout.
- [[strategies/QM5_1097_unger-gold-intraday-bias]] - same XAUUSD universe, time-bias entry instead of upper-band breakout.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
