# QM5_21522_wti-lowdb-trend - Strategy Spec

**EA ID:** QM5_21522  
**Slug:** `wti-lowdb-trend`  
**Source:** `MOP-HOLLSTEIN-WTI-LOWDB-2026`  
**Author of this spec:** Codex  
**Last revised:** 2026-08-14

## 1. Strategy Logic

On the first processed `XTIUSD.DWX` D1 bar after a genuine broker-month
transition, the EA consumes one attempt before every signal or execution gate.
It derives WTI's exact twelve-completed-month return from an independent set
of thirteen consecutive completed month ends. Separately, it intersects
completed WTI and read-only `SP500.DWX` D1 bars by exact timestamp and retains
the newest exactly 505 common closes.

Those closes form 504 chronological simple returns. Returns 0-251 are the
preceding block and returns 252-503 are the recent block; the blocks share only
close 252 and no return. In each block the EA computes the mean of all 252
SP500 returns, selects strict below-mean observations, requires at least 100,
and estimates intercept OLS WTI downside beta. A positive WTI trend is bought
and a negative trend is sold only when:

```text
beta_recent < beta_preceding - 1e-12
```

A non-falling beta, exact-zero trend, invalid regression, or unavailable
history consumes the month flat. SP500 is never ordered.

## 2. Locked Parameters

| Parameter | Default | Authorized values |
|---|---:|---|
| `strategy_trend_months` | `12` | `[12]` |
| `strategy_trend_history_bars_d1` | `500` | `[500]` |
| `strategy_beta_returns_per_block` | `252` | `[252]` |
| `strategy_beta_recent_block_offset` | `252` | `[252]` |
| `strategy_beta_common_closes` | `505` | `[505]` |
| `strategy_beta_history_bars_d1` | `900` | `[900]` |
| `strategy_min_down_days` | `100` | `[100]` |
| `strategy_beta_tolerance` | `1e-12` | `[1e-12]` |
| `strategy_variance_epsilon` | `1e-16` | `[1e-16]` |
| `strategy_max_endpoint_gap_days` | `10` | `[10]` |
| `strategy_atr_period_d1` | `20` | `[20]` |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` |
| `strategy_max_hold_days` | `40` | `[40]` |
| `strategy_max_spread_points` | `1500` | `[1500]` |

There is no optimizer range, fallback estimator, or alternate carrier.

## 3. Symbols And Timeframe

| Role | Symbol | Timeframe | Authority |
|---|---|---|---|
| Host and traded carrier | `XTIUSD.DWX` | D1 | slot 0, magic `215220000` |
| Downside-factor input | `SP500.DWX` | D1 | read-only; no magic or order |

The latest daily endpoints must precede the decision bar and be no more than
ten calendar days stale. Monthly endpoints must end in the immediately
completed broker month.

## 4. Statistical Contract

For each 252-return block `b`:

```text
market_mean_b = mean(r_SP500[all 252 rows])
D_b = {i: r_SP500_i < market_mean_b}
beta_b = sum((r_WTI_i - mean_D(r_WTI)) *
             (r_SP500_i - mean_D(r_SP500))) /
         sum((r_SP500_i - mean_D(r_SP500))^2), i in D_b
```

The strict inequality excludes ties. Each `D_b` must contain at least 100
rows and its market variance sum must exceed `1e-16`. Demeaning both selected
series is the intercept OLS slope; a common `n` or `n-1` divisor cancels.

The trend is:

```text
trend_12m = ln(last completed WTI month end /
               WTI month end twelve months earlier)
```

The endpoint result must equal the sum of twelve adjacent monthly log returns
within `1e-10`.

## 5. Execution And Lifecycle

The only backtest risk contract is `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Each entry receives a frozen
`3.5 * ATR(20,D1)` broker hard stop and no take-profit. The prior position is
closed before the next monthly evaluation, with a forty-calendar-day stale
guard. Malformed owned state is repaired before entry gates. Friday close and
all news modes are locked off.

A persistent month marker plus owned position and deal history prevents
same-month retries. No flat, filtered, failed, stopped, or closed decision may
retry. There is no scale-in, partial close, pyramid, grid, martingale,
intramonth signal exit, or SP500 order path.

## 6. Source Boundary And Adverse Evidence

Moskowitz, Ooi, and Pedersen (2012) supply WTI membership, twelve-month
own-return-sign direction, and monthly cadence. Hollstein, Prokopczuk, and
Tharann (2021) supply the downside-beta definition and low-beta orientation,
but report DownBeta as mostly unpriced, insignificant, and unstable. That null
is binding: the exact falling-beta time-series gate is a new QM falsification,
not a sourced return claim.

Continuous CFD mapping, raw SP500 substitution, zero risk-free rate, the two
disjoint blocks, falling-beta inequality, risk, stop, spread, and portfolio
diversification claim are all QM design choices. Q02 owns baseline economics
and density; Q09 alone owns realized correlation to the existing book.

## 7. Kill Criteria

Retire on zero trades or fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, or later correlation
rejection. Fail on wrong endpoint or return counts, nonconsecutive month ends,
timestamp mismatch, overlapping return blocks, pooled market means,
non-strict down-day selection, fewer than 100 rows, singular regression,
wrong beta or trend direction, same-month retry, SP500 order, missing stop,
risk mismatch, hold beyond forty days, or nondeterminism.

## 8. Safety Boundary

Authorized: deterministic build, strict compile/Q01, one
`XTIUSD.DWX` D1 fixed-risk backtest set, and one paced non-live Q02 enqueue
when CPU capacity permits. Not authorized: manual backtest, optimization,
live/demo/shadow/stress artifact, AutoTrading, `T_Live`, deploy manifest,
portfolio-gate edit, portfolio admission, or correlation waiver.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-14 | Initial scaffold from approved card | Build implementation complete |
| v2 | 2026-08-14 | Validate exact implementation and artifacts | Q01 PASS |

## 9. Q01 Status

PASS. The registered one-slot EA implements an independent thirteen-month-end
WTI trend path and exactly 505 synchronized WTI/SP500 closes split into two
disjoint 252-return blocks. Each block uses its own full-sample market mean,
strict below-mean selection, minimum support, and intercept OLS slope. SP500
is read-only; the month is consumed before signal and execution gates; the
single WTI position receives fixed-dollar V5 sizing and a frozen ATR stop.

Strict MetaEditor compilation passed with zero errors and warnings. The
targeted static build gate passed with zero failures and warnings; seven
independent formula and boundary tests passed; and P1 found the compiled
`.ex5`. No Strategy Tester run was launched during Q01.
