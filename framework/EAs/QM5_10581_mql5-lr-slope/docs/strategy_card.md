---
ea_id: QM5_10581
slug: mql5-lr-slope
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Exp_LinearRegSlope_V1, Nikolay Kositsin, MQL5 CodeBase, published 2015-11-03, updated 2023-03-29, https://www.mql5.com/en/code/14009"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/oscillator-signal-cross]]"
  - "[[concepts/linear-regression-slope]]"
indicators: [LinearRegSlope_V1]
target_symbols: [USDJPY.DWX, EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX]
period: H4
expected_trade_frequency: "Closed-bar LinearRegSlope oscillator/signal crosses on H4 should be moderate; conservative estimate is 20-60 trades/year/symbol."
expected_trades_per_year_per_symbol: 40
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS MQL5 CodeBase URL/title/author cited; R2 PASS mechanical LinearRegSlope closed-bar cross exits with ~40 trades/year/symbol; R3 PASS DWX FX/metals portable; R4 PASS fixed non-ML one-position rules."
---

# MQL5 LinearRegSlope Cloud Cross

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Nikolay Kositsin, "Exp_LinearRegSlope_V1", MQL5 CodeBase, published 2015-11-03, updated 2023-03-29, URL https://www.mql5.com/en/code/14009.
- Source location: page states the EA enters when the LinearRegSlope_V1 indicator cloud changes color; a signal forms at bar close when the oscillator crosses its signal line. Source test shown on USDJPY H4 for 2014.

## Mechanik

### Entry
- Compute LinearRegSlope_V1 on the selected timeframe.
- Long when the latest closed bar shows the oscillator crossing above its signal line and the indicator cloud changes to bullish color.
- Short when the latest closed bar shows the oscillator crossing below its signal line and the indicator cloud changes to bearish color.
- No existing position for this symbol/magic.

### Exit
- Close long on a bearish LinearRegSlope_V1 cross/cloud color change, hard stop/target, or V5 kill-switch.
- Close short on a bullish LinearRegSlope_V1 cross/cloud color change, hard stop/target, or V5 kill-switch.
- V5 Friday close and news exits apply.

### Stop Loss
- Source tests did not use SL/TP.
- P2 baseline: ATR(14) 2.0 hard stop and 1.5R target.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Sweep H1/H4/H6/H8, LinearRegSlope_V1 lookback/smoothing parameters after source-code confirmation, ATR stop multiplier, and optional ADX minimum trend filter.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL, title, author, and publish/update dates. |
| R2 Mechanical | PASS | Direction is determined by closed-bar oscillator/signal cross and cloud color state. |
| R3 DWX-testbar | PASS | Linear-regression slope oscillator logic is portable to DWX FX, metals, oil, and index CFDs. |
| R4 No ML | PASS | No ML, grid, martingale, or adaptive sizing; one-position V5 baseline enforced. |

## R3
Primary P2 basket: USDJPY.DWX, EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10580_mql5-lsma-ang]] - related linear-regression slope family.

## Lessons Learned
- TBD during pipeline run.
