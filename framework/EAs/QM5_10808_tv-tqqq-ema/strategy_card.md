---
ea_id: QM5_10808
slug: tv-tqqq-ema
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "jiaxinhuang1013, TQQQ EMA Strategy, TradingView open-source strategy, published 2026-03-28, https://www.tradingview.com/script/yhKXgYZE-TQQQ-EMA-Strategy/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/moving-average-crossover]]"
indicators:
  - "[[indicators/exponential-moving-average]]"
  - "[[indicators/adx]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 30
last_updated: 2026-05-22
g0_approval_reasoning: "R1 cites TradingView URL/author; R2 has explicit EMA20/50+ADX entry, stop/target/trailing exit and ~30 trades/year/symbol; R3 portable to DWX index/FX/gold CFDs; R4 fixed-rule non-ML one-position."
---

# TradingView TQQQ EMA ADX Trend

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `TQQQ EMA Strategy`, author handle `jiaxinhuang1013`, open-source strategy, published 2026-03-28, accessed 2026-05-22, https://www.tradingview.com/script/yhKXgYZE-TQQQ-EMA-Strategy/

## Mechanik

### Entry
Use H4/D1 baseline, ported from TQQQ to NDX.DWX / WS30.DWX / GER40.DWX and FX trend basket.

- Compute EMA(20) and EMA(50), source defaults.
- Compute ADX from DMI(14,14).
- Long entry:
  - EMA(20) crosses above EMA(50).
  - ADX >= 20.
  - No open position.
- Source is long-only; V5 optional short ablation can mirror the logic only after G0 if CEO approves.

### Exit
- Take profit limit at entry * 1.30 in source-equity form.
- For CFD portability, V5 baseline translates target to +3.0 * ATR(14) or +3.0R, whichever is closer.
- Stop starts at entry * 0.95 in source-equity form.
- For CFD portability, V5 baseline translates stop to -1.0 * ATR(14) or -1.0R.
- Stepped trailing stop:
  - At +1.0R unrealized profit, move stop to breakeven.
  - At +2.0R unrealized profit, move stop to +1.0R.

### Stop Loss
- Source initial stop: entry * 0.95.
- V5 CFD baseline: ATR-normalized equivalent, capped by fixed-risk sizing.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic. Ignore source share-count/equity sizing.

### Zusatzliche Filter
- ADX >= 20 is required.
- V5 default spread/session/news filters.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - only participates when ADX confirms a trend regime.
- [[concepts/moving-average-crossover]] - EMA(20/50) crossover is the directional trigger.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `jiaxinhuang1013` are cited. |
| R2 Mechanical | PASS | Source gives explicit EMA/ADX entry, one-position filter, stop, target, and stepped trail. |
| R3 Data Available | PASS | EMA, ADX/DMI, ATR-normalized risk conversion, and OHLC are available on DWX symbols; TQQQ edge is portable to index CFDs. |
| R4 ML Forbidden | PASS | Fixed EMA/ADX and fixed step-trailing rules; no ML, grid, martingale, or online adaptation. |

## R3
Primary P2 basket: NDX.DWX, WS30.DWX, GER40.DWX, EURUSD.DWX, GBPUSD.DWX, XAUUSD.

If this is later tested primarily on SP500.DWX, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says long entry uses fast EMA crossing above slow EMA with ADX >= 20 and no open trades.
- Source says the initial stop is 5% below entry and take profit is 30% above entry.
- Source says the trailing stop moves to breakeven after 10% profit and to +10% after 20% profit.

## Parameters To Test
- Fast EMA: 10, 20, 30.
- Slow EMA: 50, 100.
- ADX threshold: 15, 20, 25.
- ATR stop equivalent: 1.0R, 1.5R.
- Target: 2.0R, 3.0R, 4.0R.
- Timeframe: H4, D1.

## Initial Risk Profile
Sparse long-only trend strategy. The original TQQQ percent stops are too equity-specific for DWX CFDs, so P2 should prioritize the ATR/R-normalized baseline and treat percent exits as source reference.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- QM5_10787 tv-ema-rsi-adx
- QM5_10785 tv-momo-200

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD

