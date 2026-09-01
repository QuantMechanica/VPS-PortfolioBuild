# QM5_41270 WTI Lepage Location-Scale Shift Trend

**EA ID:** QM5_41270

## 1. Strategy Logic

Once per new broker month, compare fixed old and recent blocks of 25 completed
WTI D1 log returns with the classical Lepage joint rank statistic. The two
components measure a pooled-rank location shift (Wilcoxon) and a symmetric-rank
scale shift (Ansari-Bradley). When their squared standardized sum reaches the
fixed chi-square-two median gate, follow the sign of the recent block return
for at most one broker month.

| field | value |
|---|---|
| EA ID | `41270` |
| slug | `wti-mlepage-shift-tr` |
| Strategy ID | `AI-CODEX-WTI-MLEPAGE-SHIFT-20260901_S01` |
| host / traded symbol | `XTIUSD.DWX` |
| timeframe | `PERIOD_D1` |
| symbol slot | `0` |
| governed magic | `412700000` |
| card | `strategy-seeds/cards/approved/QM5_41270_wti-mlepage-shift-tr_card.md` |
| source | `strategy-seeds/sources/AI-CODEX-WTI-MLEPAGE-SHIFT-20260901/source.md` |
| G0 | `decisions/2026-09-01_qm5_41270_wti_monthly_lepage_shift_trend_g0.md` |

This is a direct-WTI structural sleeve. It is not a portfolio-admission,
correlation, live-preset, or deployment authorization.

## 2. Symbol, Timeframe, And Data Boundary

The universe is only native `XTIUSD.DWX`, slot 0, on D1. No proxy, futures
chain, alternate CFD, basket, or current-bar price is used in the statistic.

The decision clock fires only on a genuine new D1 bar whose normalized label
and broker time identify the first executable bar of a new broker month.
Normalization permits the registered zero- or one-day D1 label offset already
used by the governed WTI cohort. A month is late and consumes flat if a
completed D1 bar already exists in that normalized month or if more than 180
minutes have elapsed since the decision bar opened.

Before history, arithmetic, news, spread, quote, ATR, sizing, margin, or order
checks, the normalized month key is persisted to a terminal global. Owned
positions and same-magic entry deals are secondary restart guards. A failed
gate never retries in the same month.

The bounded request is exactly 80 completed D1 bars. Current-month completed
bars are excluded during restart validation, leaving exactly 51 positive,
finite, strictly chronological pre-month closes. At entry, the newest completed
label may be at most four calendar days old and must belong to the immediately
preceding broker month.

## 3. Exact Signal Formula

For chronological closes `C[0..50]`, form:

```text
r[i] = log(C[i+1] / C[i]), i=0..49
old = r[0..24]
recent = r[25..49]
```

All fifty returns must be finite and pairwise distinct. Pool them and assign
ordinary ascending ranks `j=1..50`. For each recent-block observation, let its
ordinary rank be `j` and its symmetric score be `min(j, 51-j)`. Compute:

```text
W = sum(recent ordinary ranks)
A = sum(recent symmetric scores)

zW2 = (W - 637.5)^2 / 2656.25
zA2 = (A - 325)^2 / (32500/49)
L = zW2 + zA2
```

The state qualifies iff `L >= 1.3862943611198906`, the locked median of the
asymptotic chi-square distribution with two degrees of freedom. The EA performs
no CDF lookup and makes no significance claim. Exact ties fail closed; no
midrank or tie correction is authorized.

For a qualifying state:

- buy when `sum(recent) > 1e-12`;
- sell when `sum(recent) < -1e-12`; and
- consume flat otherwise.

Statistic magnitude never changes size, stop distance, or holding period.

## 4. Entry And Risk Contract

Entry requires the exact symbol, D1 period, EA ID, slot, magic, seed, locked
inputs, a timely unconsumed month, no owned exposure, no same-magic entry deal,
a valid qualifying non-neutral signal, spread at most 1,500 points, a finite
quote, completed-bar `ATR(20,D1)`, and a valid normalized broker hard stop
exactly `3.5*ATR` from entry.

