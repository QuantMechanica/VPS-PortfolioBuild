---
ea_id: QM5_10602
slug: mql5-oshma
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
target_symbols: [NZDUSD.DWX, EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX]
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/oscillator-zero-cross]]"
  - "[[concepts/momentum-reversal]]"
  - "[[concepts/closed-bar-signal]]"
indicators:
  - "[[indicators/oshma]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; MQL5 CodeBase URL with named author Nikolay Kositsin, article title, and publish/update dates."
r2_mechanical: PASS
r2_reasoning: "Entry = OsHMA histogram zero-level cross on bar close; exit on reverse zero-cross or 16-bar time-stop; ATR catastrophic stop; all deterministic."
r3_data_available: PASS
r3_reasoning: "Source tested on NZDUSD H4; oscillator histogram logic portable to DWX FX and CFD symbols (NZDUSD.DWX, EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX)."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed indicator parameters with zero-cross rule; no ML, no adaptive params, no grid, no martingale; 1-pos-per-magic."
pipeline_phase: G0
last_updated: 2026-05-22
expected_trades_per_year_per_symbol: 80
g0_approval_reasoning: "R1 public MQL5 CodeBase URL; R2 closed-bar OsHMA zero-cross entries/exits with ~80 trades/year/symbol; R3 target DWX symbols listed and portable to FX/CFDs; R4 fixed non-ML one-position rule."
---

# MQL5 OsHMA Histogram Signal

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- CodeBase URL: https://www.mql5.com/en/code/1335
- Article: "Exp_OsHMA - expert for MetaTrader 5", Nikolay Kositsin, published 2012-12-26, updated 2023-03-29.
- Page / Timestamp: MQL5 CodeBase expert page describing OsHMA histogram zero-level breakout or direction-change mode and 2011 NZDUSD H4 test.

## Mechanik

### Entry
On each completed bar:
- Load `OsHMA` custom indicator with source default parameters.
- Baseline mode: use histogram zero-level breakthrough.
- Enter long when the OsHMA histogram crosses from below zero to above zero at bar close.
- Enter short when the OsHMA histogram crosses from above zero to below zero at bar close.
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
- Baseline timeframe: H4, because the source test is NZDUSD H4.
- Optional P3 sweep: source `Mode` zero-level breakthrough vs histogram direction-change, H4/H6 timeframes, ATR multiplier 2.0/2.5/3.0.

## Concepts (was ist das für eine Strategie)
- [[concepts/oscillator-zero-cross]] - primary
- [[concepts/momentum-reversal]] - secondary
- [[concepts/closed-bar-signal]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public MQL5 CodeBase URL with named author, title, publish/update dates, and downloadable source files. |
| R2 Mechanical | PASS | Source states a deal signal is formed on bar close by OsHMA histogram zero-level breakthrough or direction change. |
| R3 Data Available | PASS | Source test uses NZDUSD H4; oscillator histogram logic is portable to DWX FX and CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator signal; no ML, adaptive parameters, grid, martingale, or multiple positions per magic. |

## R3
No special custom-symbol caveat. Baseline can run on DWX FX majors and crosses.
Target symbols: NZDUSD.DWX, EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from MQL5 CodeBase page-35 continuation batch.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_10598_mql5-figseries]] - prior closed-bar histogram state strategy.

## Lessons Learned (während Pipeline-Lauf)
- TBD
