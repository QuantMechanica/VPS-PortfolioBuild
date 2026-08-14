# QM5_21516_wti-decoup-trend - Strategy Spec

**EA ID:** QM5_21516
**Slug:** `wti-decoup-trend`
**Source:** `MOP-EIA-WTI-DECOUP-2026`
**Author of this spec:** Codex
**Last revised:** 2026-08-14

## 1. Strategy Logic

On the first D1 bar after a genuine broker-month transition, consume one
attempt and intersect bounded completed `XTIUSD.DWX` and read-only
`XNGUSD.DWX` D1 histories at exact timestamps. Calculate Pearson correlation
from exactly the latest 63 synchronized simple returns. Only when its absolute
value is at most `0.30 + 1e-12`, buy WTI on a positive exact twelve-month WTI
log return or sell WTI on a negative return. A high-correlation, zero-return,
or invalid state consumes the month flat.

Every entry has a frozen `3.5 * ATR(20,D1)` hard stop, no take-profit, monthly
replacement, and a forty-calendar-day stale exit. XNG is never ordered.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trend_months` | `12` | `[12]` | Exact completed-month trend horizon |
| `strategy_corr_return_days` | `63` | `[63]` | Synchronized simple-return sample |
| `strategy_corr_abs_max` | `0.30` | `[0.30]` | Absolute Pearson admission ceiling |
| `strategy_corr_tolerance` | `1e-12` | `[1e-12]` | Range and threshold tolerance |
| `strategy_history_bars_d1` | `500` | `[500]` | Bounded completed-D1 copy per symbol |
| `strategy_max_endpoint_gap_days` | `10` | `[10]` | Latest common endpoint freshness |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `1500` | `[1500]` | WTI entry spread ceiling |

All values are locked. No optimization or alternate estimator is authorized.

## 3. Symbol Universe

The only traded symbol is registered `XTIUSD.DWX`, D1, magic slot 0, magic
`215160000`. Registered `XNGUSD.DWX` is a read-only state input with no slot or
magic and no order authority. This is an outright WTI carrier, not an XTI/XNG
basket, ratio, spread, or hedge.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Signal history | Latest 64 exact timestamp-matched completed closes for correlation; 13 consecutive completed WTI month ends for trend |
| Decision clock | First processed D1 bar after a genuine broker-month transition |
| Stop estimator | Completed `ATR(20,D1)` |
| Hold | Until the next month transition, capped at 40 calendar days |

Current D1 prices and incomplete returns are excluded.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 5-9 after warm-up; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Drawdown profile | Sparse fixed-risk WTI losses with gap, roll, threshold, and persistent-state exposure |
| State | Long positive WTI trend and short negative trend only in weak XTI/XNG daily-return co-movement |

The crude-oil carrier is a diversification hypothesis relative to the
incumbent XAU/SP500/NDX/XNG book. Q09 alone owns realized portfolio overlap.

## 6. Source Citation

Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), "Time
Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Villar, Jose A., and Frederick L. Joutz (2006), "The Relationship Between
Crude Oil and Natural Gas Prices," U.S. Energy Information Administration;
Ramberg, David J., and John E. Parsons (2012), "The Weak Tie Between Natural
Gas and Oil Prices," *The Energy Journal* 33(2), 13-35, DOI
`10.5547/01956574.33.2.2`.

The primary source supplies WTI membership, own-return sign, a twelve-month
horizon, and monthly renewal. The oil-gas sources supply weak and changing
linkage context. The 63-return Pearson sample and `0.30` ceiling are locked QM
hypotheses, not source-tested trading rules.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | `RISK_FIXED` | `$1000` per trade |
| Live burn-in | `RISK_PERCENT` | Not authorized |
| Full live | `RISK_PERCENT` | Not authorized |

The one backtest set uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## 8. Exact Statistical Contract

Intersect completed WTI and XNG D1 bars by exact timestamp. Require strict
chronology, positive finite closes, at least 64 common closes, a newest common
endpoint before the decision bar, and no more than ten calendar days stale.
From the latest 64 closes form 63 chronological simple returns per symbol:

```text
x_i = XTI_i / XTI_(i-1) - 1
y_i = XNG_i / XNG_(i-1) - 1

rho = sample_covariance(x,y) /
      sqrt(sample_variance(x) * sample_variance(y))
```

Means, covariance, and variances use the exact 63-row sample; covariance and
both variances use denominator `62`. Require positive finite variances and a
finite raw coefficient within `[-1-1e-12, 1+1e-12]`. Admit the trend only when
`abs(rho) <= 0.30 + 1e-12`.

Derive thirteen consecutive completed broker-month WTI endpoints ending in
the immediately prior broker month. Set
`trend_12m = ln(last_month_end / first_month_end)` and require it to equal the
sum of twelve component monthly log returns within `1e-10`. Positive is long,
negative is short, and exact zero is flat.

## 9. Non-Duplicate Boundary

Unconditional and alternate-horizon WTI trend EAs do not require weak
synchronized XTI/XNG return correlation. XTI/XNG ratio, residual, beta, jump,
tail, volatility, rank, and spread EAs trade or rank a cross-energy state;
this EA only uses correlation as a gate and orders one WTI leg. The incumbent
`QM5_12567` is a short-horizon long-only XNG oscillator pullback. The WTI
carrier, exact twelve-month sign, 63-return Pearson gate, absolute ceiling,
read-only XNG boundary, and consumed monthly attempt are jointly load-bearing.

## 10. Kill Criteria

Retire below five completed positions per full post-warm-up year, on
nonpositive governed economics, or at later portfolio-correlation rejection.
Fail on wrong month-end/return count, timestamp mismatch, population or rank
correlation, wrong return type, high-correlation entry, inverted trend, any
XNG order, repeated attempt, missing stop, hold beyond forty days, risk
mismatch, or nondeterminism. No rescue parameter is authorized.

## 11. Safety Boundary

Research, deterministic allocation, build, strict compile/Q01, one fixed-risk
backtest set, and one paced non-live Q02 enqueue only. No manual backtest,
live/demo/shadow/stress/optimization set, `T_Live` access, AutoTrading change,
deploy manifest, portfolio-gate edit, portfolio admission, or correlation
waiver is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-14 | Initial scaffold from approved card | Build pending |
| v2 | 2026-08-14 | Implement locked decoupled-trend contract | Strict compile, static build, reference, and P1 checks pass |

## 12. Q01 Status

PASS. The registered one-slot EA implements exact timestamp synchronization,
63 simple-return sample Pearson correlation, the inclusive absolute `0.30`
gate, thirteen consecutive completed WTI month ends, exact twelve-month trend,
restart-safe consumed attempts, one-position lifecycle, frozen ATR hard stop,
and fixed-risk contract while leaving XNG read-only. Strict compile passed
with zero errors and warnings; the target static build check passed with zero
failures and warnings; six independent formula, boundary, support, variance,
direction, and carrier tests passed; and P1 found the compiled `.ex5`.
