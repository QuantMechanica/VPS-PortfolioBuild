# QM5_20297_xng-kurt-prem — Strategy Spec

**EA ID:** QM5_20297
**Slug:** `xng-kurt-prem`
**Source:** `HOLLSTEIN-XNG-KURT-2026`
**Author of this spec:** Codex
**Last revised:** 2026-08-13

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, load exactly 253
completed XNG D1 closes and compute 252 chronological simple returns. Calculate
the source-defined Pearson historical kurtosis using sample variance with
denominator 251 and fourth central moment with denominator 252. Buy above the
fixed normal benchmark of three, sell below three, and consume a numerical tie
or invalid state flat. Every entry has a frozen `3.5 * ATR(20,D1)` hard stop,
no take-profit, monthly replacement, and a forty-day stale exit.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_d1` | `252` | `[252]` | Exact completed simple-return count |
| `strategy_history_bars` | `320` | `[320]` | Bounded completed D1 history request |
| `strategy_max_endpoint_gap_days` | `10` | `[10]` | Latest completed endpoint freshness |
| `strategy_variance_floor` | `1e-12` | `[1e-12]` | Positive source sample-variance floor |
| `strategy_kurtosis_benchmark` | `3.0` | `[3.0]` | Fixed Pearson normal benchmark |
| `strategy_kurtosis_tolerance` | `1e-12` | `[1e-12]` | Symmetric benchmark tolerance |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `2500` | `[2500]` | XNG entry spread ceiling |

All values are locked for baseline. No optimization or alternate estimator is
authorized.

## 3. Symbol Universe

Designed only for registered `XNGUSD.DWX`, D1, magic slot 0. It is not a port
to XTI, XAU, XAG, XBR, or an unregistered gas proxy. The carrier is outright
natural gas, not a two-leg rank or ratio basket.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Signal window | Exactly 252 completed simple returns |
| Decision clock | Genuine broker-month transition |
| Stop estimator | Completed `ATR(20,D1)` |
| Hold | Until next month transition, capped at 40 calendar days |

The current D1 bar and any incomplete return do not enter the signal.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11-12 after warm-up; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Drawdown profile | Sparse fixed-risk XNG fourth-moment losses with weather-jump and regime-persistence exposure |
| State | Long above Pearson kurtosis 3; short below 3 |

The natural-gas carrier and fourth-moment state are diversification hypotheses
only. The signal is structurally unlike the certified XNG cumulative-RSI
pullback, but Q09 owns any realized portfolio-overlap conclusion.

## 6. Source Citation

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021),
"Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance*
11(4), article 2150017, DOI `10.1142/S2010139221500178`.

The source defines prior-year Pearson historical kurtosis, reports a positive
full-sample cross-sectional relation, uses monthly sorts, and includes natural
gas. The two-way result and regression slope are insignificant, and the later
subperiod reverses sign insignificantly. The absolute benchmark-three rule is
a locked QM hypothesis, not a source-tested XNG rule. See the bounded source
packet and canonical card.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | `RISK_FIXED` | `$1000` per trade |
| Live burn-in | `RISK_PERCENT` | Not authorized |
| Full live | `RISK_PERCENT` | Not authorized |

The mission creates one backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## 8. Exact Statistical Contract

```text
r[d] = close[d] / close[d-1] - 1
mu = sum(r[d]) / 252
s2 = sum((r[d] - mu)^2) / 251
m4 = sum((r[d] - mu)^4) / 252
kurtosis = m4 / (s2^2)
```

Require exactly 253 positive finite closes, 252 returns, strictly increasing
timestamps, a latest endpoint before the decision bar and at most ten days
stale, finite arithmetic, and `s2 > 1e-12`. Buy above `3.0 + 1e-12`, sell below
`3.0 - 1e-12`, and consume a tie or invalid state flat. Never use excess
kurtosis, bias correction, population variance, or magnitude-scaled risk.

## 9. Non-Duplicate Boundary

`QM5_13131` and `QM5_20291` are two-leg cross-sectional kurtosis ranks;
`QM5_20295` is the separately governed WTI carrier. This EA has one absolute
XNG state, one magic, one position, no relative rank, and no orphan state.
`QM5_20296` uses third-moment skewness around zero. `QM5_13130` and
`QM5_20294` use only the five largest returns. `QM5_12567` is a short-horizon
long-only oscillator pullback. Other XNG trend, reversal, calendar, event,
breakout, and variance-ratio systems use different information objects.

## 10. Kill Criteria

Retire below five completed positions per full post-warm-up year, on
nonpositive governed economics, or at later portfolio-correlation rejection.
Fail on the wrong return count/orientation, wrong denominator, excess
kurtosis, fitted pivot, inverted direction, repeated attempt, missing stop,
hold beyond forty days, risk mismatch, or nondeterminism. No rescue parameter
is authorized.

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

PENDING. The EA ID is reserved; magic allocation and implementation are not
yet complete.

## 13. Q02 Handoff

NOT ENQUEUED. Q01 is a hard prerequisite.
