---
ea_id: QM5_10576
slug: mql5-digft01
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Exp_DigitalF-T01, Nikolay Kositsin, MQL5 CodeBase, published 2015-12-04, updated 2016-11-22, https://www.mql5.com/en/code/14136"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/oscillator-signal-cross]]"
  - "[[concepts/cloud-color-change]]"
indicators: [DigitalF-T01]
target_symbols: [GBPJPY.DWX, EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX]
period: H3
expected_trade_frequency: "Closed-bar DigitalF-T01 oscillator/signal crosses on H3 should be moderate; conservative estimate is 25-70 trades/year/symbol."
expected_trades_per_year_per_symbol: 45
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 MQL5 CodeBase URL/title/author cited; R2 closed-bar DigitalF-T01 cross/cloud-color entry and reverse/stop exits with ~45 trades/year/symbol; R3 portable to DWX FX/metals; R4 no ML/grid/martingale and one-position compatible."
---

# MQL5 DigitalF-T01 Cloud Cross

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Nikolay Kositsin, "Exp_DigitalF-T01", MQL5 CodeBase, published 2015-12-04, updated 2016-11-22, URL https://www.mql5.com/en/code/14136.
- Source location: page states the EA enters when the DigitalF-T01 indicator cloud changes color; a signal forms at bar close when the oscillator crosses its signal line. Source test shown on GBPJPY H3 for 2014.

## Mechanik

### Entry
- Compute DigitalF-T01 on the selected timeframe.
- Long when the latest closed bar shows the oscillator crossing above its signal line and the DigitalF-T01 cloud changes to bullish color.
- Short when the latest closed bar shows the oscillator crossing below its signal line and the DigitalF-T01 cloud changes to bearish color.
- No existing position for this symbol/magic.

### Exit
- Close long on a bearish DigitalF-T01 oscillator/signal cross or cloud color change, hard stop/target, or V5 kill-switch.
- Close short on a bullish DigitalF-T01 oscillator/signal cross or cloud color change, hard stop/target, or V5 kill-switch.
- V5 Friday close and news exits apply.

### Stop Loss
- Source tests did not use SL/TP.
- P2 baseline: ATR(14) 2.0 hard stop and 1.5R target.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Sweep H3/H4/H6/H8, DigitalF-T01 oscillator parameters after source-code confirmation, ATR stop multiplier, and optional trend filter from EMA200 slope.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL, title, author, and publish/update dates. |
| R2 Mechanical | PASS | Direction is determined by closed-bar oscillator/signal cross and cloud color state. |
| R3 DWX-testbar | PASS | Oscillator cross and cloud-color logic is portable to DWX FX, metals, oil, and index CFDs. |
| R4 No ML | PASS | No ML, grid, martingale, or adaptive sizing; one-position V5 baseline enforced. |

## R3
Primary P2 basket: GBPJPY.DWX, EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10557_mql5-trigger]] - oscillator/signal cross and cloud-confirmation family.

## Lessons Learned
- TBD during pipeline run.
