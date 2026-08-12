# QM5_20234_xauxag-rsj - Strategy Spec

- **EA ID:** QM5_20234
- **Strategy ID:** `KISS-RSJ-2025_XAU_XAG_S02`
- **Source:** Kiss and Ferreira Batista Martins (2025), DOI `10.1016/j.frl.2025.108656`
**Last revised:** 2026-08-06

## 1. Strategy Logic

On the first tradable XAU D1 bar of each broker month, reconstruct common XAU
and XAG completed D1 closes and calculate synchronized simple daily returns
whose ending timestamps lie inside the immediately preceding complete broker
month. For each metal, sum squared positive and negative returns and calculate
`RSJ = (RV+ - RV-) / (RV+ + RV-)`. Buy the lower-RSJ metal and short the
higher-RSJ metal, allocate half of one fixed-risk package to each leg, and
close and rerank at the next month transition. A tie or invalid input consumes
the month and stays flat.

This is a signed-semivariance cross-sectional rank. It uses no price ratio,
OLS residual, spread z-score, momentum, calendar direction, realized skewness,
oscillator, ML, or adaptive threshold.

## 2. Parameters

| Parameter | Locked value | Meaning |
|---|---:|---|
| `strategy_lookback_months` | 1 | immediately preceding complete broker month |
| `strategy_history_bars` | 80 | bounded synchronized D1 history request |
| `strategy_min_return_observations` | 15 | minimum common daily returns |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | hard-stop distance per leg |
| `strategy_max_hold_days` | 35 | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | basket-order deviation |

All framework, risk, news, Friday-close, stress, and strategy values are
fail-closed against the one authorized Q02 baseline.

## 3. Symbol Universe

- Host/slot 0: `XAUUSD.DWX`, magic `202340000`.
- Traded slot 1: `XAGUSD.DWX`, magic `202340001`.
- Logical Q02 symbol: `QM5_20234_XAU_XAG_RSJ_D1`.
- No standalone-leg interpretation or single-leg fallback is authorized.

## 4. Timeframe

The host and both return series use `D1`. Decisions occur only on a genuine
broker-month transition. Formation excludes the current month and requires at
least 15 returns calculated from timestamps common to both metal histories.
Expected cadence is approximately 12 packages per year; Q02 retires the
candidate below five packages per full year.

## 5. Expected Behaviour

The package is opposite-sided and monthly, with exposure driven by relative
upside/downside semivariance rather than outright metal direction. Equal
stop-risk halves do not guarantee dollar or beta neutrality. The manager
closes the prior package before renewal and flattens any orphan, duplicate, or
same-side pair. Persistent attempt state plus deal history prevents restart
retries. The existing energy carrier's adverse economics do not transfer.

## 6. Source Citation

Kiss, Tamas, and Ferreira Batista Martins, Igor (2025), "Good Volatility, Bad
Volatility and the Cross Section of Commodity Returns," *Finance Research
Letters* 86 Part D, article 108656, DOI
https://doi.org/10.1016/j.frl.2025.108656. The source ranks a broad commodity-
futures cross-section monthly on normalized relative signed jump and reports a
negative RSJ premium. It does not test this two-metal CFD carrier, and no
source or sibling-carrier result transfers.

## 7. Risk Model

Q02 is locked to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the complete package. Each leg receives half of the
stop-normalized risk budget and a broker-side `3.5 * ATR(20,D1)` stop. News
axes and Friday close are OFF for the structural baseline. No live, demo,
shadow, optimization, stress, or deployment setfile is created.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-06 | initial approved XAU/XAG RSJ carrier build |
| v1.1 | 2026-08-06 | strict compile and full V5 build check PASS with zero warnings |
| v1.2 | 2026-08-06 | Q02 enqueue withheld at the binding 10-of-7 factory-terminal CPU ceiling |
