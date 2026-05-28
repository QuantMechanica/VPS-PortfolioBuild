---
ea_id: QM5_10175
slug: tv-atr-ema-vwap
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/trend-filter]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/ema]]"
  - "[[indicators/vwap]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX, WS30.DWX]
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 180
last_updated: 2026-05-19
g0_approval_reasoning: "R1 verifiable TradingView URL and author handle; R2 mechanical ATR flip, EMA/VWAP filters, ATR stop and 2R exit with ~180 trades/year/symbol; R3 DWX FX/gold/index CFDs available; R4 no ML/martingale."
---

# TradingView ATR EMA VWAP Trend

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `ATR Trend System Backtest`, author handle `TheBlessedTraderPh`, published 2026-03-15, https://www.tradingview.com/script/IzWQ271v-ATR-Trend-System-Backtest/

## Mechanik

### Entry
Use M15 as first intraday baseline; source also recommends M5 and H1.

- Build ATR trend stop line:
  - Long stop line = close - ATR(length) * multiplier.
  - Short stop line = close + ATR(length) * multiplier.
  - Trend flips bullish when price crosses above the ATR stop state.
  - Trend flips bearish when price crosses below the ATR stop state.
- Long: ATR trend flips bullish AND price > EMA(13) AND price > session VWAP.
- Short: ATR trend flips bearish AND price < EMA(13) AND price < session VWAP.
- Enter only when all three confirmations agree and no position is open.

### Exit
- Take profit at 2R by default, where R is the initial distance from entry to ATR stop.
- Exit at stop loss if price hits the ATR stop before TP.

### Stop Loss
- Initial stop uses ATR volatility from the source:
  - Long stop = entry - ATR(14) * multiplier.
  - Short stop = entry + ATR(14) * multiplier.
- Baseline multiplier: 2.0 unless P1 source-code verification finds a different default.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Use session VWAP on intraday symbols; for 24h FX/gold tests, reset VWAP at broker day open.
- Standard V5 spread/news filters.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - ATR stop flip catches trend transitions
- [[concepts/trend-filter]] - EMA13 and VWAP confirm momentum and fair-value side

## Target Symbols
- EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX, WS30.DWX

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `TheBlessedTraderPh` are cited. |
| R2 Mechanical | PASS | Source gives explicit ATR trend flip, EMA13, VWAP, ATR stop, and 2R take-profit rules. |
| R3 Data Available | PASS | Source explicitly lists Forex, gold, Nasdaq, and US30 as suitable markets; all have DWX analogs. |
| R4 ML Forbidden | PASS | No ML, grid, martingale, pyramiding, or performance-adaptive parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10151_tv-ema-vwap-scalp]] - related EMA/VWAP intraday filter, but this card uses ATR trend flip as the primary trigger.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
