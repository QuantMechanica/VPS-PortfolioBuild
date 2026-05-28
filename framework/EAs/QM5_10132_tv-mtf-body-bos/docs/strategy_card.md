---
ea_id: QM5_10132
slug: tv-mtf-body-bos
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
source_citation: "JK, Body Close Outside Prior Body - BOS Filtered (MTF), TradingView, https://www.tradingview.com/script/OcVKeqc2-Body-Close-Outside-Prior-Body-BOS-Filtered-MTF-by-JK/"
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/breakout]]"
  - "[[concepts/market-structure]]"
indicators:
  - "[[indicators/candle-body]]"
  - "[[indicators/break-of-structure]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX]
period: M15
expected_trade_frequency: "Body-close breakout plus BOS filter on M15; estimate 60-120 trades/year/symbol after MTF filter."
expected_trades_per_year_per_symbol: 80
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source TradingView URL/title; R2 deterministic body-close BOS entries/exits with ~80 trades/year/symbol; R3 ports to DWX FX/gold/index CFDs; R4 fixed non-ML one-position rules."
---

# TradingView MTF Body Break Of Structure

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Citation: JK, "Body Close Outside Prior Body - BOS Filtered (MTF)", TradingView, accessed 2026-05-19, URL https://www.tradingview.com/script/OcVKeqc2-Body-Close-Outside-Prior-Body-BOS-Filtered-MTF-by-JK/.
- Author / handle: `JK`.
- Source location: public script page describes candle-body close outside the prior body with break-of-structure filtering and multi-timeframe context.

## Mechanik

### Entry
- Baseline parameters:
  - Structure lookback: 20 bars.
  - Higher timeframe: 4x chart timeframe.
  - ATR length 14.
- Long entry when all conditions are true:
  - Current candle body close is above the prior candle body high.
  - Current close breaks above the highest high of the prior 20 bars.
  - Higher-timeframe close is above higher-timeframe SMA(50).
- Short entry when all conditions are true:
  - Current candle body close is below the prior candle body low.
  - Current close breaks below the lowest low of the prior 20 bars.
  - Higher-timeframe close is below higher-timeframe SMA(50).

### Exit
- Close long when candle body closes back below the prior candle body low or after 2R target.
- Close short when candle body closes back above the prior candle body high or after 2R target.

### Stop Loss
- Long stop: min(signal candle low - 0.25 * ATR(14), entry - 1.5 * ATR(14)).
- Short stop: max(signal candle high + 0.25 * ATR(14), entry + 1.5 * ATR(14)).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- M15 primary; H1 robustness secondary.
- Skip trades within 30 minutes of major scheduled news in P8 deploy-mode evaluation.
- Skip if spread > 10% of stop distance.

## Concepts
- [[concepts/breakout]] - primary
- [[concepts/market-structure]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full TradingView URL plus author handle/title. |
| R2 Mechanical | PASS | Prior-body close, BOS lookback, HTF filter, stop, and exit are deterministic. |
| R3 DWX-testbar | PASS | OHLC-only candle/body/structure logic ports to DWX FX, gold, and index CFDs. |
| R4 No ML | PASS | Fixed lookbacks and fixed R/ATR rules; no ML, grid, martingale, or adaptive online parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10113_tv-ob-matrix]] - related market-structure family; this card uses simpler body/BOS primitives.

## Lessons Learned
- TBD during pipeline run.
