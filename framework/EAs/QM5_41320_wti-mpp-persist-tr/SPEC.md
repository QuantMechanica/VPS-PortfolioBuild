# QM5_41320 — WTI Monthly Phillips-Perron Persistence Trend

**EA ID:** QM5_41320

**Slug:** `wti-mpp-persist-tr`

**Source:** `AI-CODEX-WTI-MPP-PERSIST-TREND-20260903`

**Author of this spec:** Codex

**Last revised:** 2026-09-03

---

## 1. Strategy Logic

This EA is a direct, low-frequency `XTIUSD.DWX` commodity sleeve. On the
first executable D1 tick of each new broker month, it reconstructs exactly
sixty consecutive completed month-end closes. It fits an intercept-only level
AR(1) to their natural logs, applies an eleven-lag Bartlett residual correction
to the rho t statistic, and follows the newest twelve-month log-return sign
only when the corrected Phillips-Perron Z-tau value is at least `-2.594`.

The EA consumes its one monthly attempt before any fallible gate. A qualified
signal opens at most one position with a frozen `3.5*ATR(20,D1)` hard stop and
no target. It closes in a later broker month or after forty elapsed days. The
state line is a frozen classifier, not a finite-sample p-value, unit-root
finding, stationarity claim, or portfolio-correlation result.

---

## 2. Parameters

Every strategy parameter is locked for the single Q02 falsification baseline.

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_level_count` | 60 | locked | Completed chronological month-end closes/log levels |
| `strategy_regression_observations` | 59 | locked | Adjacent level AR(1) rows |
| `strategy_residual_dof` | 57 | locked | Observations less intercept and slope |
| `strategy_bartlett_lags` | 11 | locked | Fixed HAC residual lags |
| `strategy_energy_floor` | `1e-18` | locked | Reject degenerate variance paths |
| `strategy_pp_z_tau_min` | `-2.594` | locked, inclusive | Persistence-state line |
| `strategy_momentum_months` | 12 | locked | Continuation direction horizon |
| `strategy_direction_epsilon` | `1e-12` | locked | Symmetric neutral band |
| `strategy_history_bars` | 1200 | locked | Bounded D1 endpoint scan |
| `strategy_entry_grace_minutes` | 180 | locked | First-month-bar entry window |
| `strategy_endpoint_stale_days` | 10 | locked | Newest endpoint age ceiling |
| `strategy_atr_period` | 20 | locked | Completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | locked | Frozen hard-stop distance |
| `strategy_stale_days` | 40 | locked | Survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | locked, inclusive | Entry-cost ceiling |

Framework inputs remain sealed in the sole backtest set:
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`; both news
axes, legacy news, Friday close, and stress rejection are off.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — the approved continuous WTI CFD carrier and the only active
  slot-zero magic row for this single-symbol hypothesis.

**Explicitly NOT for:**

- `XNGUSD.DWX` — natural gas has different storage and seasonal structure.
- `XAUUSD.DWX` and `XAGUSD.DWX` — metals are outside the direct-WTI claim.
- Equity-index and FX symbols — neither source nor card transfers this
  oil-specific implementation to those markets.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Signal sampling | Sixty completed broker-month endpoints reconstructed from bounded D1 history |
| Multi-timeframe refs | None |
| Bar gating | Sole `QM_IsNewBar()` call; month identity is derived only inside that branch |
| Entry timing | First executable current-month D1 bar, within 180 minutes |

The host chart, traded carrier, and history carrier are all exactly
`XTIUSD.DWX`, D1, slot zero, magic `413200000`.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Planning prior 7–11; Q02 requires at least 5 in every full scored year |
| Typical hold time | Until the next broker month, capped by a 40-day stale repair |
| Expected drawdown profile | High-risk single-commodity sleeve; conservative research prior 30%, not a gate |
| Regime preference | Persistent directional WTI months; flat when PP Z-tau is below the state line |
| Win rate target | Unknown; no minimum is claimed before Q02 |
| Position count | At most one owned position and one consumed attempt per broker month |

### Exact signal arithmetic

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

### Clock, attempt, and lifecycle

The normalized broker-month attempt is persisted before history, arithmetic,
news, spread, quote, ATR, sizing, margin, or order gates. A consumed month is
never retried. Late decisions, an existing entry deal, owned exposure, or
foreign `XTIUSD.DWX` exposure block entry. Zero modeled DWX spread is valid;
only a negative, non-finite, or above-1500-point spread fails.

A qualified decision uses the V5 fixed-dollar risk path, a completed-bar hard
stop, and no target. Duplicate, wrong-symbol, invalid-type, wrong-side,
missing-stop, malformed entry-time, or inconsistent entry-month state triggers
a defensive close. Restart recovery may use only matching owned deal history.
There is no statistic exit, intramonth flip, Friday flatten, trail,
break-even move, partial close, resize, scale-in, grid, martingale, pyramid,
or retry.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `AI-CODEX-WTI-MPP-PERSIST-TREND-20260903`

**Source type:** Governed AI synthesis supported by two peer-reviewed papers

**Pointer:** `strategy-seeds/sources/AI-CODEX-WTI-MPP-PERSIST-TREND-20260903/source.md`

**R1–R4 verdict (Q00):** R1 passes with complete peer-reviewed evidence and
explicit synthesis boundaries; R2–R4 PASS per
`strategy-seeds/cards/approved/QM5_41320_wti-mpp-persist-tr_card.md` and the
runtime approved-card record.

Phillips and Perron (1988), *Biometrika* 75(2), DOI
`10.1093/biomet/75.2.335`, supply the corrected statistic and warn about
finite-sample size distortion under negative moving-average errors.
Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2),
DOI `10.1016/j.jfineco.2011.11.003`, supply monthly own-return continuation
and explicit WTI membership. Neither source validates this conjunction,
continuous-CFD sample, fixed lag count, threshold transport, activity,
economics, or correlation.

Initialization runs qualifying-up, qualifying-down, mean-reverting-rejection,
and degenerate deterministic fixtures. The independent Python suite checks the
AR(1), residual HAC, PP correction, pinned oracle values, additive-level
invariance, boundary, endpoints, attempt order, preset, card, registry, and
source guards.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`. The only artifact
created here is a backtest preset with `RISK_PERCENT=0`; this spec does not
authorize Q13, live use, portfolio admission, correlation waiver, terminal
control, `T_Live`, or AutoTrading.

Gaps can exceed modeled stop risk. Principal candidate risks are
continuous-CFD roll/basis/financing, single-carrier concentration,
broker-month labeling, PP finite-sample distortion, overlapping windows, and
persistence unrelated to tradable continuation. Q02 retires the unchanged
identity on zero positions, fewer than five completed positions in a full
post-warm-up year, nonpositive governed economics, nondeterminism, or any
formula, fixed-risk, stop, attempt, or lifecycle defect.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-03 | Initial build from approved card | Build task `85b3f3e7-1d5e-49ba-8aa6-eefc1abac96e`; source commit `19e0d1bbe5` |
