# QM5_41086_xauxag-commonshock-rv - Strategy Spec

**EA ID:** QM5_41086

**Slug:** `xauxag-commonshock-rv`

**Strategy ID:** `SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026_S01`

**Source:** `SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-21

## 1. Strategy Logic

On the first tradable `XAUUSD.DWX` D1 bar of a new broker week, reconstruct
the synchronized week-end close pairs of the two immediately preceding
consecutive broker weeks. Compute each metal's log return over that exact same
completed weekly interval.

Trade only when gold and silver have strict same-sign nonzero returns. Sell
gold and buy silver when gold's return is larger; buy gold and sell silver
when silver's return is larger. Mixed signs, zero, equality within `1e-10`,
malformed history, or late attachment consumes the week flat. The logical
package targets equal absolute notional, uses one aggregate fixed-risk budget,
and freezes a hard ATR stop on each leg.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_history_bars_d1` | 30 | bounded two-week D1 buffer |
| `strategy_min_sessions_per_week` | 3 | holiday-week lower bound |
| `strategy_max_sessions_per_week` | 5 | completed-week upper bound |
| `strategy_signal_epsilon` | `1e-10` | strict return-equality deadband |
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

- Host: exact `XAUUSD.DWX`, D1, slot 0, magic `410860000`.
- Companion: exact `XAGUSD.DWX`, D1, slot 1, magic `410860001`.
- Logical symbol: `QM5_41086_XAU_XAG_COMMONSHOCK_RV_D1`.
- No external signal, conversion, or third hedge symbol is used.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: two synchronized consecutive completed week-end pairs.
- Trigger: strict same-sign individual gold and silver weekly log returns over
  the common interval, with a strict relative-return inequality.
- Direction: sell the relative outperformer and buy the underperformer.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately fifteen to thirty-five completed packages per full post-warm-up
  year; Q02 retires below five.
- Symmetric paired reversion only after a clean common-direction dispersion.
- One aggregate fixed-risk package and one consumed attempt per broker week.
- Carrier and mechanic do not prove decorrelation; Q09 alone owns realized
  portfolio correlation.

## 6. Source Citation

Schweikert, K. (2018), "Are gold and silver cointegrated? New evidence from
quantile cointegrating regressions," *Journal of Banking & Finance* 88, 44-51,
DOI `10.1016/j.jbankfin.2017.11.010`, with supporting carrier definition from
CME Group, "Gold & Silver Ratio Spread."

Canonical bounded source packet:
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026/source.md`.

The sources support testing a state-dependent gold/silver relative-value
carrier. The same-direction weekly admission state, relative-outperformer
fade, and one-week hold are disclosed QM hypotheses; no source result
transfers to this CFD package.

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
| v0 | 2026-08-21 | approved build-directory identity | source approval `ff0d62e6d`; atomic EA-ID reservation `c2f395741`; G0 card `f9b95b762`; magic allocation `7c5ddaf5c` |
| v1-build | 2026-08-21 | deterministic implementation and Q01 validation | 10-test reference suite; strict compile/build PASS; static P1 PASS |
| v2-q02 | 2026-08-21 | paced Q02 handoff | this lane withheld apply at the 97% host-CPU ceiling; concurrent fleet state contained pending row `4859f62b-3a57-449c-b0c0-3cef50fd7806` |
