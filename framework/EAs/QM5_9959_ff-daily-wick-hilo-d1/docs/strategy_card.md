---
ea_id: QM5_9959
slug: ff-daily-wick-hilo-d1
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "rockzz, Your EA v3 - Daily Low & High Strategy, ForexFactory, 2023, https://www.forexfactory.com/thread/1233107-your-ea-v3-daily-low-high"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/previous-day-breakout]]"
  - "[[concepts/wick-bias-filter]]"
indicators:
  - "[[indicators/previous-day-high-low]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, NDX.DWX]
period: D1
expected_trade_frequency: "Daily previous-high/low pending breakout with wick-side bias; at most one order per day, estimate 35-80 trades/year/symbol."
expected_trades_per_year_per_symbol: 55
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 linked ForexFactory source; R2 deterministic daily wick-biased previous high/low breakout with exits/stops and ~55 trades/year/symbol; R3 DWX FX/metals/indices testable; R4 fixed-rule no ML/grid/martingale."
---

# ForexFactory Daily Wick High-Low D1

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: rockzz, "Your EA v3 - Daily Low & High Strategy", ForexFactory, 2023, URL https://www.forexfactory.com/thread/1233107-your-ea-v3-daily-low-high.
- Author / handle: `rockzz`.
- Source location: first post. The post describes the EA's exact daily logic: compute previous-day open/high/low wickBuy/wickSell, place buy stop above previous high when wickBuy > wickSell, sell stop below previous low when wickSell > wickBuy, with TP 100 pips and SL 30 pips in current settings.

## Mechanik

### Entry
- At the start of each new D1 candle, compute from the previous completed D1 candle:
  - `wickBuy = open[1] - low[1]`.
  - `wickSell = high[1] - open[1]`.
  - `PDH = high[1]`, `PDL = low[1]`.
- Long setup:
  - `wickBuy > wickSell`.
  - Place one buy stop at `PDH + 5 pips` or `PDH + 0.05 * ATR(14,D1)` for non-FX symbols.
- Short setup:
  - `wickSell > wickBuy`.
  - Place one sell stop at `PDL - 5 pips` or normalized equivalent.
- Cancel unfilled pending order at the next D1 open.

### Exit
- Source TP: 100 pips.
- Normalized TP: `min(100 pips, 2.0R)` for FX; `2.0R` for non-FX symbols.
- Time stop at next D1 open if neither TP nor SL fired.

### Stop Loss
- Source SL: 30 pips.
- Normalized SL: `0.8 * ATR(14,D1)` if 30 pips is outside 0.4-1.2 ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One pending order per symbol per day.
- Skip inside days where `PDH - PDL < 0.5 * ATR(14,D1)`.
- Spread <= 10% of stop distance.

## Concepts
- [[concepts/previous-day-breakout]] - primary
- [[concepts/wick-bias-filter]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory URL plus named handle `rockzz`. |
| R2 Mechanical | PASS | The source gives full EA logic including wick bias, pending prices, SL, TP, and daily reset. |
| R3 DWX-testbar | PASS | Uses prior-day OHLC and ATR on DWX FX/metals/indices. |
| R4 No ML | PASS | Fixed parameters, one order per day per magic, no ML/grid/martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, NDX.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9954_ff-weekly-hilo-breakout-d1]] - previous-week high/low breakout; this card uses previous-day high/low and prior-candle wick-side bias.
- [[strategies/QM5_1149_unger-dax-adx-low-breakout]] - prior-day level breakout family; this card adds wickBuy/wickSell direction selection.

## Lessons Learned
- TBD during pipeline run.

