# QM5_20301_wti-es-regime - Strategy Spec

**EA ID:** QM5_20301
**Slug:** `wti-es-regime`
**Source:** `YIYI-WTI-ES-REGIME-2026`
**Author of this spec:** Codex
**Last revised:** 2026-08-13

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, consume one
attempt and load exactly 505 completed `XTIUSD.DWX` D1 closes. Calculate the
source expected-shortfall characteristic - the arithmetic mean of the worst
five percent of simple returns - over two consecutive, disjoint 252-return
blocks. Buy when recent ES is higher (less negative) than preceding ES and
sell when it is lower. Every entry has a frozen `3.5 * ATR(20,D1)` hard stop,
no take-profit, monthly replacement, and a forty-day stale exit.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_returns_per_block` | `252` | `[252]` | Simple returns per ES block |
| `strategy_tail_probability` | `0.05` | `[0.05]` | Lower-tail fraction |
| `strategy_prior_block_offset` | `252` | `[252]` | Preceding block return offset |
| `strategy_history_bars_d1` | `505` | `[505]` | Exact completed D1 close count |
| `strategy_max_endpoint_gap_days` | `10` | `[10]` | Latest endpoint freshness |
| `strategy_es_tolerance` | `1e-12` | `[1e-12]` | Symmetric comparison tolerance |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `1500` | `[1500]` | WTI entry spread ceiling |

All values are locked. No optimization or alternate estimator is authorized.

## 3. Symbol Universe

Designed only for registered `XTIUSD.DWX`, D1, magic slot 0. This is one
outright WTI carrier, not an XTI/XNG or XAU/XAG rank basket and not a port to
XNG, XAU, XAG, or XBR.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Signal history | Exactly 505 completed closes |
| Decision clock | Genuine broker-month transition |
| Stop estimator | Completed `ATR(20,D1)` |
| Hold | Until next month transition, capped at 40 calendar days |

The current D1 bar and all incomplete returns are excluded.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11-12 after warm-up; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Drawdown profile | Sparse fixed-risk WTI downside-tail-state losses with gap, roll, and persistent-state exposure |
| State | Long when recent ES is higher; short when recent ES is lower |

The WTI carrier and downside-tail state are diversification hypotheses
relative to the incumbent XAU/SP500/NDX/XNG book. Q09 alone owns realized
overlap.

## 6. Source Citation

Qin, Yiyi; Cai, Jun; Zhu, Jie; and Webb, Robert (2025), "Commodity Futures
Characteristics and Asset Pricing Models," *Journal of Futures Markets*
45(3), 176-207, DOI `10.1002/fut.22559`.

The source defines prior-year expected shortfall as the mean of the worst five
percent of daily returns, uses monthly high-minus-low sorts, and reports weak
full-sample one-way significance. The EA's two-block own-history comparison is
a locked QM hypothesis, not a source-tested WTI rule. The paired energy
sibling's Q04 failure is retained as adverse evidence.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | `RISK_FIXED` | `$1000` per trade |
| Live burn-in | `RISK_PERCENT` | Not authorized |
| Full live | `RISK_PERCENT` | Not authorized |

The mission creates one backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## 8. Exact Statistical Contract

```text
r[b,k] = close[b+k] / close[b+k+1] - 1, k=0..251
K      = ceil(252 * 0.05) = 13
ES[b]  = arithmetic_mean(13 smallest r[b,0..251])

recent block b=0:       close-index pairs 0/1 through 251/252
preceding block b=252:  close-index pairs 252/253 through 503/504
```

Require positive finite closes, strictly older timestamps by increasing
series index, a fresh completed endpoint, finite simple returns, and exactly
thirteen selected observations per block. Buy above the preceding value by
more than `1e-12`, sell below it by more than `1e-12`, and consume a tie or
invalid state flat.

## 9. Non-Duplicate Boundary

`QM5_13143` and `QM5_20235` are two-leg cross-sectional ES ranks. This EA
compares two disjoint WTI history blocks, owns one magic, and has no shared
risk or orphan leg. `QM5_20300` averages five largest returns and buys the
lower-MAX state. `QM5_20289` uses one-month signed semivariance. WTI trend,
calendar, event, variance-ratio, robust-location, breakout, skewness,
kurtosis, and VoV builds use other state objects. `QM5_12567` is a short-
horizon long-only RSI pullback.

## 10. Kill Criteria

Retire below five completed positions per full post-warm-up year, on
nonpositive governed economics, or at later portfolio-correlation rejection.
Fail on wrong history count/orientation, wrong return type, overlapping block
support, tail count other than thirteen, wrong tail, inverted direction,
repeated attempt, missing stop, hold beyond forty days, risk mismatch, or
nondeterminism. No rescue parameter is authorized.

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
| v2 | 2026-08-13 | Implemented locked WTI carrier and monthly lifecycle | Strict compile and reference checks pass |

## 12. Q01 Status

PASS. The registered one-slot EA implements the exact two-block expected-
shortfall estimator, restart-safe monthly attempt state, one-position
lifecycle, frozen hard stop, and fixed-risk contract. Strict compile passed
with zero errors and zero warnings; the target build check passed with zero
failures and zero warnings; six independent statistic, direction, support,
invariance, chronology, count, and freshness tests passed; and P1 artifact
validation found the compiled `.ex5`.

## 13. Q02 Handoff

NOT ENQUEUED. Q01 is PASS; a fresh seven-terminal capacity check remains
required immediately before the target-only paced handoff.
