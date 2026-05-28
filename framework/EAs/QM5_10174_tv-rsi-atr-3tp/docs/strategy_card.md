---
ea_id: QM5_10174
slug: tv-rsi-atr-3tp
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum]]"
indicators:
  - "[[indicators/rsi]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 60
last_updated: 2026-05-19
g0_approval_reasoning: "R1 verifiable TradingView URL and author handle; R2 mechanical RSI/SMA entry, ATR stop, TP/opposite exit with ~60 trades/year/symbol; R3 portable to DWX FX/gold/index CFDs; R4 no ML/martingale."
---

# TradingView RSI ATR Three Target Trend

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `3-TP RSI-ATR Strategy [4h]`, author handle `wielkieef`, published 2026-04-24, https://www.tradingview.com/script/C2UvIzsg-3-TP-RSI-ATR-Strategy-4h/

## Mechanik

### Entry
Use H4 bars as source baseline.

- Long: RSI(14) crosses above 70 while SMA(100) > SMA(200).
- Short: RSI(14) crosses below 30 while SMA(100) < SMA(200).
- The source treats RSI extremes as momentum confirmation, not reversal.
- Enter only on bar close; source states signals and exits trigger on bar close.

### Exit
- Source has a three-level take-profit structure:
  - TP1 at +10% closes 25%.
  - TP2 at +20% closes 50%.
  - Final 25% exits on opposite RSI signal or ATR stop.
- Baseline implementation keeps one position per magic number and may model partial exits as deterministic position reductions if the framework supports them; fallback baseline uses full-position exits at TP2 or opposite RSI/ATR stop.

### Stop Loss
- ATR(14) * 1.5 from entry, below entry for longs and above entry for shorts.
- Stop is fixed at entry unless P1 source-code verification shows trailing behavior.

### Position Sizing
Source default is 75% of equity; V5 overrides this with fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Avoid low-liquidity crypto-only assumptions; test first on EURUSD.DWX, XAUUSD.DWX, NDX.DWX, and BTC-like behavior only through portable momentum mechanics.
- Standard V5 spread/news filters.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - SMA100/SMA200 regime filter
- [[concepts/momentum]] - RSI extreme breakout used as trend continuation

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `wielkieef` are cited. |
| R2 Mechanical | PASS | Source gives explicit RSI, SMA, ATR stop, three target, and opposite-signal exit rules. |
| R3 Data Available | PASS | Source says it works best on crypto majors and major forex pairs; RSI/SMA/ATR mechanics are directly testable on DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | No ML, grid, martingale, or adaptive parameters. Source percent-equity sizing is replaced by V5 fixed risk. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10118_tv-rsi-trend-cont]] - related RSI trend-continuation family, but this card uses RSI extreme crosses plus SMA100/200 and ATR/TP structure.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
