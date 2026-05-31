---
ea_id: QM5_10568
slug: mql5-xdpo-hist
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Exp_XDPO_Histogram, Nikolay Kositsin, MQL5 CodeBase, published 2016-06-30, updated 2023-03-29, https://www.mql5.com/en/code/15294"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/dpo-momentum]]"
  - "[[concepts/histogram-direction]]"
indicators: [XDPO_Histogram]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDCAD.DWX, XAUUSD.DWX]
period: H12
expected_trade_frequency: "XDPO histogram direction changes on H12 should be low-to-moderate; conservative estimate is 15-40 trades/year/symbol."
expected_trades_per_year_per_symbol: 25
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 cited MQL5 CodeBase URL/title/author; R2 closed-bar XDPO histogram direction entries/exits with ~25 trades/year/symbol; R3 portable to DWX FX/metals; R4 no ML/grid/martingale and one-position baseline."
---

# MQL5 XDPO Histogram Direction Change

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Nikolay Kositsin, "Exp_XDPO_Histogram", MQL5 CodeBase, published 2016-06-30, updated 2023-03-29, URL https://www.mql5.com/en/code/15294.
- Source location: page states the EA trades XDPO_Histogram signals and forms a signal at bar close when histogram direction changes. Source test shown on EURUSD H12.

## Mechanik

### Entry
- Compute XDPO_Histogram on the selected timeframe.
- Long when the closed histogram changes from falling/bearish to rising/bullish.
- Short when the closed histogram changes from rising/bullish to falling/bearish.
- No existing position for this symbol/magic.

### Exit
- Close long when XDPO_Histogram direction turns bearish or hard stop/target is hit.
- Close short when XDPO_Histogram direction turns bullish or hard stop/target is hit.
- V5 Friday close, news, and kill-switch exits apply.

### Stop Loss
- Source tests did not use SL/TP.
- P2 baseline: ATR(14) 2.0 hard stop and 1.5R target.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Sweep H4/H6/H8/H12, XDPO moving-average and smoothing inputs after source-code confirmation, ATR stop multiplier, and optional trend filter using MA(100) slope.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL, title, author, and publish/update dates. |
| R2 Mechanical | PASS | Direction is given by closed-bar histogram direction changes. |
| R3 DWX-testbar | PASS | DPO-style price-minus-average oscillator logic is portable to DWX FX, metals, oil, and index CFDs. |
| R4 No ML | PASS | No ML, grid, martingale, or adaptive sizing; one-position V5 baseline enforced. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDCAD.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10565_mql5-rvidiff]] - oscillator histogram direction-change family.

## Lessons Learned
- TBD during pipeline run.
