# QM5_41315_wti-archlm-tr - Strategy Spec

**EA ID:** QM5_41315

**Slug:** `wti-archlm-tr`

**Strategy ID:** `ENGLE-STATSMODELS-MOP-WTI-ARCHLM-20260902_S01`

**Source:** `ENGLE-STATSMODELS-MOP-WTI-ARCHLM-20260902`

**Author:** Development

**Last revised:** 2026-09-02

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of each normalized broker month,
reconstruct sixty-one consecutive completed broker-month-end closes and form
sixty chronological adjacent log returns. Demean the returns, divide their
squares by the positive mean squared residual, and regress each normalized
square at `t=6..59` on an intercept and its exact lags 1 through 6.

When `ARCH_LM=54*centered_R2 >= 4.73`, follow the newest twelve-month WTI
return sign for one broker month. Engle and the pinned statsmodels method
support the auxiliary statistic; Moskowitz, Ooi, and Pedersen support monthly
WTI own-return continuation. This exact gate-and-trend conjunction is an
untested QuantMechanica synthesis. Statistic magnitude never scales risk.

## 2. Locked Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_returns` | 60 | completed adjacent monthly log returns |
| `strategy_arch_lags` | 6 | exact squared-residual lags |
| `strategy_regression_rows` | 54 | auxiliary OLS rows, `t=6..59` |
| `strategy_energy_floor` | `1e-18` | strict residual-energy floor |
| `strategy_sst_floor` | `1e-18` | strict centered-SST floor |
| `strategy_arch_lm_boundary` | `4.73` | inclusive pre-data gate |
| `strategy_momentum_months` | 12 | newest returns used for direction |
| `strategy_direction_epsilon` | `1e-12` | symmetric neutral band |
| `strategy_history_bars` | 1800 | bounded D1 endpoint reconstruction |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | inclusive entry-cost ceiling |

Q02 has one locked baseline and no optimization surface.

## 3. Symbol, Clock, And Exact Formula

- Exact host and traded symbol: `XTIUSD.DWX`, D1.
- Symbol slot zero; governed magic `413150000`.
- Decision clock: first executable tick after a genuine broker-month change,
  within 180 elapsed minutes of that D1 boundary.
- Current-month prices are excluded. Runtime uses no external data, curve,
  inventory series, file, API, portfolio state, trained artifact, or random
  output.

For chronological completed-month closes `C[0..60]`:

```text
r[i] = ln(C[i+1]/C[i]), i=0..59
mean = sum(r[i])/60
e[i] = r[i]-mean
energy = sum(e[i]^2)/60
v[i] = e[i]^2/energy

For t=6..59:
  y[t] = v[t]
  X[t] = [1,v[t-1],v[t-2],v[t-3],v[t-4],v[t-5],v[t-6]]

beta = ordinary least squares solution
ybar = sum(y)/54
SST = sum((y-ybar)^2)
SSE = sum((y-X*beta)^2)
R2 = 1-SSE/SST
ARCH_LM = 54*R2
mom12 = sum(r[i], i=48..59)

BUY  iff ARCH_LM >= 4.73 and mom12 > +1e-12
SELL iff ARCH_LM >= 4.73 and mom12 < -1e-12
FLAT otherwise
```

Require positive finite closes, finite intermediate arithmetic,
`energy>1e-18`, a full-rank seven-column partial-pivot solve, and
`SST>1e-18`. Only R2 roundoff inside `[-1e-10,1+1e-10]` may be clamped to
`[0,1]`. The common normalization changes conditioning, not exact R2. The
gate is directionless; only `mom12` assigns side. The 4.73 boundary is the
rounded median from the committed market-free null receipt, not a p-value or
critical value.

## 4. Entry, Risk, And Attempt Semantics

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. A qualified month may open one market position with a
frozen completed-bar `3.5*ATR(20,D1)` broker hard stop and no target. Foreign
WTI exposure or an owned position blocks entry. Framework quote, contract,
tick, volume, sizing, and margin guards remain authoritative.

Persist the normalized broker-month attempt before history, arithmetic,
news, spread, quote, ATR, sizing, margin, or order gates. Never retry a
consumed month. Persist entry-month state only after confirmed fill and
recover it from matching deal history after restart. Both news axes and
legacy news are OFF; Friday close and stress rejection are disabled. Entry
spread must be finite and in `[0,1500]` points.

## 5. Management And Exit

Close an owned position on the first processed tick in a later normalized
broker month or after forty elapsed calendar days. Missing or inconsistent
position, stop, side, entry time, or entry-month state causes a defensive
strategy close. There is no target, trail, break-even, partial close,
statistic exit, intramonth flip, Friday flatten, retry, scale-in, grid,
martingale, or pyramid. Framework kill switch and broker hard stop remain
authoritative.

## 6. Evidence, Activity, And Risk

The approved packet is
`strategy-seeds/sources/ENGLE-STATSMODELS-MOP-WTI-ARCHLM-20260902/source.md`.
The pinned statsmodels implementation fixes residual squaring, lag alignment,
intercept OLS, centered R-squared, and `LM=nobs*R2`; the peer-reviewed trading
paper supports monthly WTI continuation. None evaluates this conjunction,
boundary, CFD transport, costs, risk contract, activity, or portfolio fit.

The fixed-seed 200,000-path null receipt qualifies `50.0665%`, or `6.00798`
theoretical monthly clocks per twelve. It is a formula-density prior only.
Q02 owns actual activity and economics. Retire on zero positions, fewer than
five completed positions in any full post-warm-up scored year, nonpositive
governed economics, nondeterminism, or any formula, attempt, fixed-risk,
hard-stop, or lifecycle defect.

Principal risks are WTI gaps, continuous-CFD roll/basis and financing,
single-carrier concentration, broker-month labels, noisy overlapping monthly
windows, ill-conditioned normal equations, and the untested premise that
conditional-variance dependence selects trend persistence. Q09 alone may
establish or reject portfolio diversification. Live use is not authorized.

## Framework Alignment

- `Strategy_NoTradeFilter`: identity, registered magic, fixed risk,
  news/Friday/stress contract, and every strategy lock.
- bounded helpers: month clock, attempt state, endpoint reconstruction,
  return orientation, demeaning, square normalization, fixed 7x7 solve,
  centered R-squared, LM aggregation, direction, and restart recovery.
- `Strategy_EntrySignal`: foreign/owned exposure, spread, quote, ATR, frozen
  stop, and one fixed-risk market request.
- `Strategy_ManageOpenPosition`: malformed-state repair, side validation,
  next-month exit, and forty-day stale exit.
- `Strategy_ExitSignal`: no additional discretionary exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | approved source build | G0-approved card; magic `413150000`; Q01 pending |
