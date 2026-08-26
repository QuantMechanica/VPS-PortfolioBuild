# QM5_41173_wti-mspearman-tr - Strategy Spec

**EA ID:** QM5_41173

**Slug:** `wti-mspearman-tr`

**Strategy ID:** `MOP-SPEARMAN-WTI-MRANK-TREND-2026_S01`

**Source:** `MOP-SPEARMAN-WTI-MRANK-TREND-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-26

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker month,
reconstruct the latest close in each of the immediately prior thirteen
consecutive completed broker months. Require positive, finite,
pairwise-distinct closes and assign their strict ordinal price ranks 1 through
13, oldest observation first.

Measure squared displacement between each price rank and its fixed calendar
rank, then continue only a sufficiently ordered path. With `D` equal to the
sum of squared rank displacements, the exact integer score is `T=364-D` and
Spearman `rho=T/364`. Buy WTI when `T>=104`, sell when `T<=-104`, and consume
the month flat otherwise.

A valid direction owns one fixed-risk WTI position until the first later
normalized broker month, protected by a frozen ATR hard stop. Statistic
magnitude never changes risk.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_endpoint_count` | 13 | consecutive completed month-end closes |
| `strategy_min_abs_score` | 104 | exact absolute integer score gate |
| `strategy_history_bars_d1` | 900 | bounded endpoint reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | raw current-bar execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All inputs are locked for one Q02 baseline. There is no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411730000`.
- No signal, hedge, conversion, ratio, external, or companion symbol exists.

## 4. Timeframe And Formula

```text
R[i] = strict price rank of C[i], 1 = smallest, 13 = largest
require sorted(R) = 1..13

D = sum((R[i] - (i + 1))^2), i = 0..12
T = 364 - D
rho = T / 364

BUY  iff T >= 104
SELL iff T <= -104
FLAT otherwise
```

Require `0<=D<=728`, `-364<=T<=364`, and even `D` and `T`. For no-tie
permutations this is the exact Spearman rank correlation identity. The gate is
equivalent to `abs(rho)>=2/7`; runtime uses integer arithmetic only. The
formation and decision cadence are monthly. The current month contributes no
signal close. Equal closes, average ranks, p-value gates, endpoint-direction
fallbacks, and floating thresholds are forbidden.

## 5. Expected Behaviour

- Pre-result density prior: four to eight completed WTI positions per full
  post-warm-up year; Q02 retires below four in any full year.
- Symmetric direct-WTI structural continuation; one consumed attempt per
  broker month and at most one owned position.
- Exact subset enumeration of all 13! rank orders gives 2,139,842,508
  qualifying paths, split equally by side, for a random-order qualification
  rate of 0.3436382463986631. This locks density, not expected performance.
- The global time-rank displacement is mechanically distinct from pair-sign,
  lag-pair, record, adjacent-distance, turning-point, and change-point WTI
  neighbors. Only downstream portfolio evidence may establish decorrelation.

## 6. Source Citation

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Spearman (1904), "The Proof and Measurement of Association between Two
Things," *The American Journal of Psychology* 15(1), DOI
`10.2307/1412159`.

R Core Team, `stats::cor` source and manual, public `wch/r-source` mirror
commit `7344a2d9d96b3c2b997535d3abc8c3a44af16e82`.

Canonical bounded packet:
`strategy-seeds/sources/MOP-SPEARMAN-WTI-MRANK-TREND-2026/source.md`.
The sources supply WTI monthly-continuation and rank-correlation lineage. They
do not test this thirteen-endpoint threshold or continuous-CFD trading
conjunction.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses a frozen completed-bar
`3.5*ATR(20,D1)` stop through the V5 risk helper. Both news axes, legacy news,
and Friday close are OFF. Maximum entry spread is 1,500 points.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deployment, portfolio admission, portfolio-gate
change, tie averaging, fitted threshold, retry, scale-in, grid, martingale,
target, trail, break-even move, or partial exit.

## 8. Deterministic Failure Contract

The month is durably consumed before history, arithmetic, news, spread, quote,
ATR, sizing, margin, or order checks. Missing or duplicate month keys, mixed
label conventions, stale endpoints, nonpositive/nonfinite/equal closes, wrong
endpoint count, invalid rank permutation, odd or out-of-range D/T, or a weak
score fails flat. An order reject never retries the month. Lifecycle repair
runs every tick before entry-only gates and closes duplicate, malformed,
wrong-side, later-month, or stale exposure.

## Framework Alignment

- no_trade: exact symbol/period/ID/slot and locked risk/news/Friday/strategy
  inputs.
- trade_entry: normalized month clock, consumed attempt, exact consecutive
  endpoints, strict ranks, exact D/T arithmetic, signed threshold,
  spread/quote/ATR/stop checks, and one fixed-risk request.
- trade_management: malformed or wrong-side repair, entry-month direction
  reconstruction, later-month exit, and stale repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-26 | approved source build | G0-approved card and governed magic `411730000` |
