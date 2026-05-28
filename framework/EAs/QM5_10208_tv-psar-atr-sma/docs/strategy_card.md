---
ea_id: QM5_10208
slug: tv-psar-atr-sma
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/trailing-stop]]"
indicators:
  - "[[indicators/parabolic-sar]]"
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 60
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS TradingView URL/author cited; R2 PASS PSAR/SMA entry plus ATR trailing exit with ~60 trades/year/symbol; R3 PASS portable to DWX FX/gold/index CFDs; R4 PASS fixed non-ML one-position rules."
---

# TradingView PSAR ATR SMA Trend Trail

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `PSAR with ATR Trailing Stop + SMA Filter`, author handle `kostastrovas`, published 2025-11-06, https://www.tradingview.com/script/sbDSg0RD-PSAR-with-ATR-Trailing-Stop-SMA-Filter/

## Mechanik

### Entry
Use H1 as the initial build timeframe.

- Compute SMA(100) trend filter.
- Compute Parabolic SAR with configurable start, increment, and maximum.
- Compute ATR with configurable length; baseline ATR(14).
- Long entry:
  - Close is above SMA(100).
  - PSAR flips from above price to below price.
- Short entry:
  - Close is below SMA(100).
  - PSAR flips from below price to above price.
- Ignore new signals while a position is open.

### Exit
- No fixed take profit.
- Exit long when the ATR trailing stop is hit.
- Exit short when the ATR trailing stop is hit.
- The trailing stop only moves in the position's favor.

### Stop Loss
Initial and trailing stop = 6.0 * ATR from entry in the adverse direction, updated each bar as a one-way trailing stop.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number. Source 0.5% equity risk is replaced by V5 fixed-risk sizing.

### Zusatzliche Filter
- Target symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX.
- Spread must be <= 15% of ATR stop distance.
- Optional P3 parameter sweep: SMA length 50/100/200, ATR stop 3/4.5/6, standard PSAR settings around source defaults.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - enters only with SMA trend direction after PSAR reversal.
- [[concepts/trailing-stop]] - uses ATR trailing stop to let winners run.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `kostastrovas` are cited. |
| R2 Mechanical | PASS | Source gives SMA trend filter, PSAR flip entry, and ATR trailing-stop exit. |
| R3 Data Available | PASS | PSAR, ATR, SMA, and OHLC are available on DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator rules, no ML, no grid, no martingale, one-position compatible. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView popular Pine strategy page.

## Verwandte Strategien
- [[strategies/QM5_10117_tv-ma-psar-atr-trend]] - related MA/PSAR/ATR trend family, but this card uses PSAR flip as the entry trigger and SMA solely as trend filter.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
