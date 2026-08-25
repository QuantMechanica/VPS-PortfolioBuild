# QM5_41157_xauxag-mtheilsen-rv - Strategy Spec

**EA ID:** QM5_41157

**Slug:** `xauxag-mtheilsen-rv`

**Strategy ID:** `SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026_S01`

**Source:** `SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-25

## 1. Strategy Logic

On the first executable synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 bar of a
new broker-calendar month, exclude the current month and select the latest
exactly timestamp-matched close pair in each of the immediately prior
thirteen consecutive broker months.

For every selected pair calculate `s=ln(XAU_close)-ln(XAG_close)`. In
chronological order enumerate every forward pair `0 <= i < j <= 12` and form
`(s[j]-s[i])/(j-i)`, producing exactly 78 slopes. Sort the slopes ascending
and average zero-based indexes 38 and 39. Fade a strictly positive slope with
SELL XAU / BUY XAG and a strictly negative slope with BUY XAU / SELL XAG.
Exact zero and malformed states consume the month flat. The raw endpoint
ratio displacement is diagnostic only and never gates direction.

The position is one atomic, opposite-side, equal-notional package held for
one broker month with one aggregate fixed-risk ceiling and frozen per-leg ATR
hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_month_end_count` | 13 | exact consecutive completed months |
| `strategy_history_bars_d1` | 500 | bounded synchronized D1 scan per symbol |
| `strategy_entry_window_minutes` | 180 | first-month-bar execution window |
| `strategy_max_endpoint_gap_days` | 10 | immediately prior month freshness guard |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal target absolute notionals |
| `strategy_max_notional_mismatch_fraction` | 0.20 | package validity cap |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_xau_max_spread_points` | 1500 | XAU entry-cost guard |
| `strategy_xag_max_spread_points` | 500 | XAG entry-cost guard |
| `strategy_deviation_points` | 20 | framework order deviation contract |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host/traded slot 0: exact `XAUUSD.DWX`, D1, magic `411570000`.
- Companion/traded slot 1: exact `XAGUSD.DWX`, D1, magic `411570001`.
- Logical symbol: `QM5_41157_XAU_XAG_MTHEILSEN_RV_D1`.
- The two legs are one strategy package; neither is a standalone signal.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: thirteen consecutive synchronized completed broker month ends.
- Estimator: all 78 forward log-ratio slopes with month-index denominators.
- Trigger: strict sign of the exact even-sample robust slope median.
- Hold: first tick in a later broker month, with a forty-day stale repair.

## 5. Expected Behaviour

- Approximately 10 to 12 completed packages per full post-warm-up year; Q02
  retires below five.
- Symmetric contrarian gold/silver relative-value exposure.
- One aggregate fixed-risk package and one consumed attempt per broker month.
- Opposite equal-notional legs seek different exposure from the certified
  directional book; Q09 alone owns realized portfolio correlation.

## 6. Source Citation

Karsten Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`; CME Group, "Gold & Silver Ratio Spread."

Canonical bounded packet:
`strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026/source.md`.

The sources support a state-dependent relative carrier and intermarket-spread
lineage. The governed method packet supplies exact thirteen-endpoint,
forward-pair, denominator, sort, and median arithmetic only. The paired
robust-slope horizon, fade direction, CFD mapping, execution, and risk are
disclosed QM hypotheses; no source result transfers.

## 7. Risk Model

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg begins at half of the aggregate frozen-stop
risk allowance; balancing may only reduce the larger target notional. The EA
requires no more than 20% realized notional mismatch. Both news axes and
Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio admission,
decorrelation claim, correlation waiver, portfolio-gate change, current-month
signal price, fitted center or scale, signal-strength sizing, external feed,
retry, scale-in, grid, martingale, pyramid, target, trail, break-even move, or
partial exit.

## Framework Alignment

- no_trade: exact symbols/period/ID/slots and locked risk/news/Friday inputs.
- trade_entry: consumed month, exact synchronized month-end selection,
  chronological ratios, 78 forward slopes, `j-i` denominators, even median,
  contrarian sides, spread/quote/ATR/stop checks, equal-notional sizing, and
  atomic two-order submission.
- trade_management: malformed-package repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-25 | approved source build | G0-approved card; governed magics `411570000`/`411570001`; one logical Q02 preset |
