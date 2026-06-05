---
ea_id: QM5_10821
slug: tv-wpr-zone
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "BullByte, Williams R Zone Scalper v1.0[BullByte], TradingView open-source strategy, https://my.tradingview.com/script/TJuVmOfk-Williams-R-Zone-Scalper-v1-0-BullByte/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/momentum-reversal]]"
  - "[[concepts/regime-filter]]"
  - "[[concepts/volatility-filter]]"
indicators:
  - "[[indicators/williams-r]]"
  - "[[indicators/choppiness-index]]"
  - "[[indicators/supertrend]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 180
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS TradingView URL+handle; R2 PASS mechanical Williams R/filter/bracket rules with ~180 trades/year/symbol; R3 PASS DWX OHLC/tick-volume indicators testable; R4 PASS fixed non-ML one-position rules."
---

# TradingView Williams R Zone Scalper

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `Williams R Zone Scalper v1.0[BullByte]`, author handle `BullByte`, open-source strategy, published 2025-04-28, accessed 2026-05-22, https://my.tradingview.com/script/TJuVmOfk-Williams-R-Zone-Scalper-v1-0-BullByte/

## Mechanik

### Entry
Use M5 baseline. Compute Williams %R(14), selected MA trend filter default EMA(20), Choppiness Index(12), volume MA(50), optional Bollinger Band Width filter, optional SuperTrend ATR(10) factor 3.0.

- Long setup:
  - Williams %R crosses above -80.
  - Enabled filters are green:
    - MA trend is bullish.
    - If Choppiness filter enabled, CI < 38.2.
    - If volume filter enabled, volume > volume MA(50).
    - If BBW filter enabled, BBW above its MA.
    - If SuperTrend filter enabled, SuperTrend is bullish.
- Short setup:
  - Williams %R crosses below -20.
  - Enabled filters are bearish/green for short using the same filter family.

### Exit
- Source primary exit is bracket when SL/TP is enabled.
- V5 baseline exits on ATR bracket or opposite Williams %R signal, whichever occurs first.

### Stop Loss
Source optional SL/TP: stop = 1.5 * ATR(14), target = 2.0 * ATR(14). V5 baseline keeps this bracket enabled.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic.

### Zusatzliche Filter
- Use broker tick volume for the volume filter on FX/CFD symbols.
- Disable dashboard-only logic; dashboard state is not part of execution.

## Concepts (was ist das fur eine Strategie)
- [[concepts/momentum-reversal]] - Williams %R exits an extreme zone.
- [[concepts/regime-filter]] - Choppiness and optional SuperTrend avoid low-quality reversals.
- [[concepts/volatility-filter]] - BBW and ATR bracket normalize trade quality and risk.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `BullByte` are cited. |
| R2 Mechanical | PASS | Source gives Williams %R triggers, filter defaults, optional SL/TP ATR formulas, and long/short arrows. |
| R3 Data Available | PASS | Williams %R, MA, SuperTrend, Choppiness, BBW, ATR, OHLC, and tick volume are available or implementable on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed indicator thresholds and toggles; no ML, grid, martingale, or adaptive online parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD, GER40.DWX, NDX.DWX, WS30.DWX.

If this is later tested primarily on SP500.DWX, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says long arrows occur when Williams R crosses above -80 plus all enabled filters are green.
- Source says short arrows occur when Williams R crosses below -20 plus all enabled filters are green.
- Source says optional SL/TP uses ATR-based stop-loss at 1.5 * ATR and take-profit at 2.0 * ATR.

## Parameters To Test
- Williams %R length: 14, 21, 34.
- CI threshold: 38.2, 42.0, disabled.
- MA type/length: EMA20, SMA20, EMA50.
- Volume filter: on/off; volume ratio threshold 1.0, 1.2.
- SuperTrend filter: off, ATR(10) factor 3.0.
- ATR stop/target: 1.2/1.8, 1.5/2.0, 2.0/3.0.

## Initial Risk Profile
Scalping oscillator strategy with many optional filters. The build baseline should freeze a small filter set and expose toggles to P3 rather than combine all variants into one overfit model.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- QM5_10213 tv-wpr-macd-scalp
- QM5_10820 tv-real-strength

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
