# QM5_1074_as-daa-canary SPEC

## Scope

Build-only V5 EA for the approved card `QM5_1074_as-daa-canary`.

The original Defensive Asset Allocation strategy is a monthly ETF rotation using canary momentum. The V5/DWX port is reduced to a single chart-symbol risk sleeve because the full ETF risky/protective universe is not MT5 broker-routable.

## Card Mapping

- Timeframe: D1 execution, monthly rebalance detected on the first D1 bar of a new month.
- Momentum score: `12*(p0/p1-1) + 4*(p0/p3-1) + 2*(p0/p6-1) + (p0/p12-1)` on closed MN1 bars.
- Canary universe: configurable by `strategy_canary_1_symbol` and `strategy_canary_2_symbol`.
- Default proxy decision: `strategy_canary_1_symbol=NDX.DWX`; `strategy_canary_2_symbol=""` uses `strategy_cash_canary_score=0.0`.
- Entry: long chart symbol when canary regime allows risk and chart-symbol weighted momentum is positive.
- Exit: monthly flat when canary regime no longer allows risk or chart-symbol weighted momentum is non-positive.
- Stops: source has no intramonth stop; EA uses framework/risk sizing with a catastrophic ATR stop.
- Trade management: no trailing, break-even, partial close, or pyramiding.

## Inputs

- `strategy_max_negative_canaries_for_entry`: default `0`; strict risk-on only. A value of `1` can model the published partial-risk DAA case, but single-sleeve sizing must then be reviewed through setfile `PORTFOLIO_WEIGHT`.
- `strategy_min_monthly_bars`: default `14`, enough for 12-month lookback plus current/closed-bar indexing.
- `strategy_atr_period_d1`: default `20`.
- `strategy_atr_sl_mult`: default `4.0`.
- `strategy_max_spread_points`: default `0` disabled.

## Known Porting Limitation

The card explicitly marks canary/protective bond proxy mapping as unresolved. This EA does not claim to implement the full multi-asset DAA allocation. It provides a deterministic reduced DWX canary port for P1/P2 feasibility and CTO review.

Live promotion note from the card remains binding: if evidence is generated only on `SP500.DWX`, T6 requires parallel validation on `NDX.DWX` or `WS30.DWX`.
