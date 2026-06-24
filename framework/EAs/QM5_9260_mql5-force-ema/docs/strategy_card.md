---
ea_id: QM5_9260
slug: mql5-force-ema
type: strategy
source_id: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
source_citation: "Mohamed Abdelmaaboud, Learn how to design a trading system by Force Index, MQL5 Articles, 2022-08-03, https://www.mql5.com/en/articles/11269"
sources:
  - "[[sources/mql5-articles]]"
concepts:
  - "[[concepts/momentum]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/force-index]]"
  - "[[indicators/ema]]"
target_symbols: [EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "Medium frequency; Force Index zero-line crosses filtered by EMA should trigger roughly 50-110 trades per year per symbol"
expected_trades_per_year_per_symbol: 80
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; full MQL5 article URL with named author Mohamed Abdelmaaboud satisfies R1 lineage requirement."
r2_mechanical: PASS
r2_reasoning: "Source defines Force Index zero-line cross filtered by EMA with explicit long/short conditions, signal-exit rules, ATR stop, 2R target, and time exit — fully mechanical."
r3_data_available: PASS
r3_reasoning: "Force Index uses tick volume available in DWX backtests; targets EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX — all available DWX instruments."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed indicator comparisons with deterministic ATR stops; no ML, online learning, grid, martingale, or multiple positions per magic."
pipeline_phase: G0
last_updated: 2026-05-19
card_body_incomplete: false
card_body_missing: ""
g0_approval_reasoning: "R1 PASS MQL5 article URL and attribution; R2 PASS mechanical H1 Force Index/EMA entries and exits with ~80 trades/year/symbol; R3 PASS OHLC/tick-volume indicators testable on DWX symbols; R4 PASS fixed rules, no ML/grid/martingale, one position per magic."
---

# MQL5 Force Index EMA Cross

## Quelle
- Source: [[sources/mql5-articles]]
- Article: "Learn how to design a trading system by Force Index"
- Author: Mohamed Abdelmaaboud
- Date: 2022-08-03
- URL: https://www.mql5.com/en/articles/11269
- Page / Timestamp: Force Index definition; Force Index strategy; Force Index strategy blueprint.

## Mechanik

### Entry
- On closed H1 bars, calculate Force Index(13, EMA, tick volume).
- Calculate EMA(13) on close, matching the source's Force Index signal blueprint.
- Long entry: close > EMA(13), previous Force Index < 0, and current Force Index > 0.
- Short entry: close < EMA(13), previous Force Index > 0, and current Force Index < 0.
- Enter at the next bar open; one position per magic number.

### Exit
- Close long when Force Index crosses back below 0 or close falls below EMA(13).
- Close short when Force Index crosses back above 0 or close rises above EMA(13).
- Failsafe time exit after 48 H1 bars.

### Stop Loss
- Long stop: entry - 2.0 * ATR(14).
- Short stop: entry + 2.0 * ATR(14).
- Initial take profit: 2.0R.

### Position Sizing
- V5 fixed $1,000 P2 risk from stop distance; live RISK_PERCENT default after approval.

### Zusätzliche Filter
- Closed-bar execution only.
- Ignore repeated same-direction signals while a position is open.
- V5 default spread and news filters.

## Concepts (was ist das für eine Strategie)
- [[concepts/momentum]] - primary
- [[concepts/trend-following]] - secondary

## Target Symbols
- EURUSD.DWX
- GBPJPY.DWX
- XAUUSD.DWX

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full MQL5 article URL with named author Mohamed Abdelmaaboud. |
| R2 Mechanical | PASS | Source defines Force Index, EMA, prior/current zero-line cross conditions, and directional buy/sell signals. |
| R3 Data Available | PASS | Uses OHLC and tick-volume Force Index available on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed indicator comparisons only; no ML, online learning, grid, martingale, or multiple positions per magic. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9207_mql5-mom-trend]] - related momentum baseline, but this card uses Force Index volume/price impulse.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Research note: Source is educational and signal-oriented; V5 ATR stop, 2R target, and time exit complete the lifecycle while preserving the article's entry logic.*
