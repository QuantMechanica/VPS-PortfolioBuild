---
ea_id: QM5_10584
slug: mql5-digvar
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Exp_DigVariation, Nikolay Kositsin, MQL5 CodeBase, published 2015-08-17, updated 2023-03-29, https://www.mql5.com/en/code/13554"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/oscillator-direction-change]]"
  - "[[concepts/non-normalized-oscillator]]"
indicators: [DigVariation]
target_symbols: [GBPJPY.DWX, EURUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H8
expected_trade_frequency: "Closed-bar oscillator direction reversals on H8 should be moderate; conservative estimate is 15-40 trades/year/symbol."
expected_trades_per_year_per_symbol: 25
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 source URL/title/author present; R2 closed-bar DigVariation direction reversal entry/opposite-reversal exit mechanical with ~25 trades/year/symbol; R3 portable to DWX FX/metals; R4 no ML/grid/martingale and one-position baseline."
---

# MQL5 DigVariation Direction Reversal

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Nikolay Kositsin, "Exp_DigVariation", MQL5 CodeBase, published 2015-08-17, updated 2023-03-29, URL https://www.mql5.com/en/code/13554.
- Source location: page states the EA is based on reversal of the DigVariation non-normalized oscillator direction; the signal forms at bar close when oscillator direction changes. Source test shown on GBPJPY H8 for 2014.

## Mechanik

### Entry
- Compute DigVariation on the selected timeframe.
- Long when the latest closed bar changes DigVariation direction from falling to rising.
- Short when the latest closed bar changes DigVariation direction from rising to falling.
- No existing position for this symbol/magic.

### Exit
- Close long on a bearish DigVariation direction change, hard stop/target, or V5 kill-switch.
- Close short on a bullish DigVariation direction change, hard stop/target, or V5 kill-switch.
- V5 Friday close and news exits apply.

### Stop Loss
- Source tests did not use SL/TP.
- P2 baseline: ATR(14) 2.0 hard stop and 1.5R target.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Sweep H4/H6/H8/H12, DigVariation smoothing parameters after source-code confirmation, ATR stop multiplier, and optional higher-timeframe EMA slope filter.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL, title, author, and publish/update dates. |
| R2 Mechanical | PASS | Direction is determined by closed-bar oscillator direction reversal. |
| R3 DWX-testbar | PASS | OHLC-derived oscillator logic is portable to DWX FX, metals, oil, and index CFDs. |
| R4 No ML | PASS | No ML, grid, martingale, or adaptive sizing; one-position V5 baseline enforced. |

## R3
Primary P2 basket: GBPJPY.DWX, EURUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10586_mql5-cycleper]] - related non-normalized oscillator direction-change family.

## Lessons Learned
- TBD during pipeline run.
