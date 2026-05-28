---
ea_id: QM5_10230
slug: tv-ema-stoch-atr
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/pullback-continuation]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/stochastic-rsi]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 45
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL cited; R2 mechanical EMA/Stoch RSI pullback entries with ATR stop and 2R exit, ~45 trades/year/symbol; R3 testable on DWX CFDs; R4 no ML/grid/martingale and 1-pos."
---

# EMA Pullback Stoch RSI ATR

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script page, "TradePro's 2 EMA + Stoch RSI + ATR Strategy" by PtGambler, updated 2023-03-09.
- URL: https://www.tradingview.com/script/BUsgoYjm-TradePro-s-2-EMA-Stoch-RSI-ATR-Strategy/

## Mechanik

### Entry
- Compute EMA50 and EMA200.
- Compute Stochastic RSI with configurable K/D smoothing.
- Long entry when EMA50 > EMA200, close is below EMA50, Stochastic RSI has recently traded below 20, and Stochastic RSI crosses up while forming a higher low versus the prior Stoch RSI cross-up.
- Short entry when EMA50 < EMA200, close is above EMA50, Stochastic RSI has recently traded above 80, and Stochastic RSI crosses down while forming a lower high versus the prior Stoch RSI cross-down.

### Exit
- Primary exit is attached bracket risk: stop at ATR stop distance and target at 2R.
- Optional break-even transition after configurable R progress is allowed because the source added it as an option; default P2 should keep it disabled unless P3 tests it.

### Stop Loss
- ATR stop-loss from entry. P1 default: ATR(14) * 1.5 unless Pine source exposes a different default.

### Position Sizing
- V5 fixed-risk baseline: risk USD 1,000 per P2 backtest trade.
- One open position per magic number; no pyramiding.

### Zusätzliche Filter
- Recommended DWX test set: XAUUSD.DWX, NDX.DWX, GER40.DWX, GBPJPY.DWX, EURUSD.DWX.
- Default timeframe H1 for cadence; include H4 in P3 if H1 is noisy.
- Standard V5 spread and news filters.

## Concepts (was ist das für eine Strategie)
- [[concepts/pullback-continuation]] - primary
- [[concepts/trend-following]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle PtGambler are cited. |
| R2 Mechanical | PASS | EMA trend state, Stoch RSI pullback/cross conditions, ATR stop, and 2R target are explicit. |
| R3 Data Available | PASS | EMA, Stochastic RSI, ATR, and OHLC inputs are available on DWX CFDs. |
| R4 ML Forbidden | PASS | No ML, neural logic, grid, martingale, DCA, adaptive online parameter changes, or pyramiding. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.
- P1: TBD.
- P2: TBD.

## Verwandte Strategien
- [[strategies/QM5_10220_tv-3ema-stoch-atr]] - earlier EMA/Stoch/ATR trend-stack variant.

## Lessons Learned (während Pipeline-Lauf)
- TBD.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
