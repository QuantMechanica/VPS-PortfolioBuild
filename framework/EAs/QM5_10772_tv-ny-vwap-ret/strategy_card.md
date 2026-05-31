---
ea_id: QM5_10772
slug: tv-ny-vwap-ret
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "itzkarmakyo, NY Session Trend Retest Strategy, TradingView open-source strategy, https://www.tradingview.com/script/zV6RrYm5-NY-Session-Trend-Retest-Strategy/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/vwap-retest]]"
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/session-filter]]"
indicators:
  - "[[indicators/vwap]]"
  - "[[indicators/ema]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 180
last_updated: 2026-05-22
g0_approval_reasoning: "R1 cited TradingView source URL/handle; R2 mechanical EMA/VWAP/premarket retest entries and EMA/session exits with ~180 trades/year/symbol; R3 testable on DWX intraday CFDs; R4 fixed-rule non-ML one-position-compatible."
---

# TradingView NY Session VWAP Trend Retest

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `NY Session Trend Retest Strategy`, author handle `itzkarmakyo`, open-source strategy, accessed 2026-05-22, page shows May 12, https://www.tradingview.com/script/zV6RrYm5-NY-Session-Trend-Retest-Strategy/

## Mechanik

### Entry
Use M5/M15 baseline around New York regular session.

- Higher-timeframe EMA filter:
  - Bullish environment when price is above HTF EMA.
  - Bearish environment when price is below HTF EMA.
- Anchored session VWAP resets daily and acts as equilibrium.
- Entry model 1, VWAP retest:
  - Long when price retests VWAP and closes back above VWAP while HTF trend is bullish.
  - Short when price retests VWAP and closes back below VWAP while HTF trend is bearish.
- Entry model 2, premarket breakout:
  - Track premarket high and low.
  - Long on close beyond premarket high or successful retest, depending on frozen breakout mode.
  - Short on close beyond premarket low or successful retest.
- Entry model 3, EMA retest:
  - Long when price retests faster EMA and closes back in bullish direction.
  - Short mirrors bearish direction.
- V5 baseline tests each entry model separately before combined mode.

### Exit
- Standard exit when candle body closes aggressively across exit EMA.
- VWAP override can be enabled for entries on the wrong side of exit EMA; P2 baseline disables this first, then tests ON.
- Collapse partial profit and breakeven logic to a single full-position target/exit baseline for one-position-per-magic compliance.
- Session flat at end of NY window.

### Stop Loss
- Initial stop behind VWAP/retest swing, premarket boundary, or EMA retest swing depending on entry model.
- V5 baseline adds ATR(14) buffer 0.5.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic.

### Zusatzliche Filter
- VWAP regime filter blocks flat VWAP, compressed price action, and low expansion environments.
- Cooldown after trade close.
- Session reset of premarket high/low and VWAP anchors.

## Concepts (was ist das fur eine Strategie)
- [[concepts/vwap-retest]] - trades institutional equilibrium retests in trend direction.
- [[concepts/opening-range-breakout]] - premarket high/low expansion model.
- [[concepts/session-filter]] - NY session state controls entries and resets.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `itzkarmakyo` are cited. |
| R2 Mechanical | PASS | Source defines HTF EMA bias, VWAP retest entries, premarket breakout/retest entries, EMA retest entries, VWAP regime filter, exit EMA logic, partials, breakeven, and cooldown. |
| R3 Data Available | PASS | Session OHLC, EMA, anchored VWAP proxy, premarket levels, and cooldown logic are available on DWX intraday symbols. |
| R4 ML Forbidden | PASS | Fixed technical/session rules; no ML, grid, martingale, or adaptive online learning. V5 collapses scale-outs to one active position. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD, GER40.DWX, NDX.DWX, WS30.DWX.

## Author Claims
- Source says it combines higher-timeframe trend, anchored VWAP, premarket structure, EMA positioning, and session liquidity behavior.
- Source says VWAP retest entries trade continuation after equilibrium retests.
- Source says the VWAP regime filter blocks flat or compressed environments.

## Parameters To Test
- HTF EMA period: 50, 100, 200.
- Exit EMA period: 9, 20, 34.
- Entry model: VWAP retest, premarket breakout, EMA retest, combined.
- Premarket breakout mode: close beyond, retest.
- VWAP slope threshold: low, medium, high.
- Cooldown: 0, 5, 10 bars.
- ATR stop buffer: 0.25, 0.5, 1.0.

## Initial Risk Profile
Rich intraday strategy with several entry modes. P2 should freeze one entry model per run and avoid combined-mode curve fit until single modules show independent value.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- QM5_10747 tv-vwap-ema-pb
- QM5_10768 tv-vwap-orb-pb
- QM5_10743 tv-nq-orb

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
