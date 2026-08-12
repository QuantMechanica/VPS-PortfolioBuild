# QM5_20290_wti-skew-prem — Strategy Spec

**EA ID:** QM5_20290  
**Slug:** `wti-skew-prem`  
**Source:** `FERNANDEZ-WTI-SKEW-2026`  
**Author of this spec:** Codex  
**Last revised:** 2026-08-12

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, reconstruct the
twelve complete WTI broker months immediately preceding the decision month.
Compute close-to-close log returns only when both adjacent timestamps lie
inside that half-open interval. Calculate the population mean, second central
moment, third central moment, and raw Pearson skewness. Buy below the fixed
zero pivot, sell above it, and consume near-zero or invalid state flat. Every
entry has a frozen `3.5 * ATR(20,D1)` hard stop, no take-profit, monthly
renewal, and a forty-day stale exit.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_months` | `12` | `[12]` | Exact complete broker-month formation |
| `strategy_history_bars_d1` | `500` | `[500]` | Bounded D1 reconstruction |
| `strategy_min_return_observations` | `180` | `[180]` | Minimum contained log returns |
| `strategy_max_return_observations` | `280` | `[280]` | Maximum contained log returns |
| `strategy_variance_floor` | `1e-12` | `[1e-12]` | Positive population-variance floor |
| `strategy_skew_tolerance` | `1e-12` | `[1e-12]` | Symmetric zero-pivot tolerance |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `1500` | `[1500]` | WTI entry spread ceiling |

All values are locked for baseline. No optimization or alternate estimator is
authorized.

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — registered Darwinex WTI route and only authorized carrier.

**Explicitly not for:**

- `XNGUSD.DWX` — already represented in the book and in a separate skewness-
  rank basket.
- `XAUUSD.DWX` and `XAGUSD.DWX` — governed by a separate two-leg skewness-rank
  EA.
- `XBRUSD.DWX` — distinct crude benchmark and not authorized by this card.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Signal window | Twelve complete broker months of boundary-contained D1 returns |
| Stop estimator | Completed `ATR(20,D1)` |
| Bar gating | One new-bar consume, then genuine broker-month transition check |

The current broker month and returns crossing the formation boundary do not
enter the signal.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11-12 after warm-up; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Expected drawdown profile | Sparse fixed-risk WTI third-moment losses with gap and regime-persistence exposure |
| Regime preference | Low-skew premium after negatively skewed formation; short high-skew states |

The WTI carrier and third-moment state are diversification hypotheses only.
Q09 owns any realized portfolio-overlap conclusion.

## 6. Source Citation

Fernandez-Perez, Adrian; Frijns, Bart; Fuertes, Ana-Maria; and Miffre,
Joelle (2018), "The Skewness of Commodity Futures Returns," *Journal of
Banking & Finance* 86, 143-158, DOI
`10.1016/j.jbankfin.2017.06.015`.

The source defines twelve-month Pearson skewness, documents a negative
cross-sectional skewness premium, and includes crude oil. The absolute time-
series zero pivot is a locked QM hypothesis; the paper does not test it. See
`strategy-seeds/sources/FERNANDEZ-WTI-SKEW-2026/source.md` and the canonical
card.

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
r[d] = ln(close[d] / close[d-1])
mu   = mean(r[d])
m2   = mean((r[d] - mu)^2)
m3   = mean((r[d] - mu)^3)
skew = m3 / (m2^(3/2))
```

Both timestamps for each return must lie in the twelve-month formation
interval. Require every expected month key, 180-280 returns, finite arithmetic,
and `m2 > 1e-12`. Buy below `-1e-12`, sell above `+1e-12`, and consume near-
zero or invalid state flat. Never scale risk from skewness magnitude.

## 9. Non-Duplicate Boundary

`QM5_13118` and `QM5_20233` are two-leg cross-sectional skewness-rank
baskets. This EA uses one outright WTI state, no second leg or rank, and an
absolute zero-pivot time-series premium map. `QM5_20289` uses one month of
normalized signed semivariance, not twelve-month centered third moments.
`QM5_12567` is a short-horizon long-only oscillator pullback. Ordinary WTI
trend, robust-location, return-reversal, calendar, event, breakout, and
variance-ratio systems use different information objects and clocks.

## 10. Kill Criteria

Retire below five completed positions per full post-warm-up year, on
nonpositive governed economics, or on later portfolio-correlation rejection.
Fail on the wrong formation, boundary-crossing/current-month returns, missing
month coverage, count outside 180-280, nonpositive variance, alternate moment
estimator, wrong pivot or direction, repeat attempt, missing stop, hold beyond
forty days, risk mismatch, or nondeterminism. No rescue parameter is
authorized.

## 11. Safety Boundary

Research, deterministic allocation, build, strict compile/Q01, one fixed-risk
backtest set, and one paced non-live Q02 enqueue only. No manual backtest,
live/demo/shadow/stress/optimization set, `T_Live` access, AutoTrading change,
deploy manifest, portfolio-gate edit, portfolio admission, or correlation
waiver is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-12 | Initial scaffold from approved card | Build pending |
| v2 | 2026-08-12 | Initial V5 implementation and Q01 validation | Strict compile, target build check, P1 artifact validation, and independent skewness vectors PASS |
| v3 | 2026-08-12 | Paced Q02 handoff | One WTI priority-track row enqueued below the path-anchored factory CPU ceiling |

## 12. Q01 Status

PASS. Strict compile completed with zero errors and zero warnings; the target
build check completed with zero failures and zero warnings; P1 artifact
validation found the EA directory and current `.ex5`; and independent vectors
proved the premium direction, near-zero handling, positive scale invariance,
twelve-month coverage, boundary-return exclusion, 180-280 observation bounds,
zero-variance rejection, and the genuine broker-month transition gate.
Evidence:

- `D:/QM/reports/compile/20260812_085247/summary.csv`
- `D:/QM/reports/framework/21/build_check_20260812_085247.json`
- `D:/QM/reports/pipeline/QM5_20290/P1/P1_QM5_20290_result.json`
- `framework/EAs/QM5_20290_wti-skew-prem/docs/test_skew_reference.py`

## 13. Q02 Handoff

ENQUEUED. The canonical never-tested sweep created exactly one priority-track
row for `QM5_20290 / XTIUSD.DWX` while Q01 was finishing: work item
`661b4c77-8fed-41ff-92e2-d4851ebcaad0`. Immediate readback found attempt 0
pending and unclaimed with no verdict. The subsequent target-only dry run
selected no additional row because this exact EA already had work-item state.
The binding path-anchored capacity sample found four exact T1-T10 tester
processes against the ceiling of seven. No duplicate apply, dispatch tick,
terminal launch, or manual backtest was issued by this mission. This is a
handoff, not a Q02 result.
