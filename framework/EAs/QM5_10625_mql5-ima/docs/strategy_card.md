---
ea_id: QM5_10625
slug: mql5-ima
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "An Expert Advisor - Index Moving Average, Vladimir Mikhailov / mvv444, MQL5 CodeBase, published 2010-07-30, updated 2016-11-22, https://www.mql5.com/en/code/149"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/ma-momentum]]"
  - "[[concepts/daily-trend]]"
indicators: [IndexMovingAverage]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: D1
expected_trade_frequency: "Daily IMA momentum threshold signals are expected to be weekly-to-monthly; conservative estimate is 15-40 trades/year/symbol."
expected_trades_per_year_per_symbol: 25
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS MQL5 CodeBase URL/title/author; R2 PASS deterministic daily IMA momentum thresholds plus bounded V5 exits and frequency estimate 25 trades/year/symbol; R3 PASS OHLC-derived IMA portable to DWX symbols; R4 PASS no ML/grid/martingale and one-position enforced."
---

# MQL5 Index Moving Average Daily Momentum

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Vladimir Mikhailov / mvv444, "An Expert Advisor - Index Moving Average", MQL5 CodeBase, published 2010-07-30, updated 2016-11-22, URL https://www.mql5.com/en/code/149.
- Source location: page defines daily-bar trading using `k=(ima0 - ima1)/abs(ima1)`, with long when `k >= 0.5` and short when `k <= -0.5`.

## Mechanik

- Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.
- Period: D1.

### Entry
- Evaluate only on the first tick of a new daily bar.
- Compute `k=(IMA_current - IMA_previous)/abs(IMA_previous)`.
- Long setup:
  - `k >= 0.5`.
  - No existing position for this symbol/magic.
- Short setup:
  - `k <= -0.5`.
  - No existing position for this symbol/magic.

### Exit
- Source manages open positions with a trailing stop parameter `take` and a loss close parameter `drop`.
- V5 baseline: fixed ATR stop plus trailing stop after favorable movement, with Friday Close enforced.

### Stop Loss
- Initial V5 baseline: `QM_StopATR(period=14, mult=2.0)` on D1.
- P3 should include source-style `drop` and `take` equivalents as bounded fixed parameters.

### Position Sizing
- V5 baseline: fixed-risk $1,000 per backtest trade, converted to lots from stop distance.
- Source risk/loss-dependent lot sizing is excluded; V5 enforces one-position-per-symbol/magic.

### Zusatzliche Filter
- Daily new-bar execution only.
- V5 default spread guard and news pause.
- Skip if the previous IMA value is zero or unavailable.

## Concepts
- [[concepts/ma-momentum]] - primary
- [[concepts/daily-trend]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable MQL5 CodeBase URL with title, author, publish date, and formula. |
| R2 Mechanical | PASS | Daily IMA momentum formula and thresholds are deterministic. |
| R3 Data Available | PASS | IMA is OHLC-derived and portable to DWX FX, metals, oil, and index CFDs. |
| R4 ML Forbidden | PASS | No ML/grid/martingale; source variable lot sizing is excluded and V5 one-position logic is enforced. |

## Pipeline-Verlauf
- G0: Pending batch review.

## Verwandte Strategien
- [[strategies/QM5_10614_mql5-3genxma]] - custom moving-average direction family.

## Lessons Learned
- TBD

---

*Research note: source includes risk/loss-based money management; card intentionally ports only the deterministic IMA signal and bounded V5 exits.*
