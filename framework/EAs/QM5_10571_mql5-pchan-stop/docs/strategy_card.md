---
ea_id: QM5_10571
slug: mql5-pchan-stop
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Exp_PriceChannel_Stop, Nikolay Kositsin, MQL5 CodeBase, published 2016-04-14, updated 2016-11-22, https://www.mql5.com/en/code/15222"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/price-channel-stop]]"
  - "[[concepts/trend-change]]"
indicators: [PriceChannel_Stop]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, EURJPY.DWX, XAUUSD.DWX]
period: H4
expected_trade_frequency: "Price-channel trend-change points on H4 should be moderate; conservative estimate is 20-55 trades/year/symbol."
expected_trades_per_year_per_symbol: 35
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS MQL5 CodeBase URL/title/author cited; R2 PASS closed-bar PriceChannel_Stop bullish/bearish trend-change entries and opposite-signal exits with 20-55 trades/year/symbol; R3 PASS portable to DWX FX/metals; R4 PASS no ML/grid/martingale and one-position baseline."
---

# MQL5 PriceChannel Stop Trend Change

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Nikolay Kositsin, "Exp_PriceChannel_Stop", MQL5 CodeBase, published 2016-04-14, updated 2016-11-22, URL https://www.mql5.com/en/code/15222.
- Source location: page states the EA trades PriceChannel_Stop signals, with a signal formed at bar close when a color point indicating trend change appears. Source test shown on EURUSD H4.

## Mechanik

### Entry
- Compute PriceChannel_Stop on the selected timeframe.
- Long when the latest closed bar prints a bullish color point indicating upward trend change.
- Short when the latest closed bar prints a bearish color point indicating downward trend change.
- No existing position for this symbol/magic.

### Exit
- Close long on a bearish PriceChannel_Stop trend-change point, hard stop/target, or V5 kill-switch.
- Close short on a bullish PriceChannel_Stop trend-change point, hard stop/target, or V5 kill-switch.
- V5 Friday close and news exits apply.

### Stop Loss
- Source tests did not use SL/TP.
- P2 baseline: ATR(14) 2.0 hard stop and 1.5R target.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Sweep H1/H4/H6, PriceChannel period/ATR inputs after source-code confirmation, ATR stop multiplier, and optional breakout-distance filter from channel midpoint.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL, title, author, and publish/update dates. |
| R2 Mechanical | PASS | Direction is given by closed-bar bullish/bearish trend-change color points. |
| R3 DWX-testbar | PASS | Price-channel stop/reversal logic is portable to DWX FX, metals, oil, and index CFDs. |
| R4 No ML | PASS | No ML, grid, martingale, or adaptive sizing; one-position V5 baseline enforced. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, EURJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10570_mql5-stepma-nrtr]] - stop/reversal color-point family from the same listing page.

## Lessons Learned
- TBD during pipeline run.
