---
ea_id: QM5_1109
slug: unger-gold-prev-session-breakout
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
sources:
  - "[[sources/unger-robbins-cup]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/session-breakout]]"
indicators:
  - "[[indicators/previous-session-high-low]]"
  - "[[indicators/session-close]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Unger Apr 2025 SoM gold prev-session H/L stop-orders M15 with ATR buffer + pre-close flatten + ATR(14) stop: R1 article+book-ISBN, R2 fully mechanical breakout, R3 XAUUSD.DWX present, R4 fixed parameters no ML"
---

# Unger Gold Previous-Session Breakout - Intraday High/Low Trigger

## Quelle
- Source: [[sources/unger-robbins-cup]] - Unger Academy Strategy of the Month article.
- Article: "Strategy of the Month (April 2025): A Trend Following Strategy on the Nasdaq Future Takes the Win" - https://ungeracademy.com/blog/strategy-of-the-month-april-2025-a-trend-following-strategy-on-the-nasdaq-future-takes-the-win
- Location: section "Trend Following Strategy on Gold (GC)".
- Supporting source: *The Unger Method - Andrea Unger's Trading Method* (Unger Academy Publishing, 2nd ed. 2021, ISBN 978-8896590164).
- The article describes a 15-minute gold trend-following strategy using the previous session high and low as long/short entry triggers, with a trading window and mandatory pre-session-end close.

## Mechanik

Universe: XAUUSD.DWX primary. Execution timeframe M15.

### Entry
Before the active trading window:
1. Compute `PREV_HIGH = high of previous defined session`.
2. Compute `PREV_LOW = low of previous defined session`.
3. Place buy-stop at `PREV_HIGH + BUFFER`.
4. Place sell-stop at `PREV_LOW - BUFFER`.
5. Default `BUFFER = 0.10 * ATR(14,M15)`; P3 sweep `{0, 0.05, 0.10, 0.20} * ATR`.
6. First fill cancels the opposite pending order; one trade per day.

### Exit
- Close all open positions before the session ends.
- Close if stop loss or optional take profit is hit first.
- Cancel unfilled orders outside the trading window.

### Stop Loss
- Hard stop `SL = 1.5 * ATR(14,M15)` from entry.
- Optional `TP = 2.5R`; default disabled for first build unless P3 selects it.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25%`.

### Zusaetzliche Filter
- Time window limits entries; default London/NY overlap for XAUUSD.DWX.
- Skip if previous session range is below 0.5x its 20-session median.
- Standard V5 spread/news filters.
- One position per magic.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/session-breakout]] - primary
- [[concepts/gold]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Official Unger Academy article URL plus book ISBN. |
| R2 Mechanical | UNKNOWN | Previous-session high/low stop orders, time window, ATR stop, pre-close flatten. |
| R3 Data Available | UNKNOWN | XAUUSD.DWX is available in the DWX symbol matrix. |
| R4 ML Forbidden | UNKNOWN | Fixed parameters, no ML/adaptive online logic, no grid/martingale, one position per magic. |

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1108_unger-gold-bb-breakout]] - same gold universe, Bollinger breakout rather than prior-session high/low.
- [[strategies/QM5_1061_unger-larry-williams-vola-breakout]] - related breakout family with open-plus-range trigger.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
