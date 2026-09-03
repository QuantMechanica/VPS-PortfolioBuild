# QM5_41320 — WTI Monthly Phillips-Perron Persistence Trend

**EA ID:** QM5_41320

**Slug:** `wti-mpp-persist-tr`

**Strategy ID:** `AI-CODEX-WTI-MPP-PERSIST-TREND-20260903_S01`

**Author:** Development

**Last revised:** 2026-09-03

## 1. Strategy Logic

This EA implements the G0-approved card
`strategy-seeds/cards/approved/QM5_41320_wti-mpp-persist-tr_card.md` as a
direct, low-frequency `XTIUSD.DWX` D1 commodity sleeve. Sixty completed
monthly WTI log-price levels feed a level AR(1) with intercept. Eleven
Bartlett-weighted residual autocovariances produce the long-run variance in a
Phillips-Perron Z-tau correction. An inclusive corrected statistic of at least
`-2.594` gates the sign of the newest twelve-month log return.

The line is a frozen persistence-state classifier, not a finite-sample
p-value, unit-root finding, or stationarity claim. The conjunction is a
QuantMechanica synthesis; Q09 alone can establish portfolio diversification.

## 2. Locked Parameters

| input | value | purpose |
|---|---:|---|
| `strategy_level_count` | 60 | completed chronological month-end closes/log levels |
| `strategy_regression_observations` | 59 | adjacent level AR(1) rows |
| `strategy_residual_dof` | 57 | observations less intercept and slope |
| `strategy_bartlett_lags` | 11 | fixed HAC residual lags |
| `strategy_energy_floor` | `1e-18` | reject degenerate variance paths |
| `strategy_pp_z_tau_min` | `-2.594` | inclusive persistence-state line |
| `strategy_momentum_months` | 12 | continuation direction horizon |
| `strategy_direction_epsilon` | `1e-12` | symmetric neutral band |
| `strategy_history_bars` | 1200 | bounded D1 endpoint scan |
| `strategy_entry_grace_minutes` | 180 | first-month-bar entry window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | inclusive entry-cost ceiling |

Q02 has one set only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## 3. Exact Signal

The host, traded carrier, and slot are `XTIUSD.DWX`, D1, slot zero, magic
`413200000`. On the first executable tick after a genuine broker-month
change, reconstruct exactly 60 immediately prior consecutive month-end
closes, oldest to newest. The current month never enters the sample.

For `C[0..59]`, let `x[t]=ln(C[t])`. For `i=0..58`, regress:

```text
lhs[i] = x[i+1]
rhs[i] = x[i]
lhs[i] = alpha + rho*rhs[i] + u[i]

Sxx     = sum((rhs[i]-mean(rhs))^2)
SSE     = sum(u[i]^2)
s2      = SSE/57
s       = sqrt(s2)
gamma0  = SSE/59
se_rho  = sqrt(s2/Sxx)
raw_tau = (rho-1)/se_rho
```

For `j=1..11`, use covariance divisor 59 and Bartlett weight
`w[j]=1-j/12`:

```text
gamma[j] = sum(i=j..58, u[i]*u[i-j])/59
lambda2  = gamma0 + 2*sum(j=1..11, w[j]*gamma[j])

PP_Ztau =
  sqrt(gamma0/lambda2)*raw_tau
  - 0.5*((lambda2-gamma0)/sqrt(lambda2))*(59*se_rho/s)

mom12 = x[59]-x[47]

BUY  iff PP_Ztau >= -2.594 and mom12 > +1e-12
SELL iff PP_Ztau >= -2.594 and mom12 < -1e-12
FLAT otherwise
```

All closes and arithmetic must be finite; closes must be positive. `Sxx`,
`SSE`, `s2`, `s`, `gamma0`, `lambda2`, and `se_rho` must exceed
`1e-18`. Statistic magnitude never changes side or risk.

## 4. Clock, Attempt, And Lifecycle

Persist the normalized broker-month attempt before history reconstruction,
signal, news, spread, quote, ATR, sizing, margin, or order gates. A consumed
month is never retried. Reject late decisions, previous entry deals, owned
exposure, or foreign `XTIUSD.DWX` exposure. Entry spread must be finite and
within `[0,1500]` points.

A qualified decision opens at most one market position through the V5
fixed-dollar risk path with a frozen completed-bar `3.5*ATR(20,D1)` hard
stop and no target. Close on the first processed tick in a later normalized
broker month or after forty elapsed calendar days. Duplicate, wrong-symbol,
invalid-type, wrong-side, missing-stop, malformed entry time, or inconsistent
entry-month state triggers a defensive close. Restart recovery may use only
matching owned deal history.

There is no statistic exit, intramonth flip, Friday flatten, trail,
break-even move, partial close, resize, scale-in, grid, martingale, pyramid,
or retry. Both news axes, legacy news, Friday close, and stress rejection are
locked off. Framework kill switch and broker hard stop remain authoritative.

## 5. Source And Validation Boundary

Phillips and Perron supply the corrected unit-root statistic and explicitly
warn about finite-sample size distortion under negative moving-average
errors. Moskowitz, Ooi, and Pedersen supply monthly own-return continuation
and WTI membership. Neither source validates this conjunction, sixty-month
continuous-CFD sample, fixed eleven-lag choice, threshold transport,
activity, economics, or correlation.

Initialization runs deterministic qualifying-up, qualifying-down,
mean-reverting-rejection, and degenerate fixtures. The independent Python
suite checks the AR(1), residual HAC, PP correction, fixture receipt,
additive-level invariance, boundary, direction, endpoints, attempt order,
set/card/registry binding, and source guards.

Q02 must retire the unchanged variant on zero positions, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, nondeterminism, or any formula, fixed-risk, stop, attempt, or
lifecycle defect. No result-based parameter repair is authorized.

## 6. Risk And Safety

The baseline is exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; gaps can exceed modeled stop risk. Principal risks are
continuous-CFD roll/basis/financing, single-carrier concentration,
broker-month labeling, PP finite-sample distortion, overlapping windows, and
persistence unrelated to tradable continuation.

This build and Q02 queue item do not authorize live use, portfolio admission,
correlation waiver, terminal control, `T_Live`, or AutoTrading.

## Framework Alignment

- `Strategy_NoTradeFilter`: identity, magic, fixed-risk and framework locks.
- Bounded helpers: month clock, attempt state, endpoints, PP Z-tau, side, restart.
- `Strategy_EntrySignal`: exposure, spread, quote, ATR, frozen stop, order.
- `Strategy_ManageOpenPosition`: malformed-state repair and time exits.
- `Strategy_ExitSignal`: no discretionary exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-03 | approved-source build | G0-approved card; magic `413200000`; Q01 pending |
