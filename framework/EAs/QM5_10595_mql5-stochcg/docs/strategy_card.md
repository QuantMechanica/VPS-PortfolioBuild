---
ea_id: QM5_10595
slug: mql5-stochcg
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/oscillator-cross]]"
  - "[[concepts/cycle-oscillator]]"
  - "[[concepts/closed-bar-signal]]"
indicators:
  - "[[indicators/stochastic-cg-oscillator]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
expected_trades_per_year_per_symbol: 80
g0_approval_reasoning: "R1 public MQL5 CodeBase URL; R2 closed-bar oscillator cross entry/opposite-cross exit with ~80 trades/year/symbol; R3 USDJPY H4 portable to DWX FX/CFDs; R4 fixed non-ML one-position rule."
---

# MQL5 Stochastic CG Cross

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- CodeBase URL: https://www.mql5.com/en/code/2312
- Article: "Exp_StochasticCGOscillator - expert for MetaTrader 5", Nikolay Kositsin, published 2014-05-19, updated 2023-03-29.
- Page / Timestamp: MQL5 CodeBase expert page describing StochasticCGOscillator main/signal line crossing and 2013 USDJPY H4 test.

## Mechanik

### Entry
On each completed bar:
- Load `StochasticCGOscillator` custom indicator with source default parameters.
- Enter long when the oscillator main line crosses above its signal line on the just-closed bar.
- Enter short when the oscillator main line crosses below its signal line on the just-closed bar.
- Ignore still-forming bars.
- One open position per magic number.

### Exit
- Close long when the oscillator main line crosses below its signal line.
- Close short when the oscillator main line crosses above its signal line.
- Fallback time stop: close after 12 completed H4 bars.

### Stop Loss
Source test did not use Stop Loss or Take Profit. Baseline catastrophic stop: `2.5 * ATR(14)` from entry.

### Position Sizing
Fixed $1,000 P2 risk equivalent, one position per symbol/magic.

### Zusätzliche Filter
- Baseline timeframe: H4, because the source test is USDJPY H4.
- Optional P3 filter: require cross separation on the signal bar to exceed a small epsilon to avoid flat-line duplicate crosses.

## Concepts (was ist das für eine Strategie)
- [[concepts/oscillator-cross]] - primary
- [[concepts/cycle-oscillator]] - secondary
- [[concepts/closed-bar-signal]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public MQL5 CodeBase URL with named author, title, publish/update dates, and attached EA/indicator source. |
| R2 Mechanical | PASS | Entry and exit are deterministic closed-bar crosses of the main and signal lines. |
| R3 Data Available | PASS | Source test uses USDJPY H4; rule is portable to DWX FX, metals, oil, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed oscillator-cross logic; no ML, adaptive parameters, grid, martingale, or multi-position scheme. |

## R3
No special custom-symbol caveat. Baseline can run on DWX FX majors and crosses.

## Target symbols
- USDJPY.DWX primary source analog.
- EURUSD.DWX, GBPUSD.DWX, USDCHF.DWX as baseline DWX FX portability symbols.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from MQL5 CodeBase page-33 continuation batch.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_10592_mql5-asymstoch]] - another stochastic-style closed-bar cross from the same CodeBase page.

## Lessons Learned (während Pipeline-Lauf)
- TBD
