---
ea_id: QM5_10195
slug: tv-st-macd-ema
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum]]"
indicators:
  - "[[indicators/supertrend]]"
  - "[[indicators/macd]]"
  - "[[indicators/ema]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 70
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL cited; R2 mechanical Supertrend/MACD/EMA entries and MACD exits with ~70 trades/year/symbol; R3 ports to DWX FX/index/gold CFDs; R4 no ML/grid/martingale and one-position."
---

# TradingView Supertrend MACD EMA

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Supertrend and MACD strategy`, author handle `angiludia`, published 2024-12-01, https://www.tradingview.com/script/lGdn6A7A/

## Mechanik

### Entry
Use H1 bars in baseline.

- Long: Supertrend direction is up, MACD line is above signal line, and close is above EMA(200).
- Short: Supertrend direction is down, MACD line is below signal line, and close is below EMA(200).
- Enter only when flat.

### Exit
- Close long when MACD line crosses below signal line.
- Close short when MACD line crosses above signal line.

### Stop Loss
- Long stop: below the lowest low of the last 10 bars, with a one-tick buffer.
- Short stop: above the highest high of the last 10 bars, with a one-tick buffer.
- If the broker minimum stop distance invalidates the swing stop, widen to 1.5 ATR(14).

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Target Symbols
EURUSD.DWX, GBPUSD.DWX, DAX.DWX, NDX.DWX, XAUUSD.DWX.

### Zusatzliche Filter
- All indicator states evaluated on closed bars.
- Disable alerts/visual signals; execution follows only the mechanical rules above.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/momentum]] - MACD signal-line confirmation

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `angiludia` are cited. |
| R2 Mechanical | PASS | Source defines long/short entry conditions, MACD reversal exits, swing-low/high stop placement, and one-open-trade control. |
| R3 Data Available | PASS | EMA, MACD, Supertrend, and OHLC swing stops are available on DWX FX, gold, oil, and index CFDs. |
| R4 ML Forbidden | PASS | No ML, grid, martingale, pyramiding, or adaptive live parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10152_tv-nq-supertrend-macd]] - related but this variant uses EMA200 trend side and MACD-line reversal exits.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD

