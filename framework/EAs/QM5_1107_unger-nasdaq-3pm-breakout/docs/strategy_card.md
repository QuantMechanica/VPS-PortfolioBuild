---
ea_id: QM5_1107
slug: unger-nasdaq-3pm-breakout
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
sources:
  - "[[sources/unger-robbins-cup]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/session-breakout]]"
indicators:
  - "[[indicators/session-close]]"
  - "[[indicators/price-level-breakout]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Unger Oct 2024 SoM 15:00 anchor breakout NDX 15:05-15:55 with Fri/Mon weekday filter + 02:00 exit: R1 article+book-ISBN, R2 fully mechanical breakout+ATR-stop, R3 NDX/WS30.DWX live-routable, R4 fixed parameters no ML"
---

# Unger Nasdaq 3PM Breakout - Final-Hour Session Trend

## Quelle
- Source: [[sources/unger-robbins-cup]] - Unger Academy Strategy of the Month article.
- Article: "Strategy of the Month: The Winner is a Trend Following Strategy on the Nasdaq (October 2024)" - https://ungeracademy.com/blog/strategy-of-the-month-the-winner-is-a-trend-following-strategy-on-the-nasdaq-october-2024
- Location: section "October 2024 Strategy of the Month: Trend-Following on the Nasdaq".
- Supporting source: *The Unger Method - Andrea Unger's Trading Method* (Unger Academy Publishing, 2nd ed. 2021, ISBN 978-8896590164).
- The article describes a Nasdaq NQ five-minute strategy that trades only 15:05-15:55 exchange time, with entries above or below levels based on the 15:00 close; it avoids long trades on Friday and short trades on Monday.

## Mechanik

Universe: NDX.DWX primary; SP500.DWX optional backtest-only; WS30.DWX robustness port. Execution timeframe M5.

### Entry
At 15:00 New York / exchange time:
1. Set `BASE = Close of the 15:00 M5 bar`.
2. Set `LONG_LEVEL = BASE * (1 + LONG_PCT)`.
3. Set `SHORT_LEVEL = BASE * (1 - SHORT_PCT)`.
4. During 15:05-15:55, place buy-stop at `LONG_LEVEL` unless day-of-week is Friday.
5. During 15:05-15:55, place sell-stop at `SHORT_LEVEL` unless day-of-week is Monday.
6. Defaults: `LONG_PCT = 0.0008`, `SHORT_PCT = 0.0008`; P3 sweep `{0.0005, 0.0008, 0.0012, 0.0016}` separately for long/short.
7. First fill cancels the opposite pending order; one trade per day.

### Exit
- If stop is not hit, close at 02:00 New York / exchange time next session, following the source.
- Optional same-session flatten at 15:55 for a stricter intraday variant; default source-faithful 02:00 exit.

### Stop Loss
- Hard stop `SL = 1.25 * ATR(14,M5)` from entry.
- Optional P3 target `TP = 2.0R`; default no TP unless selected in sweep.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25%`.

### Zusaetzliche Filter
- Trading window fixed to 15:05-15:55.
- Skip long entries on Fridays; skip short entries on Mondays.
- Source mentions PatternFast filters; first build uses no proprietary filter, then P3 may test deterministic replacements: `ATR(14,D1) percentile`, `day-of-week`, and `prior-day trend`.
- Standard V5 spread/news filters.
- One position per magic.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/session-breakout]] - primary
- [[concepts/intraday-index]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Official Unger Academy article URL plus book ISBN. |
| R2 Mechanical | UNKNOWN | 15:00 close anchor, percentage breakout levels, fixed time window, weekday filters, timed exit. |
| R3 Data Available | UNKNOWN | NDX.DWX and WS30.DWX live-routable; SP500.DWX optional backtest-only. |
| R4 ML Forbidden | UNKNOWN | Fixed parameters, no ML, no adaptive online learning, one position per magic. |

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1106_unger-nasdaq-pullback-tf]] - same market, pullback entry rather than final-hour breakout.
- [[strategies/QM5_1098_unger-sp500-pivot-trend]] - same trend-following family, pivot levels instead of 15:00 close levels.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
