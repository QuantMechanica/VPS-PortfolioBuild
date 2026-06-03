---
ea_id: QM5_10573
slug: mql5-extrem-n
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Exp_Extrem_N, Nikolay Kositsin, MQL5 CodeBase, published 2016-04-13, updated 2016-11-22, https://www.mql5.com/en/code/14890"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/extreme-line-reversal]]"
  - "[[concepts/closed-bar-signal]]"
indicators: [Extrem_N]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H6
expected_trade_frequency: "Closed-bar Extrem_N line flips on H6 should be moderate-to-low; conservative estimate is 15-45 trades/year/symbol."
expected_trades_per_year_per_symbol: 28
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS MQL5 CodeBase URL/title/author cited; R2 PASS closed-bar Extrem_N red/green line-flip entries and opposite-flip exits with 15-45 trades/year/symbol; R3 PASS portable to DWX FX/metals; R4 PASS no ML/grid/martingale and one-position baseline."
---

# MQL5 Extrem_N Line Flip

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Nikolay Kositsin, "Exp_Extrem_N", MQL5 CodeBase, published 2016-04-13, updated 2016-11-22, URL https://www.mql5.com/en/code/14890.
- Source location: page states the EA trades Extrem_N indicator signals; a signal is generated at bar close when a red indicator line appears after the green one disappears, or vice versa. Source test shown on EURUSD H6 for 2015.

## Mechanik

### Entry
- Compute Extrem_N on the selected timeframe.
- Long when the latest closed bar shows the bullish/green Extrem_N line after the bearish/red line has disappeared.
- Short when the latest closed bar shows the bearish/red Extrem_N line after the bullish/green line has disappeared.
- No existing position for this symbol/magic.

### Exit
- Close long on a bearish Extrem_N line flip, hard stop/target, or V5 kill-switch.
- Close short on a bullish Extrem_N line flip, hard stop/target, or V5 kill-switch.
- V5 Friday close and news exits apply.

### Stop Loss
- Source tests did not use SL/TP.
- P2 baseline: ATR(14) 2.0 hard stop and 1.5R target.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Sweep H4/H6/H8/H12, Extrem_N indicator inputs after buffer confirmation, ATR stop multiplier, and optional volatility minimum filter.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL, title, author, and publish/update dates. |
| R2 Mechanical | PASS | Direction is determined by a closed-bar red/green indicator-line replacement. |
| R3 DWX-testbar | PASS | Extrem_N line-flip logic uses OHLC-derived indicator buffers portable to DWX instruments. |
| R4 No ML | PASS | No ML, grid, martingale, or adaptive sizing; one-position V5 baseline enforced. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10557_mql5-trigger]] - closed-bar indicator-state flip family.

## Lessons Learned
- TBD during pipeline run.
