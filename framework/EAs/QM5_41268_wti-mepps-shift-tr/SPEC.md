# QM5_41268 WTI Epps-Singleton Distribution-Shift Trend

**EA ID:** QM5_41268

## 1. Strategy Logic

Once per new broker month, compare fixed old and recent blocks of 25 completed
WTI D1 log returns with the Epps-Singleton empirical-characteristic-function
quadratic form. When the full-rank statistic reaches its fixed chi-square-four
median gate, follow the sign of the recent block return for at most one month.

Identity:

| field | value |
|---|---|
| EA ID | `41268` |
| slug | `wti-mepps-shift-tr` |
| Strategy ID | `AI-CODEX-WTI-MEPPS-SHIFT-20260901_S01` |
| host / traded symbol | `XTIUSD.DWX` |
| timeframe | `PERIOD_D1` |
| symbol slot | `0` |
| governed magic | `412680000` |
| card | `strategy-seeds/cards/approved/QM5_41268_wti-mepps-shift-tr_card.md` |
| source | `strategy-seeds/sources/AI-CODEX-WTI-MEPPS-SHIFT-20260901/source.md` |
| G0 | `decisions/2026-09-01_qm5_41268_wti_monthly_epps_singleton_shift_trend_g0.md` |

This is one direct-WTI structural sleeve. It is not a portfolio admission,
correlation finding, live preset, or deployment authorization.

## 2. Parameters

The sample, Fourier points, covariance, inverse guards, activity gate,
direction tolerance, fixed risk, ATR stop, spread ceiling, and time exit are
all immutable. The complete literal input table appears under Detailed Locked
Inputs below and is reproduced in the sole backtest setfile.

## 3. Symbol Universe

The universe contains only native `XTIUSD.DWX`, symbol slot 0. No proxy,
basket, external futures chain, or alternate CFD symbol is authorized.

## 4. Timeframe

The host and execution timeframe is exactly `PERIOD_D1`. Signal history uses
completed D1 closes only; evaluation cadence is one consumed broker-month
attempt, and the current D1 bar never enters the statistic.

## 5. Expected Behaviour

The locked chi-square-four median supplies an asymptotic one-half state prior,
roughly six monthly qualifying states per year before dependence, neutral
direction, data, rank, cost, and execution gates. This is an activity prior,
not measured WTI frequency or performance. Q02 must retire the candidate below
five completed positions in any full post-warm-up year.

## 6. Source Citation

Moskowitz, Ooi, and Pedersen (2012) provide peer-reviewed evidence for broad
own-return continuation and explicitly include NYMEX WTI in their futures
universe. Epps and Singleton (1986) provide the named empirical-
characteristic-function two-sample method. The signed-tag-pinned SciPy 1.18.0
documentation and implementation provide the exact semi-IQR, feature,
covariance, quadratic-form, rank, and chi-square reference arithmetic used by
this build.

No source tests this EA's conjunction. The fixed daily blocks, chi-square-four
median gate, recent-return side, CFD mapping, fixed risk, ATR stop, monthly
attempt, and lifecycle are disclosed pre-result QM choices. No source return,
trade frequency, cost, significance, or decorrelation statistic transfers.

Preallocation dedup evidence:
`artifacts/qm5_wti_mepps_shift_tr_preallocation_dedup_20260901.json`.

## 7. Risk Model

All governed backtests use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Every order carries one frozen completed-bar
`3.5*ATR(20,D1)` broker hard stop and no target. Sizing is independent of the
statistic magnitude. This build creates no live preset or deployment state.

## Detailed Decision Clock And Data Boundary

The EA evaluates only on a genuine new D1 bar whose normalized label and
broker time identify the first executable bar of a new broker month.
Normalization permits the registered zero- or one-day D1 label offset used by
the neighboring governed WTI implementations.

The month is late and consumes flat when either:

