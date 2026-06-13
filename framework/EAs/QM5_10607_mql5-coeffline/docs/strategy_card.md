---
ea_id: QM5_10607
slug: mql5-coeffline
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/oscillator-zero-cross]]"
  - "[[concepts/histogram-breakout]]"
  - "[[concepts/closed-bar-signal]]"
indicators:
  - "[[indicators/coeffofline-true]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; named MQL5 CodeBase author (Kositsin), title, and publish/update dates cited."
r2_mechanical: PASS
r2_reasoning: "CoeffofLine_true histogram zero-cross at bar close is a fully deterministic entry; opposite-cross and time-stop are deterministic exits."
r3_data_available: PASS
r3_reasoning: "Source test is AUDUSD H4; histogram logic is portable to any DWX FX major or CFD."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed indicator signal, one position per magic, no ML, adaptive parameters, grid, or martingale."
pipeline_phase: G0
last_updated: 2026-05-22
expected_trades_per_year_per_symbol: 80
card_body_incomplete: true
card_body_missing: "target_symbols"
g0_approval_reasoning: "R1 PASS MQL5 CodeBase URL with title/author/date cited; R2 PASS deterministic completed-bar histogram zero-cross entries and opposite-cross/time/ATR exits with plausible 80 trades/year/symbol; R3 PASS AUDUSD H4 and portable DWX FX/CFD testability; R4 PASS fixed non-ML one-position-per-magic."
---

# MQL5 CoeffofLine True Histogram Breakout

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- CodeBase URL: https://www.mql5.com/en/code/1151
- Article: "Exp_CoeffofLine_true - expert for MetaTrader 5", Nikolay Kositsin, published 2012-12-10, updated 2016-11-22.
- Page / Timestamp: MQL5 CodeBase expert page describing a CoeffofLine_true histogram zero-level breakthrough signal and 2011 AUDUSD H4 test.

## Mechanik

### Entry
On each completed bar:
- Load `CoeffofLine_true` / `ColorCoeffofLine_true` custom indicator with source default parameters.
- Enter long when the histogram crosses from below zero to above zero at bar close.
- Enter short when the histogram crosses from above zero to below zero at bar close.
- One open position per symbol/magic.

### Exit
- Close long on a bearish zero-level cross.
- Close short on a bullish zero-level cross.
- Fallback time stop: close after 16 completed H4 bars.

### Stop Loss
Source test did not use Stop Loss or Take Profit. Baseline catastrophic stop: `2.5 * ATR(14)` from entry.

### Position Sizing
Fixed $1,000 P2 risk equivalent, one position per symbol/magic.

### Zusätzliche Filter
- Baseline timeframe: H4, because the source test is AUDUSD H4.
- Optional P3 sweep: H4/H6, ATR stop multiplier 2.0/2.5/3.0, with and without a 200 EMA trend filter.

## Concepts (was ist das für eine Strategie)
- [[concepts/oscillator-zero-cross]] - primary
- [[concepts/histogram-breakout]] - secondary
- [[concepts/closed-bar-signal]] - secondary

## Target symbols
AUDUSD.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX.

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public MQL5 CodeBase URL with named author, title, publish/update dates, and downloadable source files. |
| R2 Mechanical | PASS | Source states the deal signal is formed at bar close when the histogram breaks through its zero level. |
| R3 Data Available | PASS | Source test uses AUDUSD H4; histogram logic is portable to DWX FX and CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator signal; no ML, adaptive parameters, grid, martingale, or multiple positions per magic. |

## R3
No special custom-symbol caveat. Baseline can run on DWX FX majors and crosses.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from MQL5 CodeBase page-36 continuation batch.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_10602_mql5-oshma]] - prior closed-bar histogram zero-cross strategy.

## Lessons Learned (während Pipeline-Lauf)
- TBD
