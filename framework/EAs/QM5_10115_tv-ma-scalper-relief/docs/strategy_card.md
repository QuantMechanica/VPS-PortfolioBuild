---
ea_id: QM5_10115
slug: tv-ma-scalper-relief
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
source_citation: "Coinrule, Moving Average Scalper, TradingView, 2021-04-29, https://www.tradingview.com/script/PfBSgqMw-Moving-Average-Scalper/"
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/moving-average-crossover]]"
indicators:
  - "[[indicators/sma]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX]
period: M15
expected_trade_frequency: "M15 MA relief-rally scalper can trigger repeatedly in downtrend regimes; conservative estimate 45-90 trades/year/symbol."
expected_trades_per_year_per_symbol: 60
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL/author cited; R2 MA stack entry and MA9/MA200/time exit mechanical with 60 trades/year/symbol estimate; R3 OHLC MA logic testable on DWX FX/gold/index CFDs; R4 fixed rules one-position no ML/grid/martingale."
---

# TradingView Moving Average Scalper Relief Rally

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Citation: Coinrule, "Moving Average Scalper", TradingView, 2021-04-29, URL https://www.tradingview.com/script/PfBSgqMw-Moving-Average-Scalper/.
- Author / handle: `Coinrule`.
- Source location: public description defines MA9/MA50/MA100/MA200 entry stack, MA9/MA200 exit, 15-minute preferred timeframe, and one-trade-at-a-time behavior.

## Mechanik

### Entry
- Compute SMA(9), SMA(50), SMA(100), and SMA(200) on M15.
- Long entry when all conditions are true:
  - SMA(9) crosses above SMA(50).
  - SMA(50) < SMA(100).
  - SMA(100) < SMA(200).
- No short entries.

### Exit
- Close long when SMA(9) crosses above SMA(200).
- Time stop: close after 96 M15 bars if no MA9/SMA200 exit has occurred, matching the source goal of short holding periods.

### Stop Loss
- Source emphasizes limiting downside but does not define a fixed stop.
- V5 build default: stop at 2 * ATR(14,M15) below entry or below the lowest low of the prior 20 bars, whichever is farther.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Source uses 30% capital; do not use percent-of-equity sizing in P2.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Skip if SMA200 slope over the prior 20 bars is positive; the source premise is a downtrend relief rally.
- Skip if spread > 10% of stop distance.

## Concepts
- [[concepts/mean-reversion]] - primary
- [[concepts/moving-average-crossover]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full TradingView URL plus author handle `Coinrule`. |
| R2 Mechanical | PASS | MA stack entry and MA9/SMA200 exit are explicit; stop gap is filled by V5 default. |
| R3 DWX-testbar | PASS | OHLC-derived moving-average logic ports directly to DWX FX, gold, and index CFDs. |
| R4 No ML | PASS | Fixed MA rules and one position at a time; no ML/grid/martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10116_tv-multi-ma-exit]] - same Coinrule MA family but this card buys relief rallies inside a bearish MA stack.

## Lessons Learned
- TBD during pipeline run.
