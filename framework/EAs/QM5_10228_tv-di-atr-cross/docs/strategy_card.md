---
ea_id: QM5_10228
slug: tv-di-atr-cross
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/directional-movement]]"
indicators:
  - "[[indicators/adx]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 25
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL cited; R2 DI cross entries with ATR bracket/opposite-cross exits and ~25 trades/year/symbol; R3 OHLC indicators testable on DWX CFDs; R4 no ML/grid/martingale."
---

# DI Cross With ATR Bracket

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script page, "DI Crossing Daily Straregy HulkTrading" by TheHulkTrading, published 2021-11-02.
- URL: https://www.tradingview.com/script/pAsSZCGD-di-crossing-daily-straregy-hulktrading/

## Mechanik

### Entry
- Long entry when DI+ crosses above DI-.
- Short entry when DI+ crosses below DI-.
- Use confirmed daily bars by default, matching the source's recommended timeframe.

### Exit
- Exit by bracket:
  - Stop loss at 1 ATR(14) against entry.
  - Take profit at 2 ATR(14) in favor of entry.
- If an opposite DI cross occurs before bracket exit, close the current position and permit reversal on the next confirmed signal.

### Stop Loss
- Source default: 1 * ATR(14).

### Position Sizing
- V5 fixed-risk baseline: risk USD 1,000 per P2 backtest trade.
- One open position per magic number.

### Zusätzliche Filter
- Recommended timeframe: D1 from source; H4 may be tested only if D1 cadence is too low.
- Test on trend-capable and liquid DWX CFDs: XAUUSD.DWX, GER40.DWX, NDX.DWX, GBPJPY.DWX, USDJPY.DWX.
- Standard V5 spread and news filters.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/directional-movement]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle TheHulkTrading are cited. |
| R2 Mechanical | PASS | DI cross entries and ATR stop/take-profit exits are explicit. |
| R3 Data Available | PASS | DI/ADX family and ATR are standard OHLC-derived indicators available for DWX symbols. |
| R4 ML Forbidden | PASS | No ML, adaptive learning, grid, martingale, DCA, or multi-position convention. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.
- P1: TBD.
- P2: TBD.

## Verwandte Strategien
- [[strategies/QM5_10224_tv-viop-atr-snipe]] - uses ADX/ATR as part of intraday momentum filtering.

## Lessons Learned (während Pipeline-Lauf)
- TBD.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
