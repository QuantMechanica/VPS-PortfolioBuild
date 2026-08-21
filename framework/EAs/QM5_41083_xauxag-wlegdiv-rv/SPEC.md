# QM5_41083_xauxag-wlegdiv-rv - Strategy Spec

EA ID: `QM5_41083`

Slug: `xauxag-wlegdiv-rv`

Strategy ID: `SCHWEIKERT-CME-XAUXAG-WLEGDIV-RV-2026_S01`

Source: `SCHWEIKERT-CME-XAUXAG-WLEGDIV-RV-2026`

Author: Codex

Last revised: 2026-08-21

## 1. Strategy Logic

On the first tradable `XAUUSD.DWX` D1 bar of a new broker week, reconstruct
the synchronized week-end close pairs of the two immediately preceding
consecutive broker weeks. Compute each metal's log return over that exact same
completed weekly interval.

Trade only when gold and silver have strictly opposite nonzero return signs.
Gold positive and silver negative sells gold and buys silver; gold negative
and silver positive buys gold and sells silver. Same-sign, zero, equality,
malformed history, or late attachment consumes the week flat. The logical
package targets equal absolute notional, uses one aggregate fixed-risk budget,
and freezes a hard ATR stop on each leg.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_history_bars_d1` | 30 | bounded two-week D1 buffer |
| `strategy_min_week_sessions` | 3 | holiday-week lower bound |
| `strategy_max_week_sessions` | 5 | completed-week upper bound |
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal absolute notional |
| `strategy_max_notional_mismatch_pct` | 20.0 | rounded-lot mismatch ceiling |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_xau_max_spread_points` | 1500 | host entry cost guard |
| `strategy_xag_max_spread_points` | 500 | companion entry cost guard |
| `strategy_deviation_points` | 20 | market-order deviation |
| `qm_friday_close_enabled` | false | preserve full-week hold |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host: exact `XAUUSD.DWX`, D1, slot 0, magic `410830000`.
- Companion: exact `XAGUSD.DWX`, D1, slot 1, magic `410830001`.
- Logical symbol: `QM5_41083_XAU_XAG_WLEGDIV_RV_D1`.
- No external signal, conversion, or third hedge symbol is used.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: two synchronized consecutive completed week-end pairs.
- Trigger: strictly opposite individual gold and silver weekly log-return
  signs over the common interval.
- Direction: fade the weekly winner and buy the weekly loser.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately eight to eighteen completed packages per full post-warm-up
  year; Q02 retires below five.
- Symmetric paired reversion only after a clean individual-leg divergence.
- One aggregate fixed-risk package and one consumed attempt per broker week.
- Carrier and mechanic do not prove decorrelation; Q09 alone owns realized
  portfolio correlation.

## 6. Source Citation

Schweikert, K. (2018), "Are gold and silver cointegrated? New evidence from
quantile cointegrating regressions," *Journal of Banking & Finance* 88, 44-51,
DOI `10.1016/j.jbankfin.2017.11.010`, with supporting carrier definition from
CME Group, "Gold & Silver Ratio Spread."

Canonical bounded source packet:
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WLEGDIV-RV-2026/source.md`.

The sources support testing a state-dependent gold/silver relative-value
carrier. The weekly individual-leg sign condition and one-week fade are
disclosed QM hypotheses; no source result transfers to this CFD package.

## 7. Risk Model And Scope

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg has a frozen completed-bar ATR stop. Combined
normalized stop risk cannot exceed the one fixed-risk budget.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, decorrelation claim,
correlation waiver, portfolio-gate change, external feed, retry, scale-in,
grid, martingale, pyramid, target, trail, break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-21 | approved build-directory identity | source approval `55a658719`; atomic EA-ID reservation `b1c4e3988`; G0 card |
| v1-build | 2026-08-21 | deterministic implementation and Q01 validation | 9-test reference suite; strict compile/build PASS; static P1 PASS |
