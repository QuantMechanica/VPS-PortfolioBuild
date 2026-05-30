---
ea_id: QM5_10470
slug: mql5-adxmacd
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum-confirmation]]"
indicators:
  - "[[indicators/adx]]"
  - "[[indicators/macd]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 40
last_updated: 2026-05-21
g0_approval_reasoning: "R1 source URL present; R2 mechanical ADX/MACD entry-exit with ~40 trades/year/symbol; R3 indicators testable on DWX symbols; R4 no ML/grid/martingale and one-position baseline."
---

# MQL5 ADX MACD Deev

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Page / Timestamp: MQL5 CodeBase, "ADX MACD Deev - expert for MetaTrader 5", idea by Dmitry, code by Vladimir Karputov / barabashkakvn, published 2019-02-07, https://www.mql5.com/en/code/23595

## Mechanik

### Entry
- Baseline symbols: liquid DWX FX majors, XAUUSD.DWX, and liquid index CFDs.
- Timeframe: H1 baseline; M30/H4 variants can be swept.
- Long setup:
  - MACD main and signal lines have moved upward for the configured MACD bars interval.
  - ADX main line has moved upward for the configured ADX bars interval.
  - ADX main line is above 20.
  - Enter long at market on the next bar.
- Short setup:
  - MACD main and signal lines have moved downward for the configured MACD bars interval.
  - ADX main line has moved upward for the configured ADX bars interval.
  - ADX main line is above 20.
  - Enter short at market on the next bar.

### Exit
- Source implements half-profit and trailing; V5 baseline disables partial closes for one-position simplicity.
- Baseline TP = 2R.
- Close on opposite full setup if it appears first.

### Stop Loss
- V5 baseline: SL = 1.5 x ATR(14), unless source-code fixed SL default is adopted during build review.

### Position Sizing
- V5 baseline: fixed-risk $1,000 per backtest trade.
- Live sizing deferred to V5 risk conventions.

### Zusätzliche Filter
- One-position-per-magic.
- Take-half-profit option disabled in baseline.
- V5 default spread guard.
- No grid, martingale, or performance-adaptive sizing.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/momentum-confirmation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable MQL5 CodeBase page with title, author attribution, publish date, and URL. |
| R2 Mechanical | PASS | Source defines ADX strength and MACD direction conditions over fixed bar intervals plus ADX minimum 20. |
| R3 Data Available | PASS | ADX, MACD, and OHLC data are available on DWX symbols. |
| R4 ML Forbidden | PASS | No ML, online adaptation, grid, or martingale; partial-close feature is disabled for V5 baseline. |

## Pipeline-Verlauf
- G0: Pending batch review.

## Verwandte Strategien
- [[strategies/QM5_10454_mql5-supermac]] - prior MACD-confirmed trend card.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Research note: expected cadence assumes H1 MACD direction plus ADX>20 filter across liquid symbols.*
