---
ea_id: QM5_10232
slug: tv-donchian-macd
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/donchian-breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/macd]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 30
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL cited; R2 mechanical Donchian breakout plus MACD filter with 4ATR trailing exit, ~30 trades/year/symbol; R3 testable on DWX CFDs; R4 no ML/grid/martingale and 1-pos."
---

# Donchian MACD Trend Filter

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script page, "Trend Following with Donchian Channels and MACD" by LordRobrecht, updated 2022-02-07.
- URL: https://www.tradingview.com/script/bGjB7COd-Trend-Following-with-Donchian-Channels-and-MACD/

## Mechanik

### Entry
- Compute 50-bar Donchian high/low breakout levels.
- Compute MACD line and signal line.
- Long entry when price makes a new 50-day or 50-bar high, MACD line is above or crosses above the signal line, and both MACD and signal line are above zero.
- Short entry when price makes a new 50-day or 50-bar low, MACD line is below or crosses below the signal line, and both MACD and signal line are below zero.

### Exit
- Exit on ATR trailing stop.
- Reverse entry is allowed only after the opposite Donchian+MACD conditions are met; no simultaneous long/short.

### Stop Loss
- Initial and trailing stop are 4 ATRs from price per source.

### Position Sizing
- V5 fixed-risk baseline: risk USD 1,000 per P2 backtest trade.
- The source reverted pyramiding to 1; P1 must enforce one open position per magic number.

### Zusätzliche Filter
- Source describes a daily 50-day high/low system. For QM cadence, test D1 and H4 with the same 50-bar breakout length.
- Recommended symbols: XAUUSD.DWX, GER40.DWX, NDX.DWX, GBPJPY.DWX, EURJPY.DWX.
- Standard V5 spread and news filters.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/donchian-breakout]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle LordRobrecht are cited. |
| R2 Mechanical | PASS | Donchian breakout entries, MACD trend filter, and 4 ATR stop are explicit. |
| R3 Data Available | PASS | Donchian, MACD, ATR, and OHLC data are directly available on DWX CFDs. |
| R4 ML Forbidden | PASS | No ML, neural logic, grid, martingale, DCA, or adaptive parameters. Source release notes reverted pyramiding to 1. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.
- P1: TBD.
- P2: TBD.

## Verwandte Strategien
- [[strategies/QM5_9986_tv-donchian20-breakout-flip]] - earlier Donchian flip-reversal strategy.
- [[strategies/QM5_10229_tv-donchian-base]] - simpler Donchian baseline-exit variant.

## Lessons Learned (während Pipeline-Lauf)
- TBD.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
