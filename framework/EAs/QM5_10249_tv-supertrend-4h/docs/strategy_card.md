---
ea_id: QM5_10249
slug: tv-supertrend-4h
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/volatility-stop]]"
indicators:
  - "[[indicators/supertrend]]"
  - "[[indicators/atr]]"
  - "[[indicators/rsi]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 50
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS: exact TradingView URL/author cited; R2 PASS: SuperTrend flip entries, ATR stop, partial/BE and flip exits with ~50 trades/year/symbol; R3 PASS: OHLC/ATR/RSI testable on DWX CFDs after porting; R4 PASS: fixed-rule non-ML one-position logic."
---

# Simple SuperTrend 4H Runner

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script page, "Simple SuperTrend Strategy for BTCUSD 4H" by StrategiesForEveryone, updated 2023-03-14.
- URL: https://www.tradingview.com/script/N0nYQBlh/

## Mechanik

### Entry
- Calculate SuperTrend and ATR stop-loss line.
- Long entry when SuperTrend changes from downtrend to uptrend.
- Short entry when SuperTrend changes from uptrend to downtrend.
- Re-entry variant from release notes: if a position was closed at break-even while SuperTrend still points in the same direction, re-enter when RSI crosses out of the relevant extreme zone:
  - Long re-entry when SuperTrend remains up and RSI crosses above oversold.
  - Short re-entry when SuperTrend remains down and RSI crosses below overbought.

### Exit
- Close half of the position at 0.75R.
- Move stop to break-even after the partial take profit.
- Close remaining long when SuperTrend flips to downtrend or break-even stop is hit.
- Close remaining short when SuperTrend flips to uptrend or break-even stop is hit.

### Stop Loss
- Initial stop: source ATR stop-loss line.
- Partial target: 0.75R.
- Break-even: entry price after first target.

### Position Sizing
- V5 fixed-risk baseline: risk USD 1,000 per P2 backtest trade.
- One open position per magic number.
- Source percent-risk sizing is replaced with fixed-risk baseline.

### Zusätzliche Filter
- Baseline timeframe: H4, as source-designed; optional P3 tests M30/H1 for FX/index cadence.
- Best DWX ports: BTCUSD.DWX if available, XAUUSD.DWX, XTIUSD.DWX, NDX.DWX, GER40.DWX, EURUSD.DWX.
- Standard V5 spread and news filters.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/volatility-stop]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle StrategiesForEveryone are cited. |
| R2 Mechanical | PASS | SuperTrend flip entries, ATR stop, 0.75R partial, break-even move, SuperTrend exit, and RSI re-entry variant are explicit. |
| R3 Data Available | PASS | OHLC, SuperTrend, ATR, RSI, and H4 bars are available on DWX CFDs after crypto-to-CFD/index/FX porting. |
| R4 ML Forbidden | PASS | No ML, neural logic, grid, martingale, DCA, pyramiding, or online parameter adaptation. Percent-risk sizing is replaced by V5 fixed risk. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.
- P1: TBD.
- P2: TBD.

## Verwandte Strategien
- [[strategies/QM5_10227_tv-triple-st-adx]] - multi-SuperTrend ADX confirmation.
- [[strategies/QM5_10111_tv-pmax-flip]] - ATR trailing-stop flip family.

## Lessons Learned (während Pipeline-Lauf)
- TBD.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
