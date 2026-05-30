---
ea_id: QM5_10460
slug: mql5-cci-macd
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/momentum]]"
  - "[[concepts/trend-filter]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/cci]]"
  - "[[indicators/macd]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 85
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS MQL5 CodeBase URL/title/author; R2 PASS mechanical EMA+CCI+MACD entries with SL/TP exits and ~85 trades/year/symbol; R3 PASS EURUSD.DWX/FX testable; R4 PASS no ML/grid/martingale, one-position-per-magic."
---

# MQL5 CCI MACD EMA Scalper

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Page / Timestamp: MQL5 CodeBase, "CCI + MACD Scalper - expert for MetaTrader 5", author Dorde Milovancevic, published 2023-01-16, updated 2023-01-16, https://www.mql5.com/en/code/42283

## Mechanik

### Entry
- Source market/timeframe: EURUSD M15.
- Baseline port: EURUSD.DWX M15, then other liquid FX majors.
- Long setup:
  - Candle closes above EMA(34).
  - CCI(50) crosses upward through 0 into positive territory.
  - MACD uses default MT5 settings and makes a bullish signal-line cross while MACD is below 0.
  - Enter long on the closed M15 bar.
- Short setup:
  - Candle closes below EMA(34). The source page repeats the buy text for sells, so this mirror condition is the mechanical V5 interpretation.
  - CCI(50) crosses downward through 0 into negative territory.
  - MACD makes a bearish signal-line cross while MACD is above 0.
  - Enter short on the closed M15 bar.

### Exit
- TP at 2R for baseline.
- Close on opposite confirmed signal as a Q03 variant.
- Friday Close enforced by framework default.

### Stop Loss
- SL = 1.5 x ATR(14), capped by recent swing high/low if closer than 2.5R.

### Position Sizing
- V5 baseline: fixed-risk $1,000 per backtest trade.
- Live sizing deferred to V5 risk conventions.

### Zusätzliche Filter
- V5 default spread guard.
- Avoid first 15 minutes after session rollover.
- One-position-per-magic.

## Concepts (was ist das für eine Strategie)
- [[concepts/momentum]] - primary
- [[concepts/trend-filter]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable MQL5 CodeBase page with title, named author, publish/update dates, and URL. |
| R2 Mechanical | PASS | EMA close, CCI zero-cross, and MACD cross are deterministic; sell-side text typo is resolved by symmetric inverse rules. |
| R3 Data Available | PASS | EURUSD.DWX and standard indicator history are available. |
| R4 ML Forbidden | PASS | No ML, no adaptive parameters, no grid/martingale. |

## Pipeline-Verlauf
- G0: Pending batch review.

## Verwandte Strategien
- [[strategies/QM5_10454_mql5-supermac]] - earlier MACD/MA confirmation card.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Research note: expected cadence is conservative for M15 momentum confluence on EURUSD and major FX.*
