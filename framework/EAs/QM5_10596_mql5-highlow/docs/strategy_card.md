---
ea_id: QM5_10596
slug: mql5-highlow
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/semaphore-signal]]"
  - "[[concepts/price-action]]"
  - "[[concepts/closed-bar-signal]]"
indicators:
  - "[[indicators/highslowssignal]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
expected_trades_per_year_per_symbol: 70
g0_approval_reasoning: "R1 public MQL5 CodeBase URL; R2 closed-bar star signal entry/opposite-star exit with ~70 trades/year/symbol; R3 AUDUSD H4 portable to DWX FX/CFDs; R4 fixed non-ML one-position rule."
---

# MQL5 HighsLowsSignal Star

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- CodeBase URL: https://www.mql5.com/en/code/2314
- Article: "Exp_HighsLowsSignal - expert for MetaTrader 5", Nikolay Kositsin, published 2014-05-19, updated 2016-11-22.
- Page / Timestamp: MQL5 CodeBase expert page describing HighsLowsSignal star direction decisions and 2013 AUDUSD H4 test.

## Mechanik

### Entry
On each completed bar:
- Load `HighsLowsSignal` custom indicator with source default parameters.
- Enter long when a bullish star of the appropriate color and direction appears on the just-closed bar.
- Enter short when a bearish star of the appropriate color and direction appears on the just-closed bar.
- The indicator's default directed-candle lookback is used initially; P3 may sweep `HowManyCandles`.
- One open position per magic number.

### Exit
- Close long when a bearish `HighsLowsSignal` star appears.
- Close short when a bullish `HighsLowsSignal` star appears.
- Fallback time stop: close after 16 completed H4 bars.

### Stop Loss
Source test did not use Stop Loss or Take Profit. Baseline catastrophic stop: `2.5 * ATR(14)` from entry.

### Position Sizing
Fixed $1,000 P2 risk equivalent, one position per symbol/magic.

### Zusätzliche Filter
- Baseline timeframe: H4, because the source test is AUDUSD H4.
- Optional P3 parameter sweep: `HowManyCandles` 2/3/4/5.

## Concepts (was ist das für eine Strategie)
- [[concepts/semaphore-signal]] - primary
- [[concepts/price-action]] - secondary
- [[concepts/closed-bar-signal]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public MQL5 CodeBase URL with named author, title, publish/update dates, and downloadable source files. |
| R2 Mechanical | PASS | Source defines direction by appearance of a star with color/direction; opposite star gives deterministic close. |
| R3 Data Available | PASS | Source test uses AUDUSD H4; High/Low/OHLC-derived rule is portable to DWX FX and CFDs. |
| R4 ML Forbidden | PASS | Fixed semaphore-price-action rule; no ML, adaptive parameters, grid, martingale, or multiple positions per magic. |

## R3
No special custom-symbol caveat. Baseline can run on DWX FX majors and crosses.

## Target symbols
- AUDUSD.DWX primary source analog.
- EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX as baseline DWX FX portability symbols.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from MQL5 CodeBase page-33 continuation batch.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_10594_mql5-beginner]] - another semaphore-color/symbol card from the same continuation area.

## Lessons Learned (während Pipeline-Lauf)
- TBD
