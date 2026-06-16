---
ea_id: QM5_10541
slug: mql5-20prexp
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "20PRExp-3, Sergey idea / Vladimir Karputov MQL5 code, MQL5 CodeBase, published 2017-03-22, updated 2018-02-27, https://www.mql5.com/en/code/17866"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/intraday-breakout]]"
  - "[[concepts/parabolic-sar-filter]]"
indicators: [ParabolicSAR, Volume, ATR]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX]
period: M5
expected_trade_frequency: "M5 close beyond the PRIOR completed D1 high/low with a tick-volume confirmation. Breaking the previous day's full range on a closed M5 bar is a low-frequency daily-range breakout; measured realization on real-tick 2024 was ~3 trades/yr (GDAXI.DWX) and ~0/yr (EURUSD.DWX). Realistic expectation ~4 trades/year/symbol."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS MQL5 CodeBase URL/title/authors; R2 PASS D1 level M5 breakout with SAR/volume filters and trailing/ATR exits, ~80 trades/year/symbol; R3 PASS DWX FX/metals/index M5 data; R4 PASS no ML/grid/martingale."
---

# MQL5 20PRExp Intraday Breakthrough

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Sergey idea / Vladimir Karputov MQL5 code, "20PRExp-3", MQL5 CodeBase, published 2017-03-22, updated 2018-02-27, URL https://www.mql5.com/en/code/17866.
- Source location: page states the EA is an intraday volatility breakthrough system, additionally using volume filters and Parabolic SAR. Recommended period is M5. It draws and moves daily levels at current D1 high (`MLP`), current D1 low (`MLM`), and midpoint (`MidL`), and exits via trailing stop.

## Mechanik

### Entry
- Evaluate on M5 bars.
- Build current-day levels from D1 high, D1 low, and midpoint.
- Long when price breaks above the active upper daily breakthrough level with Parabolic SAR below price and volume filter satisfied.
- Short when price breaks below the active lower daily breakthrough level with Parabolic SAR above price and volume filter satisfied.
- No existing position for this symbol/magic.

### Exit
- Source uses trailing stop; P2 baseline uses SAR trail plus hard ATR stop.
- Optional fixed target = 1.5R for ablation.

### Stop Loss
- ATR(14) hard stop, sweep 1.0/1.5/2.0 ATR on M5.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Sweep M5/M15, SAR step/max defaults, minimum tick volume percentile, and breakout buffer around MLP/MLM.
- V5 spread/news/Friday-close defaults apply; P5b latency stress is important because M5 breakout entries can be fill-sensitive.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL, title, idea author, code author, and publish/update dates. |
| R2 Mechanical | PASS | Daily level breakout, SAR side, volume filter, and trailing exit are deterministic. |
| R3 DWX-testbar | PASS | OHLC, SAR, tick volume, and M5 data are available on DWX symbols. |
| R4 No ML | PASS | No ML, grid, martingale, or online adaptation; one-position V5 baseline enforced. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10521_mql5-daybreak]] - daily-level breakout family.

## Lessons Learned
- TBD during pipeline run.
