# QM5_20233_xauxag-skew-rank - Strategy Spec

**EA ID:** QM5_20233  
**Strategy ID:** `FERNANDEZ-SKEW-2018_XAU_XAG_S02`  
**Source:** Fernandez-Perez et al. (2018), DOI `10.1016/j.jbankfin.2017.06.015`  
**Last revised:** 2026-08-17

## 1. Strategy Logic

On the first tradable XAU D1 bar of each broker month, reconstruct the prior
12 complete broker months of XAU and XAG daily log returns. Calculate each
metal's population Pearson third standardized moment, buy the lower-skew
metal, and short the higher-skew metal. Allocate half of one fixed-risk
package to each leg, then close and rerank at the next month transition.
A tie or any invalid input consumes the month and stays flat.

This is a third-moment cross-sectional rank. It uses no price ratio, OLS
residual, spread z-score, momentum, oscillator, calendar direction, ML, or
adaptive threshold and is therefore distinct from the existing metal book.

## 2. Parameters

| Parameter | Locked value | Meaning |
|---|---:|---|
| `strategy_lookback_months` | 12 | complete broker-month formation window |
| `strategy_history_bars` | 500 | bounded D1 history request |
| `strategy_min_return_observations` | 180 | minimum returns per metal |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | hard-stop distance per leg |
| `strategy_max_hold_days` | 35 | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | basket-order deviation |

All framework, risk, news, Friday-close, stress, and strategy values are
fail-closed against the one authorized Q02 baseline.

## 3. Symbol Universe

- Host/slot 0: `XAUUSD.DWX`, magic `202330000`.
- Traded slot 1: `XAGUSD.DWX`, magic `202330001`.
- Logical Q02 symbol: `QM5_20233_XAU_XAG_SKEW_RANK_D1`.
- No standalone-leg interpretation or single-leg fallback is authorized.

## 4. Timeframe

The host and both return series use `D1`. Decisions occur only on a genuine
broker-month transition. Formation excludes the current month, uses only
completed D1 closes, and requires at least 180 valid returns for each metal.
Expected cadence after warm-up is approximately 12 packages per year; Q02
retires the candidate below five packages per full year.

## 5. Expected Behaviour

The package is opposite-sided and monthly, with exposure driven by relative
realized skewness rather than outright metal direction. Equal stop-risk halves
do not guarantee dollar or beta neutrality. The manager closes the prior
package before renewal and flattens any orphan, duplicate, or same-side pair.
A persistent month-attempt marker plus deal history prevents restart retries.

## 6. Source Citation

Fernandez-Perez, A.; Frijns, B.; Fuertes, A.-M.; and Miffre, J. (2018),
"The Skewness of Commodity Futures Returns," *Journal of Banking & Finance*
86, 143-158, DOI https://doi.org/10.1016/j.jbankfin.2017.06.015.
The source ranks 27 commodity futures monthly on Pearson skewness estimated
from the prior 12 months of daily returns; gold and silver are explicit
members. Its broad-universe results do not transfer to this two-CFD carrier.

## 7. Risk Model

Q02 is locked to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the complete package. Each leg receives half of the
stop-normalized risk budget and a broker-side `3.5 * ATR(20,D1)` stop. News
axes and Friday close are OFF for the structural baseline. No live, demo,
shadow, optimization, stress, or deployment setfile is created.

## 8. Q02 Infrastructure Repair

The sealed Q02 row `92235bb9-1fc0-4aeb-90c3-f8771ca9e2bd` reached valid
two-leg trades but timed out after 25,200 seconds. While a package was open,
the original build scanned its positions several times on every Model-4 tick
and each ownership check called `QM_MagicChecked`. That lookup walks the full
generated registry, so the cost multiplied across real ticks and prevented a
five-year run from completing.

The repaired build resolves the two immutable registered magics once in
`OnInit`. Package-composition management now runs on each D1 bar and after a
trade transaction; the transaction latch preserves prompt orphan cleanup after
a stop, close, entry, or rollback. Monthly formation, rank direction, entry,
renewal, stale exit, hard stops, pair sizing, news policy, and all frozen inputs
are unchanged. Q02 remains the authority for frequency and economics.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-06 | initial approved XAU/XAG skewness-rank carrier build |
| v2 | 2026-08-17 | remove the Q02 per-tick magic-resolution and pair-scan hot path without changing strategy mechanics |
