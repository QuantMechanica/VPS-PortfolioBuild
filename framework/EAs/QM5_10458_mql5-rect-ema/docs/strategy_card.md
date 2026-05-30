---
ea_id: QM5_10458
slug: mql5-rect-ema
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/support-resistance]]"
  - "[[concepts/trend-filter]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/sma]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 70
last_updated: 2026-05-21
g0_approval_reasoning: "R1 MQL5 CodeBase URL/title/author/date cited; R2 deterministic H1 rectangle breakout with EMA/SMA filter and fixed exits with ~70 trades/year/symbol; R3 portable to DWX FX/index CFDs; R4 no ML/grid/martingale and one-position-per-magic."
---

# MQL5 Rectangle EMA SMA Trend Levels

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Page / Timestamp: MQL5 CodeBase, "RectangleTest - expert for MetaTrader 5", author Igor Widiger, published 2023-07-29, updated 2023-11-12, https://www.mql5.com/en/code/45639

## Mechanik

### Entry
- Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, GER40.DWX, NDX.DWX.
- Timeframe: H1 baseline; M15 can be a P3 variant because the source includes a time filter and fixed point exits.
- Build a rectangle support/resistance zone from the source rectangle settings.
- Long setup:
  - Price closes above the active rectangle resistance.
  - EMA Small is above SMA Big, confirming bullish trend.
  - Enter long on the first confirmed close outside the rectangle.
- Short setup:
  - Price closes below the active rectangle support.
  - EMA Small is below SMA Big, confirming bearish trend.
  - Enter short on the first confirmed close outside the rectangle.
- If source code defaults are not exposed to the builder, baseline uses EMA(20), SMA(50), and a 20-bar rectangle lookback.

### Exit
- Fixed TP Points from the source are mapped to a V5 2R take-profit.
- Opposite rectangle break closes any open position before considering reversal.
- Friday Close enforced by framework default.

### Stop Loss
- SL Points from the source are mapped to max(1.5 x ATR(14), opposite rectangle boundary).
- Stop Loss of Day is treated as a no-trade kill limit for the symbol/magic.

### Position Sizing
- V5 baseline: fixed-risk $1,000 per backtest trade.
- Live sizing deferred to V5 risk conventions.

### Zusätzliche Filter
- Use source time filter as a session gate.
- V5 default spread guard.
- One-position-per-magic.

## Concepts (was ist das für eine Strategie)
- [[concepts/support-resistance]] - primary
- [[concepts/trend-filter]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable MQL5 CodeBase page with title, named author, publish and update dates, and URL. |
| R2 Mechanical | PASS | Rectangle breakout plus EMA/SMA state creates deterministic directional entries; fixed point SL/TP completes the exit. |
| R3 Data Available | PASS | Uses OHLC and moving averages portable to DWX FX and index CFDs. |
| R4 ML Forbidden | PASS | No ML, no online adaptation, no grid/martingale; V5 enforces one-position-per-magic. |

## Pipeline-Verlauf
- G0: Pending batch review.

## Verwandte Strategien
- [[strategies/QM5_10456_mql5-donchian]] - earlier N-bar breakout card.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Research note: expected cadence is conservative for rectangle breakouts on H1 across liquid DWX symbols.*
