# QM5_41374_xtixng-weffdiv-rv - Strategy Spec

**EA ID:** QM5_41374  
**Slug:** `xtixng-weffdiv-rv`  
**Strategy ID:** `AI-CODEX-XTIXNG-WEFFDIV-RV-20260907_S01`  
**Source:** `AI-CODEX-XTIXNG-WEFFDIV-RV-20260907`  
**Last revised:** 2026-09-07

## 1. Strategy Logic

On the first synchronized tradable D1 bar of each new broker week, aggregate
XTI and XNG OHLC from the immediately completed broker week. For each leg,
divide the absolute weekly open-to-close body by the weekly high-low range.
Trade only when one efficiency is strictly above two-thirds and the other is
strictly below one-third. Fade the high-efficiency leg's body direction and
take the opposite side in the low-efficiency leg as one equal-notional
package. Close both legs at the next week boundary or the stale guard.

## 2. Locked Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_history_bars_d1` | 30 | bounded completed-week history buffer |
| `strategy_min_week_sessions` | 3 | holiday-week lower bound |
| `strategy_max_week_sessions` | 5 | broker-week upper bound |
| `strategy_efficiency_lower` | 0.333333333333 | strict low-efficiency boundary |
| `strategy_efficiency_upper` | 0.666666666667 | strict high-efficiency boundary |
| `strategy_entry_grace_minutes` | 180 | first-week-bar decision window |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal entry-notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | lot-step mismatch ceiling |
| `strategy_max_hold_days` | 10 | stale package repair |
| `strategy_xti_max_spread_points` | 1500 | XTI cost guard |
| `strategy_xng_max_spread_points` | 3000 | XNG cost guard |
| `strategy_deviation_points` | 20 | order deviation |

There is no Q02 optimization surface.

## 3. Identity And Lifecycle

- Host: exact `XTIUSD.DWX`, D1, slot 0, magic `413740000`.
- Companion: exact `XNGUSD.DWX`, D1, slot 1, magic `413740001`.
- Logical symbol: `QM5_41374_XTI_XNG_WEFFDIV_RV_D1`.
- Formation: one exact synchronized immediately completed broker week.
- Hold: to the next broker week, with ten calendar days as stale repair.
- Attempt: persisted once per broker week before any fallible signal or order
  gate; no backfill or retry.

## 4. Risk And Safety

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Each leg has a frozen `3.5*ATR(20,D1)` stop and no target. Combined normalized
stop risk is capped at the one package budget. Equal absolute notionals do not
establish beta, volatility, factor, dollar, or portfolio neutrality.

The locked-configuration guard pins only strategy inputs, `qm_ea_id`,
`qm_magic_slot_offset`, and fixed-risk mode. It does not pin RNG, news,
Friday-close, or portfolio-weight inputs; stress rejection is checked only for
finiteness and the inclusive zero-to-one range.

No live/demo/shadow/stress/optimization preset, manual tester dispatch,
AutoTrading, `T_Live`, deploy manifest, portfolio-gate change, portfolio
admission, correlation waiver, external feed, retry, scale-in, grid, pyramid,
trail, break-even, or partial exit is authorized.

## 5. Source And Falsification

Villar and Joutz (2006), U.S. EIA; Ramberg and Parsons (2012), *The Energy
Journal* 33(2), DOI `10.5547/01956574.33.2.2`; and Fuertes, Miffre, and Rallis
(2010), *Journal of Banking & Finance* 34(10), DOI
`10.1016/j.jbankfin.2010.04.009`. The exact efficiency-divergence conjunction
is a disclosed QM hypothesis; no source result transfers.

Expected density is eight to eighteen paired packages per full post-warm-up
year. Q02 retires on zero packages, fewer than five packages in any full year,
or nonpositive governed economics. Q09 alone owns realized correlation.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-07 | initial build from approved card | governed source/G0 and active magic slots 0/1 |
