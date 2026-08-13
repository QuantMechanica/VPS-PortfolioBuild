# QM5_20305_xng-aliq-regime - Strategy Spec

**EA ID:** QM5_20305
**Slug:** `xng-aliq-regime`
**Source:** `YIYI-XNG-ALIQ-REGIME-2026`
**Author of this spec:** Codex
**Last revised:** 2026-08-13

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, consume one
attempt and load exactly 505 completed `XNGUSD.DWX` rates. Form two disjoint
252-log-return blocks, divide every absolute return by its ending bar's
strictly positive tick volume, multiply by 1,000,000, and average each block.
Buy XNG when recent ALIQ is higher and sell XNG when it is lower. A tie or
invalid state stays flat without retry.

Every entry has a frozen `3.5 * ATR(20,D1)` hard stop, no take-profit, monthly
replacement, and a forty-day stale exit.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_returns_per_block` | `252` | `[252]` | ALIQ terms per block |
| `strategy_preceding_block_offset` | `252` | `[252]` | Older return block offset |
| `strategy_history_bars_d1` | `505` | `[505]` | Completed D1 rate count |
| `strategy_aliq_scale` | `1000000.0` | `[1000000.0]` | Source scale |
| `strategy_state_tolerance` | `1e-12` | `[1e-12]` | Comparison tolerance |
| `strategy_max_endpoint_gap_days` | `10` | `[10]` | Endpoint freshness |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Stale close |
| `strategy_max_spread_points` | `3000` | `[3000]` | XNG entry spread ceiling |

All values are locked. No optimization or alternate estimator is authorized.

## 3. Symbol Universe

Designed only for registered `XNGUSD.DWX`, D1, magic slot 0. This is one
outright natural-gas carrier and not a port to XTI, XAU, XAG, or XBR.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Signal history | Exactly 505 completed rates |
| Decision clock | Genuine broker-month transition |
| Stop estimator | Completed `ATR(20,D1)` |
| Hold | Until next month transition, capped at 40 calendar days |

The current D1 bar and all incomplete returns are excluded.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11-12 after warm-up; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Drawdown profile | Sparse fixed-risk XNG losses with gap, roll, activity-proxy, and persistent-state exposure |
| State | Long when recent ALIQ is higher; short when lower |

The slow symmetric XNG activity-price-impact state differs structurally from
the incumbent short-horizon long-only XNG pullback. Q09 alone owns realized
overlap.

## 6. Source Citation

Qin, Yiyi; Cai, Jun; Zhu, Jie; and Webb, Robert (2025), "Commodity Futures
Characteristics and Asset Pricing Models," *Journal of Futures Markets*
45(3), 176-207, DOI `10.1002/fut.22559`.

The source defines dollar-volume ALIQ and a monthly broad-universe high-minus-
low sort. The EA's quote-tick proxy, two-block own-history comparison, and XNG
continuous-CFD carrier are locked QM hypotheses. The paired sibling's Q08
runs failure and WTI sibling's Q02 PF 1.01 remain material evidence.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | `RISK_FIXED` | `$1000` per trade |
| Live burn-in | `RISK_PERCENT` | Not authorized |
| Full live | `RISK_PERCENT` | Not authorized |

The mission creates one backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## 8. Exact Statistical Contract

Load 505 completed rates. For offsets 0 and 252, compute 252 log returns,
divide absolute return by the tick volume at the return's ending bar, multiply
by 1,000,000, and average. The blocks share close index 252 but no return or
tick-volume observation. Buy when recent minus preceding exceeds `1e-12`,
sell below `-1e-12`, and consume a tie or invalid state flat.

## 9. Non-Duplicate Boundary

`QM5_13140` is a concurrent two-leg XTI/XNG ALIQ rank. `QM5_20302` is the
same locked method on WTI and supplies no transferable result. `QM5_12567` is
short-horizon, long-only cumulative-RSI pullback logic. Other XNG moment,
trend, calendar, event, variance-ratio, and relative-value builds use other
state objects or clocks.

## 10. Kill Criteria

Retire below five completed positions per full post-warm-up year, on
nonpositive governed economics, or at later portfolio-correlation rejection.
Fail on wrong counts, offsets, return type, volume alignment or scale,
nonpositive used tick volume, reversed direction, repeated attempt, missing
stop, hold beyond forty days, risk mismatch, or nondeterminism. No rescue
parameter is authorized.

## 11. Safety Boundary

Research, deterministic allocation, build, strict compile/Q01, one fixed-risk
backtest set, and one paced non-live Q02 enqueue only. No manual backtest,
live/demo/shadow/stress/optimization set, `T_Live` access, AutoTrading change,
deploy manifest, portfolio-gate edit, portfolio admission, or correlation
waiver is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-13 | Initial scaffold from approved card | Build pending |

## 12. Q01 Status

PENDING. Populate only after implementation, strict compile, target build
checks, independent reference tests, and Q01 artifact validation pass.
