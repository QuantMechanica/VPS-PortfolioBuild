# QM5_41317 — WTI Monthly KPSS Trend

**EA ID:** QM5_41317

**Slug:** `wti-mkpss-tr`

**Strategy ID:** `KWIATKOWSKI-STATSMODELS-MOP-WTI-KPSS-20260902_S01`

**Author:** Development

**Last revised:** 2026-09-02

## 1. Strategy Logic

This EA implements the G0-approved card
`strategy-seeds/cards/approved/QM5_41317_wti-mkpss-tr_card.md` as a direct,
low-frequency `XTIUSD.DWX` D1 commodity sleeve. Sixty completed monthly WTI
log-price levels feed a constant-only KPSS statistic with four fixed
Bartlett/Newey–West covariance lags. A KPSS value at or above `0.347` gates
the sign of the newest twelve-month log return. This conjunction is a
QuantMechanica synthesis; Q09 alone can establish portfolio diversification.

## 2. Locked Parameters

| input | value | purpose |
|---|---:|---|
| `strategy_level_count` | 60 | completed chronological month-end closes/log levels |
| `strategy_covariance_lags` | 4 | fixed long-run-variance lag count |
| `strategy_residual_energy_floor` | `1e-18` | reject degenerate residual paths |
| `strategy_long_run_variance_floor` | `1e-18` | reject unstable/nonpositive denominators |
| `strategy_kpss_boundary` | `0.347` | inclusive constant-only 10% critical value |
| `strategy_momentum_months` | 12 | continuation direction horizon |
| `strategy_direction_epsilon` | `1e-12` | symmetric neutral band |
| `strategy_history_bars` | 1800 | bounded D1 endpoint reconstruction |
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
`413170000`. On the first executable tick after a genuine broker-month
change, reconstruct exactly 60 immediately prior consecutive month-end
closes, oldest to newest. The current month never enters the sample.

For `C[0..59]`, let `x[t]=ln(C[t])`, `e[t]=x[t]-mean(x)`, and
`S[t]=sum(e[0..t])`.

```text
eta = sum(S[t]^2, t=0..59) / 3600
cross[k] = sum(e[t]*e[t-k], t=k..59), k=1..4
weight[k] = 1-k/5
s_hat = (sum(e[t]^2)+2*sum(weight[k]*cross[k], k=1..4))/60
KPSS = eta/s_hat
mom12 = x[59]-x[47]

BUY  iff KPSS >= 0.347 and mom12 > +1e-12
SELL iff KPSS >= 0.347 and mom12 < -1e-12
FLAT otherwise
```

All closes and arithmetic must be finite; closes must be positive. Residual
energy must exceed `1e-18`, `eta` must be nonnegative, and `s_hat` must exceed
`1e-18`. KPSS magnitude never changes side or risk.

## 4. Clock, Attempt, And Lifecycle

Persist the normalized broker-month attempt before history reconstruction,
signal, news, spread, quote, ATR, sizing, margin, or order gates. A consumed
month is never retried. Reject late decisions, previous entry deals, owned
exposure, or foreign `XTIUSD.DWX` exposure. Entry spread must be finite and
within `[0,1500]` points.

A qualified decision opens at most one market position through the V5
fixed-dollar risk path with a frozen completed-bar `3.5*ATR(20,D1)` hard stop
and no target. Close on the first processed tick in a later normalized broker
month or after forty elapsed calendar days. Duplicate, wrong-symbol,
invalid-type, wrong-side, missing-stop, malformed entry time, or inconsistent
entry-month state triggers a defensive close. Restart recovery may use only
matching owned deal history.

There is no statistic exit, intramonth flip, Friday flatten, trail,
break-even move, partial close, resize, scale-in, grid, martingale, pyramid,
or retry. Both news axes, legacy news, Friday close, and stress rejection are
locked off. Framework kill switch and broker hard stop remain authoritative.

## 5. Source And Validation Boundary

The pinned statsmodels implementation fixes constant demeaning, cumulative
residuals, `eta`, Bartlett-weighted long-run variance, and the `0.347`
constant-only critical value. Kwiatkowski et al. provide method attribution;
Moskowitz, Ooi, and Pedersen provide monthly own-return continuation and WTI
membership. No source proves this exact conjunction, CFD transport,
economics, activity, or portfolio correlation.

Initialization runs deterministic stationary/trending/additive-shift/
degenerate fixtures. The independent Python suite separately checks the
formula, weights, fixture receipt, boundary, direction, endpoints, attempt
order, set/card/registry binding, and source guards.

Q02 must retire the variant on zero positions, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics,
nondeterminism, or any formula, fixed-risk, stop, attempt, or lifecycle
defect. No result-based parameter repair is authorized.

## 6. Risk And Safety

The baseline is exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; gaps can exceed modeled stop risk. Principal risks are
continuous-CFD roll/basis/financing, single-carrier concentration,
broker-month labeling, KPSS finite-sample size and lag choice, overlapping
windows, and nonstationarity unrelated to tradable continuation.

This build and Q02 queue item do not authorize live use, portfolio admission,
correlation waiver, terminal control, `T_Live`, or AutoTrading.

## Framework Alignment

- `Strategy_NoTradeFilter`: identity, magic, fixed-risk and framework locks.
- bounded helpers: month clock, attempt state, endpoints, KPSS, side, restart.
- `Strategy_EntrySignal`: exposure, spread, quote, ATR, frozen stop, and order.
- `Strategy_ManageOpenPosition`: malformed-state repair and time exits.
- `Strategy_ExitSignal`: no discretionary exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | approved-source build | G0-approved card; magic `413170000`; Q01 pending |
