# QM5_41364_xtixng-wclv-div-rv - Strategy Spec

**EA ID:** QM5_41364
**Slug:** `xtixng-wclv-div-rv`
**Strategy ID:** `AI-CODEX-XTIXNG-WCLVDIV-RV-20260906_S01`
**Source:** `AI-CODEX-XTIXNG-WCLVDIV-RV-20260906`
**Author:** Codex
**Last revised:** 2026-09-06

## 1. Strategy Logic

On the first synchronized tradable D1 bar of each new broker week, aggregate
XTI and XNG OHLC from the immediately completed broker week. Compute each
leg's final-close location independently and trade only when the locations are
in strict opposite outer terciles. Sell the upper-location leg and buy the
lower-location leg as one equal-notional package, then close both legs at the
next broker-week boundary or the stale guard.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_history_bars_d1` | 30 | bounded completed-week history buffer |
| `strategy_min_week_sessions` | 3 | holiday-week lower bound |
| `strategy_max_week_sessions` | 5 | broker-week upper bound |
| `strategy_clv_lower` | 0.333333333333 | strict lower-tercile boundary |
| `strategy_clv_upper` | 0.666666666667 | strict upper-tercile boundary |
| `strategy_entry_grace_minutes` | 180 | first-week-bar decision window |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal entry-notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | lot-step mismatch ceiling |
| `strategy_max_hold_days` | 10 | stale package repair |
| `strategy_xti_max_spread_points` | 1500 | XTI cost guard |
| `strategy_xng_max_spread_points` | 3000 | XNG cost guard |
| `strategy_deviation_points` | 20 | order deviation |

All parameters are locked for Q02.

## 3. Symbol Universe

- Host: exact `XTIUSD.DWX`, D1, slot 0, magic `413640000`.
- Companion: exact `XNGUSD.DWX`, D1, slot 1, magic `413640001`.
- Logical symbol: `QM5_41364_XTI_XNG_WCLVDIV_RV_D1`.

## 4. Timeframe

- Decision timeframe: D1.
- Formation: exact synchronized immediately completed broker-week OHLC.
- Hold: one broker week, with a ten-calendar-day stale repair.

## 5. Expected Behaviour

Expected density is six to twelve completed paired packages per full post-
warm-up year; Q02 retires below five in any scored year. The rule is a
market-neutral-style energy construction, not a claim of exact neutrality or
decorrelation. Q09 alone owns realized portfolio overlap.

## 6. Source Citation

Villar and Joutz (2006), U.S. EIA, and Ramberg and Parsons (2012), *The Energy
Journal* 33(2), DOI `10.5547/01956574.33.2.2`.

Canonical packet:
`strategy-seeds/sources/AI-CODEX-XTIXNG-WCLVDIV-RV-20260906/source.md`.
The exact CLV conjunction is a disclosed QM hypothesis; no source or
precious-metals sibling performance transfers. R1 lineage and R2-R4 approval
are recorded in the approved card.

## 7. Risk Model

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg has a frozen `3.5*ATR(20,D1)` hard stop and no
target; combined normalized stop risk is capped at the one package budget.
Equal absolute notionals may still leave factor, beta, gap, basis, financing,
spread, or one-leg execution risk.

No live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`, deploy
manifest, portfolio-gate change, portfolio admission, correlation waiver,
external feed, retry, scale-in, grid, pyramid, trail, break-even, or partial
exit is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-06 | initial build from approved card | governed source/G0 and active magic slots 0/1 |