- a completed D1 bar already exists in the current normalized month; or
- more than 180 minutes have elapsed since the current D1 bar opened.

Before every fallible history, arithmetic, news, spread, quote, ATR, sizing,
margin, or order gate, the normalized month key is written to a terminal
global. Owned positions plus same-magic entry deals provide the secondary
restart guard. A rejected gate never retries in that month.

The bounded history request is exactly 80 completed D1 bars. Current-month
completed bars are excluded during restart validation so the pre-month sample
remains frozen. The selected sample is exactly 51 positive, finite, strictly
chronological closes. At entry, its newest completed label may be at most four
calendar days old and must belong to the immediately preceding broker month.

## Detailed Signal Formula

For chronological closes `C[0..50]`, form:

```text
r[i] = log(C[i+1] / C[i]), i=0..49
old = r[0..24]
recent = r[25..49]
```

Sort a copy of all fifty returns. The locked default-linear percentiles are:

```text
q25 = sorted[12] + 0.25 * (sorted[13] - sorted[12])
q75 = sorted[36] + 0.75 * (sorted[37] - sorted[36])
sigma = (q75 - q25) / 2
t1 = 0.4 / sigma
t2 = 0.8 / sigma
```

Require finite positive `sigma`, `t1`, and `t2`. For every return `x`, use
the exact feature order:

```text
g(x) = [cos(t1*x), cos(t2*x), sin(t1*x), sin(t2*x)]
```

For each fixed block, compute its feature mean and biased covariance:

```text
cov_block = (1/25) * sum((g - mean_g) * (g - mean_g)')
est_cov = 2 * cov_old + 2 * cov_recent
delta = mean_old - mean_recent
W = 50 * delta' * inverse(est_cov) * delta
```

The direct 4x4 inverse uses deterministic scaled partial-pivot Gauss-Jordan
elimination. Every pivot must exceed
`1e-12*max(1,max_abs_matrix_element)`. Every entry must remain finite and the
maximum absolute residual of `est_cov*inverse-I` must not exceed `1e-8`.
Rank-deficient or ill-conditioned packages fail closed. A finite `W` in
`[-1e-10,0)` clamps to zero; a lower value fails closed.

The state qualifies iff `W >= 3.356693980033321`, the locked median of a
chi-square distribution with four degrees of freedom. The EA performs no CDF
lookup and makes no significance claim.

For a qualifying state:

- buy when `sum(recent) > 1e-12`;
- sell when `sum(recent) < -1e-12`; and
- consume flat otherwise.

Statistic magnitude never changes size, stop, or holding period.

## Detailed Entry Contract

Entry requires all of the following:

1. Exact symbol, D1 period, EA ID, slot, magic, seed, and locked inputs.
2. `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
3. News temporal mode OFF, compliance profile NONE, legacy news OFF, Friday
   close OFF, and stress rejection probability zero.
4. A timely, not previously consumed broker-month decision.
5. No owned exposure and no same-magic entry deal in that month.
6. A valid full-rank qualifying signal with a non-neutral direction.
7. Spread no greater than 1,500 points and a finite executable quote.
8. Completed-bar `ATR(20,D1)` and a valid broker-normalized hard stop exactly
   `3.5*ATR` from entry.
9. Framework fixed-risk sizing, metadata, and margin checks.

The request is one market order, deviation 20 points, one hard stop, no take
profit, and no expiration.

## Detailed Position Management And Exit Precedence

Every tick processes exits before entry-only gates:

1. Framework kill switch and broker hard stop.
2. Immediate repair of duplicate, wrong-symbol, wrong-magic, wrong-side,
   stopless, target-bearing, or otherwise malformed owned exposure.
3. Close on the first processed tick in a later normalized broker month.
4. Close after 40 elapsed calendar days as stale repair.
5. Only then process a new-month entry attempt.

Restart direction validation reconstructs the frozen pre-month sample while
excluding any completed current-month bars. It does not reapply the entry-only
four-day staleness gate to a valid position later in its holding month.

No intramonth flip, target, trail, break-even, partial close, Friday close,
news exit, scale-in, grid, martingale, or pyramid is authorized.

## Detailed Locked Inputs

| input | value |
|---|---:|
| `strategy_close_count` | 51 |
| `strategy_return_count` | 50 |
| `strategy_block_size` | 25 |
| `strategy_t1` | 0.4 |
| `strategy_t2` | 0.8 |
| `strategy_statistic_gate` | 3.356693980033321 |
| `strategy_inverse_pivot_epsilon` | 1e-12 |
| `strategy_inverse_residual_tolerance` | 1e-8 |
| `strategy_negative_stat_tolerance` | 1e-10 |
| `strategy_direction_epsilon` | 1e-12 |
| `strategy_history_bars_d1` | 80 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_max_completed_bar_age_days` | 4 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 40 |
| `strategy_max_spread_points` | 1500 |
| `strategy_deviation_points` | 20 |

