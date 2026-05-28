---
ea_id: QM5_10222
slug: tv-bbsr-jma-atr
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/momentum-confirmation]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/stochastic-rsi]]"
  - "[[indicators/average-true-range]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 100
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL/author; R2 mechanical Bollinger/Stochastic/JMA entries with ATR trailing exit, ~100 trades/year/symbol; R3 indicators/proxy testable on DWX CFDs; R4 fixed-rule non-ML one-position strategy."
---

# TradingView BBSR JMA ATR

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `BBSR Extreme Strategy [nachodog]`, author handle `ryanwhitham`, published 2024-04-11, updated 2024-05-03, https://www.tradingview.com/script/59farSw2-BBSR-Extreme-Strategy-nachodog/

## Target Symbols
EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX.

## Mechanik

### Entry
Long when price closes back above the lower Bollinger Band after the previous close was below the lower band, both Stochastic K and D are below the oversold threshold, and the Jurik Moving Average trend filter is green. Short when price closes back below the upper Bollinger Band after the previous close was above the upper band, both Stochastic K and D are above the overbought threshold, and the JMA trend filter is red.

### Exit
Use the source's ATR trailing stop for both directions. Also close a long on a bearish entry signal and close a short on a bullish entry signal.

### Stop Loss
Initial stop uses ATR trailing-stop level at entry. If P1 cannot reproduce JMA directly in MQL5, replace JMA with a low-lag EMA/HMA proxy only as a documented P1 implementation decision.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
Baseline uses M30/H1. The edge needs volatility and reversals; avoid very low-spread but flat overnight sessions in first tests.

## Concepts (was ist das fur eine Strategie)
- [[concepts/mean-reversion]] - enters when price reclaims an extreme Bollinger Band zone.
- [[concepts/momentum-confirmation]] - Stochastic state and JMA color gate entries.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `ryanwhitham` are cited. |
| R2 Mechanical | PASS | Source gives Bollinger/Stochastic/JMA entry conditions plus ATR trailing exit. |
| R3 Data Available | PASS | Bollinger Bands, Stochastic, ATR, OHLC, and a JMA/proxy trend filter are testable on DWX CFDs. |
| R4 ML Forbidden | PASS | Fixed technical indicators and ATR trailing stop; no ML, grid, martingale, or adaptive parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView popular Pine strategy page.

## Verwandte Strategien
- [[strategies/QM5_10207_tv-bb-wick-reversal]] - Bollinger reversal family.
- [[strategies/QM5_10197_tv-ssl-wavetrend]] - oscillator-confluence reversal family.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
