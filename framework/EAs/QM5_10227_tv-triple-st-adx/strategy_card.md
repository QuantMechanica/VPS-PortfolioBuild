---
ea_id: QM5_10227
slug: tv-triple-st-adx
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/multi-filter-confirmation]]"
indicators:
  - "[[indicators/supertrend]]"
  - "[[indicators/adx]]"
  - "[[indicators/moving-average]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 35
last_updated: 2026-05-19
g0_approval_reasoning: "R1 URL+author cited; R2 mechanical triple-Supertrend/ADX/EMA entries with Supertrend reversal exits and ~35 trades/year/symbol; R3 OHLC/ATR indicators portable to DWX CFDs; R4 no ML/grid/martingale and one-position compatible."
---

# Triple Supertrend EMA ADX

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script page, "Triple Supertrend with EMA and ADX strategy" by kunjandetroja, published 2022-04-22.
- URL: https://www.tradingview.com/script/ChaVrUF9-Triple-Supertrend-with-EMA-and-ADX-strategy/

## Mechanik

### Entry
- Compute three Supertrend instances using the source/Pine defaults.
- Long entry when all three Supertrend states turn positive.
- If filters are enabled, also require ADX above the selected threshold and close above the EMA.
- Short entry mirrors long: all three Supertrends turn negative; if filters are enabled, ADX is above threshold and close is below EMA.
- Confirm signals on bar close only.

### Exit
- Exit long when the first of the three Supertrend states turns negative.
- Exit short when the first of the three Supertrend states turns positive.
- Source includes optional same-side re-entry control; P1 default should disable same-side re-entry until an opposite signal occurs to reduce churn.

### Stop Loss
- Source exit is Supertrend state reversal.
- Protective V5 default: emergency stop at 2 ATR from entry if no Supertrend exit occurs first.

### Position Sizing
- V5 fixed-risk baseline: risk USD 1,000 per P2 backtest trade.
- One open position per magic number.

### Zusätzliche Filter
- Test H1/H4 on trend-capable DWX symbols: XAUUSD.DWX, GER40.DWX, NDX.DWX, GBPJPY.DWX, EURJPY.DWX.
- Standard spread and news filters.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/multi-filter-confirmation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle kunjandetroja are cited. |
| R2 Mechanical | PASS | Triple Supertrend agreement, optional ADX/EMA filters, and first-Supertrend reversal exit are deterministic. |
| R3 Data Available | PASS | Supertrend, ADX, EMA, ATR, and OHLC are available on DWX symbols. |
| R4 ML Forbidden | PASS | No ML, neural, online-learning, grid, martingale, or adaptive-parameter component. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.
- P1: TBD.
- P2: TBD.

## Verwandte Strategien
- [[strategies/QM5_10196_tv-dual-st-macd]] - dual-Supertrend plus MACD confirmation from the same TradingView source family.

## Lessons Learned (während Pipeline-Lauf)
- TBD.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
