---
ea_id: QM5_10001
slug: ff-static-fib-open
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "Olaha, Simple Trading system for Intraday/short term, ForexFactory, 2007, https://www.forexfactory.com/thread/33615-simple-trading-system-for-intradayshort-term"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/open-price-breakout]]"
  - "[[concepts/static-fibonacci-levels]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/sma]]"
  - "[[indicators/rsi]]"
  - "[[indicators/stochastic]]"
target_symbols: [GBPUSD.DWX, EURUSD.DWX, USDJPY.DWX, GBPJPY.DWX]
period: M15
expected_trade_frequency: "Daily Tokyo-open static-level stop orders with M15/M30 filters; estimate 120-220 trades/year/symbol."
expected_trades_per_year_per_symbol: 160
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS: ForexFactory source URL and handle; R2 PASS: deterministic Tokyo-open static-level breakout with stop/targets and ~160 trades/year/symbol; R3 PASS: standard OHLC indicators testable on DWX FX pairs; R4 PASS: fixed parameters, one position, no ML/grid/martingale."
---

# ForexFactory Static Fib Open Breakout

## Source
- Source: [[sources/forexfactory-trading-systems]]
- Citation: Olaha, "Simple Trading system for Intraday/short term", ForexFactory, 2007, URL https://www.forexfactory.com/thread/33615-simple-trading-system-for-intradayshort-term.
- Author / handle: `Olaha`.
- Source location: first post defines 1H trend with SMA70 and RSI21, M15/M30 retracement with stochastic(15,3,3), Tokyo open price, static offsets +34/+89/+144 and -34/-89/-144 pips, buy/sell stops at first levels, SL at open price, TP at later levels, and breakeven after about 20 pips.

## Mechanics

### Entry
- At Tokyo open, store the daily open price `O`.
- Build static levels:
  - Long side: `O + 34 pips`, `O + 89 pips`, `O + 144 pips`.
  - Short side: `O - 34 pips`, `O - 89 pips`, `O - 144 pips`.
- Long bias requires:
  - H1 close above SMA(70).
  - RSI(21,H1) above 50.
  - Stochastic(15,3,3,M15) above 60.
- Short bias requires:
  - H1 close below SMA(70).
  - RSI(21,H1) below 50.
  - Stochastic(15,3,3,M15) below 30.
- Place a buy stop at `O + 34 pips` when long bias is valid.
- Place a sell stop at `O - 34 pips` when short bias is valid.
- Cancel the opposite initial order when one side triggers.

### Exit
- TP1 baseline: first target at `O +/- 89 pips`.
- Runner option for P3: `O +/- 144 pips`.
- Move SL to entry +3 pips after price moves +20 pips in favor.
- Time stop at 20:00 broker time.

### Stop Loss
- Initial long SL at daily open `O`.
- Initial short SL at daily open `O`.
- Skip if the distance from entry to `O` is less than 0.4 or greater than 2.5 times ATR(14,M15).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Additional filters
- One active position per magic-symbol.
- Close or skip new entries 15 minutes before high-impact news, matching the source warning to avoid news releases.

## Concepts
- [[concepts/open-price-breakout]] - primary
- [[concepts/static-fibonacci-levels]] - secondary

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory URL and named handle `Olaha`. |
| R2 Mechanical | PASS | First post provides indicators, open-price levels, entry orders, stops, targets, breakeven, and news handling. |
| R3 DWX-testbar | PASS | Uses standard OHLC indicators on DWX FX pairs. |
| R4 No ML | PASS | Fixed offsets and indicators, one position, no ML, grid, martingale, or adaptive sizing. |

## R3
Primary P2 basket: GBPUSD.DWX, EURUSD.DWX, USDJPY.DWX, GBPJPY.DWX. Not SP500-specific.

## Pipeline history
- G0: 2026-05-19, PENDING.

## Related strategies
- [[strategies/QM5_9993_ff-open-levels-mwd]] - monthly/weekly/daily open levels; this card uses Tokyo daily open plus fixed +34/+89/+144 pip ladders.
- [[strategies/QM5_9936_ff-range-breakout-gmt3-h1]] - session range breakout; this card anchors to the open price rather than a completed high-low range.

## Lessons Learned
- TBD during pipeline run.

