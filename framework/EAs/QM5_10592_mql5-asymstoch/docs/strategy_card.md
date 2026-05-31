---
ea_id: QM5_10592
slug: mql5-asymstoch
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/oscillator-cross]]"
  - "[[concepts/mean-reversion]]"
  - "[[concepts/closed-bar-signal]]"
indicators:
  - "[[indicators/asimmetricstochnr]]"
  - "[[indicators/stochastic]]"
target_symbols: [AUDUSD.DWX, EURUSD.DWX, USDJPY.DWX, GBPJPY.DWX]
period: H4
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
expected_trades_per_year_per_symbol: 80
g0_approval_reasoning: "R1 linked MQL5 CodeBase source; R2 closed-bar AsimmetricStochNR stochastic/signal cross entry/exit with ~80 trades/year/symbol; R3 portable to DWX FX; R4 no ML/grid/martingale and one-position baseline."
---

# MQL5 AsimmetricStochNR Cross

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- CodeBase URL: https://www.mql5.com/en/code/1279
- Article: "Exp_AsimmetricStochNR - expert for MetaTrader 5", Nikolay Kositsin, published 2013-01-30, updated 2023-03-29.
- Page / Timestamp: MQL5 CodeBase expert page describing the AsimmetricStochNR stochastic/signal-line crossing rule and 2011 AUDUSD H4 test.

## Mechanik

### Entry
On each completed bar:
- Load `AsimmetricStochNR` custom indicator with source default parameters.
- Enter long when the stochastic line crosses above its signal line on the just-closed bar.
- Enter short when the stochastic line crosses below its signal line on the just-closed bar.
- Ignore still-forming bars.
- One open position per magic number.

### Exit
- Close long when the stochastic line crosses back below the signal line.
- Close short when the stochastic line crosses back above the signal line.
- Fallback time stop: close after 12 completed H4 bars if no opposite cross appears.

### Stop Loss
Source test did not use Stop Loss or Take Profit. Baseline catastrophic stop: `2.5 * ATR(14)` from entry.

### Position Sizing
Fixed $1,000 P2 risk equivalent, one position per symbol/magic.

### Zusätzliche Filter
- Baseline timeframe: H4, because the source test is AUDUSD H4.
- Optional P3 filter: skip entries when `ATR(14) / close` is above its rolling 95th percentile.

## Concepts (was ist das für eine Strategie)
- [[concepts/oscillator-cross]] - primary
- [[concepts/mean-reversion]] - secondary
- [[concepts/closed-bar-signal]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public MQL5 CodeBase URL with named author, title, publish/update dates, and source code attachment. |
| R2 Mechanical | PASS | Entry is a deterministic closed-bar crossing of stochastic and signal lines; exit mirrors the opposite cross. |
| R3 Data Available | PASS | Source test uses AUDUSD H4; rule is portable to DWX FX, metals, oil, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed oscillator-cross rule; no ML, online adaptation, grid, martingale, or multiple positions per magic. |

## R3
No special custom-symbol caveat. Target symbols: AUDUSD.DWX, EURUSD.DWX, USDJPY.DWX, GBPJPY.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from MQL5 CodeBase page-33 continuation batch.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_10595_mql5-stochcg]] - another stochastic-style closed-bar cross from the same CodeBase page.

## Lessons Learned (während Pipeline-Lauf)
- TBD