All governed backtests use exactly:

```text
RISK_FIXED=1000
RISK_PERCENT=0
PORTFOLIO_WEIGHT=1
```

The order is one market order, deviation 20 points, one frozen hard stop, no
take profit, and no expiration. News temporal mode is OFF, compliance is NONE,
legacy news is OFF, Friday close is disabled, and stress rejection is zero.
This directory intentionally contains no live setfile.

## 5. Position Management And Exit Precedence

Every tick handles exits before entry-only gates:

1. Framework kill switch and broker hard stop.
2. Repair duplicate, wrong-symbol, wrong-magic, wrong-side, stopless,
   target-bearing, or otherwise malformed owned exposure.
3. Close on the first processed tick in a later normalized broker month.
4. Close after 40 elapsed calendar days as stale repair.
5. Only then consider a new-month entry.

Restart validation reconstructs the frozen pre-month sample and expected side.
There is no intramonth flip, target, trail, break-even, partial close, Friday
close, news exit, scale-in, grid, martingale, or pyramid.

## 6. Locked Inputs

| input | value |
|---|---:|
| `strategy_close_count` | 51 |
| `strategy_return_count` | 50 |
| `strategy_block_size` | 25 |
| `strategy_w_mean` | 637.5 |
| `strategy_w_variance` | 2656.25 |
| `strategy_a_mean` | 325.0 |
| `strategy_a_variance` | 663.26530612244898 |
| `strategy_statistic_gate` | 1.3862943611198906 |
| `strategy_direction_epsilon` | 1e-12 |
| `strategy_history_bars_d1` | 80 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_max_completed_bar_age_days` | 4 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 40 |
| `strategy_max_spread_points` | 1500 |
| `strategy_deviation_points` | 20 |

The sole setfile is
`sets/QM5_41270_wti-mlepage-shift-tr_XTIUSD.DWX_D1_backtest.set` and is locked
to `risk_mode: FIXED`.

## 7. Expected Activity And Q02 Rule

The chi-square-two median gate supplies an asymptotic one-half qualifying-state
prior, or roughly six states per year before serial dependence, neutral
direction, data, tie, cost, and execution gates. This is a design prior, not a
measured WTI frequency or performance claim. Q02 must retire the candidate if
any full post-warm-up calendar year has fewer than five completed positions.

## 8. Source And Non-Duplicate Boundary

Moskowitz, Ooi, and Pedersen (2012) support broad own-return continuation and
explicit WTI membership. Lepage (1971), the fully read Hussain-Tsagris author
preprint, and the official CRAN `LePage` implementation support the classical
joint rank arithmetic and asymptotic chi-square-two reference. They do not test
this EA conjunction. The daily blocks, median gate, recent-return side, CFD
mapping, risk, stop, monthly attempt, and lifecycle are disclosed QM choices.

The preallocation receipt is
`artifacts/qm5_wti_mlepage_shift_tr_preallocation_dedup_20260901.json`. Its one
fuzzy neighbor, QM5_41268, uses Fourier empirical-characteristic features and a
pooled covariance inverse. This EA uses only ordinary pooled ranks and two
closed-form distribution-free components. It also differs from the existing
location-only and scale-only monthly WTI cards by requiring their joint Lepage
state. No source return, frequency, cost, significance, or decorrelation result
is transferred.

## 9. Runtime Evidence

Each monthly decision emits the normalized month, decision clock, consumption
state, data counts, strict-distinctness flag, `W`, `A`, `zW2`, `zA2`, `L`, gate
result, recent cumulative return, direction, sample endpoints, timestamps, and
terminal state. Framework telemetry retains entry, exit, risk, stop, and
execution evidence.

This build is authorized only for governed backtesting. It does not authorize
T_Live, AutoTrading, a portfolio gate change, or any live manifest mutation.
