---
ea_id: QM5_20059
slug: wti-tsmom6m
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_S06
source_id: MOP-TSMOM-2012
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250. DOI: 10.1016/j.jfineco.2011.11.003."
target_symbols: [XTIUSD.DWX]
logical_symbol: QM5_20059_WTI_TSMOM6M_D1
period: D1
expected_trade_frequency: "Monthly WTI six-month time-series-momentum package; approximately 8-12 entries/year when the return clears the neutral band."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
expected_pf: 1.10
expected_dd_pct: 20.0
strategy_type_flags: [time-series-momentum, medium-horizon-trend, atr-hard-stop, time-stop, low-frequency]
g0_approval_reasoning: "OWNER commodity-sleeve mission authorizes the build. R1 PASS peer-reviewed JFE source; R2 PASS locked completed-bar 126-D1 return sign, monthly renewal, ATR hard stop, and stale guard; R3 PASS registered XTI D1 data; R4 PASS no ML, banned indicator, external feed, grid, martingale, or pyramiding. Exact dedup CLEAN: existing WTI TSMOM builds use 3-month, 9-month-plus-3-month confirmation, 12-month, or twelve monthly-sign breadth; no registered EA uses a standalone six-month sign."
---

# WTI Six-Month Time-Series Momentum

## Hypothesis

WTI supply, inventory, producer-hedging, and investment regimes can persist
for several months. The sign of the completed 126-D1 return supplies a
medium-horizon structural trend sleeve between the already-built three-month
and twelve-month variants, adding crude-oil exposure to the
XAU/SP500/NDX/XNG book.

## Markets And Timeframe

Trade `XTIUSD.DWX` on D1. Evaluate only on the first tradable D1 bar of each
broker month using completed D1 closes.

## Entry Rules

- Compute `ln(Close[1] / Close[127])`, a completed-bar 126-D1 return.
- Enter long when the return is above the fixed neutral threshold.
- Enter short when the return is below the negative threshold.
- Do not trade inside the neutral band.
- Allow at most one entry per broker month and one position per magic.
- Reject entry when the current spread exceeds 1000 points.

## rules

Use MT5-native completed D1 bars and broker calendar only. Never pyramid,
average down, query an external feed, or re-enter within the same broker
month.

## Exit Rules

Close the prior package on the next monthly rebalance before considering a
new signal. Close any stale package after 31 calendar days. Attach a frozen
ATR(20) x 3.5 hard stop at entry. Framework Friday-close and news entry gates
remain enabled.

## Parameters To Test

- `strategy_momentum_lookback_d1`: default 126; locked for Q02
- `strategy_min_abs_return_pct`: default 0.0; range [0.0, 2.0, 5.0]
- `strategy_atr_period`: default 20; range [14, 20, 30]
- `strategy_atr_sl_mult`: default 3.5; range [3.0, 3.5, 4.0]
- `strategy_max_hold_days`: default 31; range [28, 31]
- `strategy_max_spread_points`: default 1000; locked for Q02

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position size is framework-derived from the frozen ATR
stop distance. No live setfile or live authorization exists.

## Kill Criteria

- Retire if Q02 produces fewer than 5 trades/year on XTIUSD.DWX.
- Retire on invalid or insufficient D1 history, non-finite momentum, or
  inability to enforce the frozen hard stop.
- Reject if implementation uses current-bar data, an external feed, ML,
  banned indicators, grid, martingale, averaging down, or pyramiding.
- Later portfolio correlation evidence decides orthogonality; this card does
  not claim a correlation pass in advance.

## Review Focus

Verify the 126-D1 completed-bar indexing, first-bar-of-month single-fire
guard, close-before-renew ordering, frozen ATR stop, and exact dedup result.
The intended book driver is medium-horizon crude supply/inventory trend, not
the incumbent XNG RSI logic or index/metal mean reversion.

## Strategy Allowability Check

- R1: PASS — peer-reviewed Journal of Financial Economics source with DOI.
- R2: PASS — fixed schedule, return formula, directions, exits, and risk.
- R3: PASS — registered `XTIUSD.DWX` D1 history route.
- R4: PASS — MT5-native price/ATR only; no ML or banned indicator.
- Frequency: expected 8-12 entries/year, above the Q02 floor.
- Non-duplicate: `QM5_20055` is standalone 63-D1 momentum;
  `QM5_12616` is a 9-month signal gated by 3-month confirmation;
  `QM5_12603` is standalone 12-month momentum; `QM5_13150` is twelve
  monthly-sign breadth. This card is standalone 126-D1 momentum.

## Framework Alignment

- no_trade: enforce XTI D1, slot, parameter, position, and spread guards.
- trade_entry: first broker-month D1 bar and completed 126-D1 return sign.
- trade_management: close at monthly renewal or 31-day stale guard.
- trade_close: framework frozen ATR hard stop plus deterministic time exits.

## Evidence Log

| Gate | Date | Result | Evidence |
|---|---|---|---|
| G0 | 2026-07-23 | APPROVED under OWNER commodity-sleeve mission | This card |
| Q01 Build Validation | 2026-07-23 | PASS: strict compile 0 errors/0 warnings; schema lint PASS | `docs/ops/evidence/2026-07-23_qm5_20059_wti_tsmom6m_q02_enqueue.md` |
