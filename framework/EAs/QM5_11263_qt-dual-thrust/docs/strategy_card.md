---
ea_id: QM5_11263
slug: qt-dual-thrust
type: strategy
source_id: 72f9fcfa-6c75-5544-80c4-31e15c9817ab
source_citation: "je-suis-tm, quant-trading Dual Thrust backtest.py, https://github.com/je-suis-tm/quant-trading/blob/master/Dual%20Thrust%20backtest.py"
sources:
  - "[[sources/github-topic-algorithmic-trading-python]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/range-expansion]]"
indicators:
  - "[[indicators/rolling-range]]"
strategy_type_flags: [intraday-session-pattern, n-period-max-continuation, time-stop, signal-reversal-exit, symmetric-long-short, news-blackout]
target_symbols: [GBPUSD.DWX, EURUSD.DWX, XAUUSD.DWX, GER40.DWX]
period: M1
expected_trade_frequency: "Daily opening-range breakout with at most one net position and possible reversal; conservative estimate 80-160 trades/year/symbol."
expected_trades_per_year_per_symbol: 120
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
g0_approval_reasoning: "R1 source repo/script cited; R2 mechanical Dual Thrust thresholds/reversal/time exit and plausible daily 80-160 trades/year; R3 DWX FX/metals/index CFDs testable; R4 fixed rules no ML/grid/martingale."
---

# Quant-Trading Dual Thrust Intraday Breakout

## Quelle
- Source citation 2026 URL: je-suis-tm, quant-trading Dual Thrust backtest.py, https://github.com/je-suis-tm/quant-trading/blob/master/Dual%20Thrust%20backtest.py
- Source: GitHub topic `algorithmic-trading` language Python, most-starred listing: https://github.com/topics/algorithmic-trading?l=python
- Repository: `je-suis-tm/quant-trading`, https://github.com/je-suis-tm/quant-trading
- Source location: README section "Dual Thrust" and `Dual Thrust backtest.py`. The script cites QuantConnect's Dual Thrust rules, uses `rg = 5`, `param = 0.5`, computes rolling range from prior intraday high/low/open/close data, sets thresholds at 03:00, permits long/short/reversal, and closes at 12:00.

## Mechanik

### Entry
- Convert M1 data into prior-session intraday OHLC over the source session window.
- Compute over the prior `rg = 5` sessions:
  - `range1 = rolling_high(rg) - rolling_close_min(rg)`.
  - `range2 = rolling_close_max(rg) - rolling_low(rg)`.
  - `range = max(range1, range2)`.
- At the session open, set:
  - `upper = open + param * range`.
  - `lower = open - (1 - param) * range`.
  - Source default `param = 0.5`.
- Enter long when price exceeds `upper`.
- Enter short when price falls below `lower`.
- If already positioned and price crosses the opposite threshold, reverse the position per source logic.

### Exit
- Force close all open positions at the source session close, 12:00 EST in the script.
- No fixed source TP/SL; V5 baseline adds a catastrophic stop for pipeline safety.

### Stop Loss
- Catastrophic ATR(14,M30) hard stop at 1.5 ATR, not part of the alpha thesis.
- P3 axis: 1.0, 1.5, 2.0 ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic; reversal is implemented as close-then-open, not multiple positions.

### Zusaetzliche Filter
- News blackout on entries and reversals.
- Skip if prior 5-session range is zero or missing.
- Skip if current spread exceeds 10% of threshold distance.
- Friday close enforced by framework.

## Concepts
- [[concepts/opening-range-breakout]] - thresholds are computed at the session open.
- [[concepts/range-expansion]] - entries require price to exceed a recent range-derived boundary.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | GitHub topic, repository, README, and exact Dual Thrust script URL are cited. |
| R2 Mechanical | PASS | Source fixes range calculation, lookback, threshold parameter, entry/reversal rules, and end-of-session flattening. |
| R3 DWX-testbar | PASS | Uses OHLC intraday prices testable on DWX FX, metals, and index CFDs. |
| R4 No ML | PASS | Fixed range-breakout algorithm; no ML, grid, martingale, or adaptive parameters. |

## R3
Primary P2 basket: GBPUSD.DWX, EURUSD.DWX, XAUUSD.DWX, GER40.DWX.

## Author Claims
- Source README describes Dual Thrust as an opening-range breakout strategy.
- Source README states that upper and lower thresholds are based on previous days' open, close, high, and low.
- Source README states that positions are cleared by the end of day.

## Parameters To Test
- Range lookback `rg`: 3, 5, 10 sessions.
- Threshold parameter `param`: 0.35, 0.50, 0.65.
- Session window: London, New York, broker-day open.
- Catastrophic stop: off, 1.0 ATR, 1.5 ATR, 2.0 ATR.

## Initial Risk Profile
Medium-high risk. Daily intraday breakouts can overtrade in chop, and source has no native stop loss; V5 catastrophic stop is required for bounded loss.

## Pipeline-Verlauf
- G0: 2026-05-23, PENDING, drafted from `je-suis-tm/quant-trading` Dual Thrust script.

## Verwandte Strategien
- [[strategies/QM5_11262_qt-london-brk]] - narrower pre-London range breakout; this card uses rolling multi-day Dual Thrust thresholds.

## Lessons Learned
- TBD during pipeline run.