The only setfile is
`sets/QM5_41268_wti-mepps-shift-tr_XTIUSD.DWX_D1_backtest.set`. It is a D1
backtest preset using fixed risk. No live, demo, shadow, or stress preset is
part of this build.

## Detailed Deterministic Validation

`docs/test_wti_mepps_shift_tr_reference.py` uses only the Python standard
library and locks:

- the chi-square-four median equation;
- the exact percentile indices and interpolation;
- cosine/cosine/sine/sine feature order;
- biased block covariance and equal-block multipliers;
- scaled partial-pivot inverse and singular rejection;
- inverse identity residual and negative-statistic guards;
- fixed long, short, and below-gate fixtures;
- chronological close/return orientation;
- consume-before-history source ordering;
- banned runtime surface absence;
- fixed-risk setfile locks; and
- source pin and card-copy preservation.

The reference fixture is not a backtest and supplies no performance evidence.

## Detailed Non-Duplicate Boundary

Unlike `QM5_41255`, this EA does not integrate squared empirical-CDF
differences. Unlike `QM5_41258`, it uses no pairwise energy distance. Unlike
`QM5_41259`, it uses no sorted-quantile Wasserstein distance. Unlike
`QM5_41262`, it does not use raw close mean-location. Unlike `QM5_41267`, it
does not use pooled squared ranks or a relative-scale classification.

This EA alone maps two fixed 25-return WTI blocks into four empirical-
characteristic-function means, normalizes their difference by a guarded
feature covariance, applies a fixed chi-square-four median gate, and follows
the recent cumulative return.

## Detailed Risk, Frequency, And Kill Criteria

The chi-square-four median has a one-half asymptotic state prior, suggesting
roughly six qualifying monthly states per year before serial dependence,
neutral direction, rank, data, spread, ATR, sizing, and execution gates. This
is not a WTI trade-frequency or performance measurement.

Q02 must retire the candidate on zero positions or fewer than five completed
positions in any full post-warm-up year. It must also retire on failed
deterministic parity, nonpositive governed economics, or any later gate
failure. Q09 alone may establish realized correlation behavior.

WTI gaps, continuous-CFD roll and basis, financing, stale/missing history,
small-sample instability, covariance conditioning, spread, and execution
remain material risks.

## Framework Alignment

- `no_trade`: exact identity, symbol, timeframe, magic, risk, news, Friday,
  stress, and locked-input validation.
- `trade_entry`: consumed monthly state, fixed-window Epps-Singleton signal,
  side, spread, quote, completed ATR, frozen stop, and one fixed-risk order.
- `trade_management`: integrity and side repair, new-month close, and 40-day
  stale close.
- `trade_close`: V5 close helper, framework kill switch, and broker hard stop.

## Revision History

| version | date | reason | notes |
|---|---|---|---|
| v0 | 2026-09-01 | approved source build | G0 card; governed magic `412680000` |
