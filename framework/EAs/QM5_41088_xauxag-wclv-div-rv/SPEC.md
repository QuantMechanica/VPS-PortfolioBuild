# QM5_41088_xauxag-wclv-div-rv - Strategy Spec

**EA ID:** QM5_41088

**Slug:** `xauxag-wclv-div-rv`

**Strategy ID:** `SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026_S01`

**Source:** `SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-21

## 1. Strategy Logic

On the first tradable `XAUUSD.DWX` D1 bar of a new normalized Monday-anchored
broker week, aggregate synchronized XAU/XAG D1 OHLC pairs from the immediately
preceding completed week. Each leg must have the same three to five unique
session timestamps.

For each leg compute
`CLV=(completed_week_close-completed_week_low)/(completed_week_high-completed_week_low)`.
Sell XAU and buy XAG only when gold is strictly above the upper tercile and
silver is strictly below the lower tercile. Buy XAU and sell XAG only in the
strict inverse state. Boundary equality, interior or same-tercile states,
invalid ranges, malformed history, asynchrony, or late attachment consumes the
week flat. The package targets equal absolute notional, uses one aggregate
fixed-risk budget, and freezes a hard ATR stop on each leg.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_history_bars_d1` | 30 | bounded completed-week D1 buffer |
| `strategy_min_week_sessions` | 3 | holiday-week lower bound |
| `strategy_max_week_sessions` | 5 | completed-week upper bound |
| `strategy_clv_lower` | `0.333333333333` | strict lower-tercile boundary |
| `strategy_clv_upper` | `0.666666666667` | strict upper-tercile boundary |
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal absolute notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | rounded-lot mismatch ceiling |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_xau_max_spread_points` | 1500 | host entry cost guard |
| `strategy_xag_max_spread_points` | 500 | companion entry cost guard |
| `strategy_deviation_points` | 20 | market-order deviation |
| `qm_friday_close_enabled` | false | preserve full-week hold |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host: exact `XAUUSD.DWX`, D1, slot 0, magic `410880000`.
- Companion: exact `XAGUSD.DWX`, D1, slot 1, magic `410880001`.
- Logical symbol: `QM5_41088_XAU_XAG_WCLVDIV_RV_D1`.
- No external signal, conversion, or third hedge symbol is used.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: the synchronized immediately completed broker week, with three
  to five sessions per leg.
- Trigger: strict opposite outer-tercile per-leg weekly close locations.
- Direction: sell the upper-location metal and buy the lower-location metal.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately six to twelve completed packages per full post-warm-up year;
  Q02 retires below five.
- Symmetric paired reversion only after a strict completed-week auction-
  location disagreement.
- One aggregate fixed-risk package and one consumed attempt per broker week.
- Equality, same-tercile states, invalid history, and late attachment remain
  flat; there is no fallback or retry.
- Carrier and mechanic do not prove decorrelation; Q09 alone owns realized
  portfolio correlation.

## 6. Source Citation

Schweikert, K. (2018), "Are gold and silver cointegrated? New evidence from
quantile cointegrating regressions," *Journal of Banking & Finance* 88, 44-51,
DOI `10.1016/j.jbankfin.2017.11.010`, with supporting carrier definition from
CME Group, "Gold & Silver Ratio Spread."

Canonical bounded source packet:
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026/source.md`.

The sources support testing a state-dependent gold/silver relative-value
carrier. The completed-week opposite-leg CLV admission state, contrarian side,
tercile boundaries, and one-week hold are disclosed QM hypotheses; no source
result transfers to this CFD package.

## 7. Risk Model And Scope

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg has a frozen `3.5*ATR(20,D1)` hard stop, no
target, and combined normalized stop risk cannot exceed the one fixed-risk
budget. Rounded orders target one-to-one absolute entry notional and reject
more than 20 percent mismatch.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, decorrelation claim,
correlation waiver, portfolio-gate change, current-week signal price, ratio
center, fitted beta, return filter, external feed, retry, scale-in, grid,
martingale, pyramid, target, trail, break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-21 | approved build-directory identity | source approval `2b66172a6`; EA-ID reservation `14ed68e12`; G0 card `b51b2de24`; magic allocation `433b05f0c` |
| v1-build | 2026-08-21 | deterministic implementation and Q01 validation | 10-test reference suite; strict compile/build PASS; static P1 PASS |
| v2-q02 | 2026-08-21 | paced Q02 enqueue | one canonical pending row `bf1dfee8-add9-481a-93c1-568314f1c5b3`; no dispatcher or manual tester action |
