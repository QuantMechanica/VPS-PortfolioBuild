# QM5_11902_bermuda-triangle-123-fib-extension-h1 - Strategy Spec

**EA ID:** QM5_11902  
**Slug:** `bermuda-triangle-123-fib-extension-h1`  
**Source:** `d2e5a8c4-3f76-5b91-8c47-a1f9d6e3b5c8`  
**Symbol:** ten DWX forex pairs listed below  
**Timeframe:** H1

## 1. Strategy Logic

On each closed H1 bar, the EA scans a bounded H1 window for a ZigZag-like swing
sequence with two descending swing highs, two rising swing lows, and an apex
projected within the configured forward window. Inside that compression context
it accepts a 1-2-3 sequence only when point 3 retraces the point 1 to point 2
leg near one of 23.6%, 38.2%, 50.0%, or 61.8%, with no retrace deeper than 65%.

For a long setup the sequence is low-high-higher low; the EA places a buy stop
at point 2 plus the entry buffer. For a short setup the sequence is high-low-
lower high; the EA places a sell stop at point 2 minus the entry buffer. Pending
orders expire after 50 H1 bars. The stop is beyond point 3 by the stop buffer.
The final take-profit is the 423.6% extension of the point 1 to point 2 leg.
The EA closes 40% at 161.8%, moves the stop to breakeven, closes another 40% at
261.8%, then moves the stop to the first target. Any remainder times out after
480 H1 bars.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_zigzag_depth` | 12 | 2-20 | Local swing window used to approximate ZigZag depth. |
| `strategy_zigzag_deviation_pips` | 10 | 1-100 | Minimum price movement between opposite pivots. |
| `strategy_zigzag_backstep` | 3 | 1-20 | Minimum bar spacing between opposite pivots. |
| `strategy_triangle_min_bars` | 30 | 10-200 | Minimum compression age. |
| `strategy_triangle_max_bars` | 200 | 30-240 | Maximum scan age for the triangle context. |
| `strategy_apex_max_bars` | 50 | 1-100 | Required forward apex projection window. |
| `strategy_p3_fib_tolerance` | 0.05 | 0.00-0.20 | Allowed distance from accepted point-3 retracement ratios. |
| `strategy_entry_buffer_pips` | 2 | 1-20 | Stop-entry buffer beyond point 2. |
| `strategy_stop_buffer_pips` | 5 | 1-50 | Stop-loss buffer beyond point 3. |
| `strategy_pending_valid_bars` | 50 | 1-100 | Pending stop order validity in H1 bars. |
| `strategy_time_stop_bars` | 480 | 1-2000 | Hard time stop for any open remainder. |
| `strategy_target1_fib` | 1.618 | 1.01-3.00 | First extension target and 40% partial close. |
| `strategy_target2_fib` | 2.618 | 1.10-5.00 | Second extension target and 40% partial close. |
| `strategy_target3_fib` | 4.236 | 1.20-8.00 | Final extension target. |
| `strategy_tp1_fraction` | 0.40 | 0.00-1.00 | Fraction of initial volume closed at target 1. |
| `strategy_tp2_fraction` | 0.40 | 0.00-1.00 | Fraction of initial volume closed at target 2. |
| `strategy_max_spread_points` | 0 | 0-500 | Optional spread guard; zero disables it. |

## 3. Symbol Universe

- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCAD.DWX`, `USDCHF.DWX`,
  `AUDUSD.DWX`, `NZDUSD.DWX`, `EURJPY.DWX`, `GBPJPY.DWX`, and `AUDJPY.DWX`.
- These are liquid DWX forex pairs with enough H1 history for the structural
  pattern scan.
- Explicitly not for metals, indices, energy, crypto, rates, or synthetic
  basket symbols in this build.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` through the V5 framework OnTick path |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 10-30 before Q02 calibration |
| Typical hold time | Hours to multiple days; hard cap is 20 days |
| Expected drawdown profile | Breakout-pattern losses cluster in false triangle breaks |
| Regime preference | Volatility compression followed by directional expansion |
| Win rate target | Medium; scaled exits seek convex winners |

## 6. Source Citation

This card was mechanised from Michel Selim, "Forex Bermuda Trading Strategy" on
superiorfxsignals.com, with the constituent pattern grammar drawn from classical
triangle, 1-2-3 reversal, and Fibonacci-extension literature. The approved farm
card is `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11902_bermuda-triangle-123-fib-extension-h1.md`
and records R1 track record, R2 mechanical, R3 data availability, and R4
forbidden-ML checks as PASS.

## 7. Risk Model

- Q02-Q10 backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Live burn-in would use `RISK_PERCENT` only after the portfolio and owner
  gates; this build does not configure live deployment.
- The EA uses the V5 risk sizer from the stop distance between pending entry
  and point-3 stop. No grid, martingale, pyramiding, ML, external feeds, T_Live,
  AutoTrading, deploy manifest, or portfolio-gate changes are involved.
