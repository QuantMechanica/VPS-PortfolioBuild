# QM5_20249 XAU/XAG Variance-Ratio Spread G0 Authorization

Date: 2026-08-06

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 Strategy Card and non-live build for
`QM5_20249_xauxag-vr-spread`. On the first tradable XAU D1 bar of each genuine
broker month, reconstruct 33 synchronized completed month-end closes for gold
and silver, form 32 gold-minus-silver monthly log returns, and estimate the
published `q=2` heteroskedasticity-robust variance-ratio state. Significant
persistence follows the latest relative return; significant anti-persistence
reverses it; insignificant memory consumes the month flat. An actionable
state opens one opposite-direction XAU/XAG package and closes it at the next
month boundary.

The candidate may proceed through deterministic card lint, directory-first EA
and magic allocation, strict compile, one logical-basket `RISK_FIXED`
backtest setfile, strict Q01, and one paced Q02 enqueue. G0 does not pre-approve
efficacy, neutrality, diversification, decorrelation, certification,
execution-contract promotion, or portfolio admission.

## Source Boundary

The approved source of record is
`strategy-seeds/sources/CME-MEHLITZ-XAUXAG-VRSPREAD-2026/source.md`. Its
complete-read parents are Mehlitz and Auer (2024), *The European Journal of
Finance* 30(8), 773-802, DOI `10.1080/1351847X.2023.2220118`, and CME Group's
"Gold & Silver Ratio Spread" lesson.

Mehlitz and Auer supply the 32-month `R1-q2` robust variance-ratio statistic,
fixed two-sided 10% critical value, latest-return direction, and continuation /
reversal matrix; their source universe explicitly includes gold and silver.
CME supplies the related two-leg relative-value carrier and distinct metal
drivers. Neither source tests the relative-return intersection. The
continuous-CFD carrier, synchronized broker-month proxy, equal fixed-stop-risk
halves, ATR stops, spread caps, legging repair, and lifecycle controls are
transparent QM adaptations. No source efficacy or portfolio statistic
transfers.

## Non-Duplicate Decision

The deterministic checker scanned 4,306 pre-allocation registry rows and 423
canonical cards and returned `CLEAN`, without a fuzzy hit, for the slug,
strategy identity, authors, and complete mechanic. Manual review separates
the candidate from:

- `QM5_12577`, which fades a rolling fixed-beta log-ratio z-score;
- `QM5_12724` and `QM5_12862`, which trade ratio-channel continuation and D1
  return-spread z-score reversion;
- `QM5_20161` and `QM5_13205`, which trade OLS and quantile disequilibrium;
- `QM5_20194`, which requires 12/18-month relative-rank disagreement;
- `QM5_20233`-`QM5_20236`, which rank third moment, signed jumps, expected
  shortfall, and volatility-of-volatility; and
- `QM5_13134`, which applies the source memory rule to outright WTI rather
  than a synchronized two-leg precious-metals relative series.

The synchronized relative-return series, 32-return robust `q=2` test, fixed
significance boundary, latest relative direction, persistence-follow /
anti-persistence-reverse matrix, opposite two-leg package, and monthly attempt
clock are jointly load-bearing. Verdict:
`CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

## Allocation And Kill Boundary

- EA ID: `QM5_20249`
- slug: `xauxag-vr-spread`
- strategy ID: `CME-MEHLITZ-XAUXAG-VRSPREAD-2026_S01`
- slot 0: `XAUUSD.DWX` / magic `202490000`
- slot 1: `XAGUSD.DWX` / magic `202490001`
- logical symbol: `QM5_20249_XAU_XAG_VRSPREAD_D1`
- cadence: estimated 6-10 completed packages/year after warm-up; Q02 must
  establish the actual count
- retire below five completed packages per full post-warm-up year
- retire on unsynchronized or nonconsecutive endpoints, wrong relative-return
  series, wrong robust statistic, wrong direction matrix, same-direction or
  orphan legs, repeated monthly attempt, aggregate-risk breach, nonpositive
  governed economics, or later portfolio-correlation rejection
- no post-result horizon, `q`, critical value, direction, retry, stop, carrier,
  or hedge rescue is authorized

## Safety Boundary

This authorization excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; correlation waivers; and downstream
promotion. Q02 uses one aggregate package budget with exactly
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
