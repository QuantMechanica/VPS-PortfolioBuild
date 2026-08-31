# QM5_41246_xauxag-mturnpoint-rv - Strategy Spec

**EA ID:** QM5_41246

**Slug:** `xauxag-mturnpoint-rv`

**Strategy ID:** `SCHWEIKERT-WALLIS-MOORE-CME-XAUXAG-MTURNPOINT-RV-2026_S01`

**Source:** `SCHWEIKERT-WALLIS-MOORE-CME-XAUXAG-MTURNPOINT-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-31

## 1. Strategy Logic

On the first executable synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 bar of
a new broker month, exclude the current month and select the latest exactly
timestamp-matched close pair in each of the immediately prior thirteen
consecutive broker months. Form
`L[i]=ln(XAU_close[i])-ln(XAG_close[i])`, oldest to newest.

Require every pair of ratio endpoints to differ by more than `1e-12`. Across
the eleven interior observations, count a turning point when the observation
is strictly above both neighbors or strictly below both neighbors. The path
qualifies exactly when `3*TP<22`, equivalently `TP<=7`. Fade its endpoint
displacement: a positive displacement maps to SELL XAU / BUY XAG and a
negative displacement maps to BUY XAU / SELL XAG. Ties, `TP>=8`, or endpoint
displacement within `1e-12` consume the month flat.

The exposure is one atomic, opposite-side, equal-target-notional package held
for one broker month with one aggregate fixed-risk ceiling and frozen per-leg
ATR hard stops. Turning-point count and displacement magnitude never scale
risk.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_endpoint_count` | 13 | synchronized completed months |
| `strategy_max_turning_points` | 7 | inclusive persistence boundary |
| `strategy_ratio_tie_epsilon` | 0.000000000001 | pairwise distinction and direction epsilon |
| `strategy_history_bars_d1` | 900 | bounded synchronized D1 scan |
| `strategy_entry_window_minutes` | 180 | first-month-bar execution window |
| `strategy_max_endpoint_gap_days` | 10 | prior-month freshness guard |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal target absolute notionals |
| `strategy_max_notional_mismatch_fraction` | 0.20 | package validity cap |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_xau_max_spread_points` | 1500 | XAU cost guard |
| `strategy_xag_max_spread_points` | 500 | XAG cost guard |
| `strategy_deviation_points` | 20 | order-deviation contract |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

Every strategy parameter is locked for the Q02 baseline.

## 3. Symbol Universe

- Slot 0: exact `XAUUSD.DWX`, D1, magic `412460000`.
- Slot 1: exact `XAGUSD.DWX`, D1, magic `412460001`.
- Logical symbol: `QM5_41246_XAU_XAG_MTURNPOINT_RV_D1`.
- The legs are one package; neither is a standalone signal.

## 4. Timeframe

- Signal and execution: D1.
- Formation: thirteen consecutive synchronized completed month ends.
- Trigger: `TP<=7` and nonzero endpoint displacement, traded contrarian.
- Hold: first tick in a later broker month, with forty-day stale repair.

## 5. Expected Behaviour

- Approximately 5-8 packages/full post-warm-up year; retire below five.
- Symmetric contrarian gold/silver relative-value exposure.
- One aggregate fixed-risk package and one consumed attempt per month.
- Any pairwise ratio tie, `TP>=8`, or zero displacement consumes flat.
- Q09 alone owns realized portfolio-correlation conclusions.

## 6. Source Citation

Karsten Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`; CME Group, *Gold & Silver Ratio Spread*;
W. Allen Wallis and Geoffrey H. Moore (1941), *Journal of the American
Statistical Association* 36(215), 401-409, DOI
`10.1080/01621459.1941.10500577`; and the complete governed public
strict-turning-point method files.

Canonical packet:
`strategy-seeds/sources/SCHWEIKERT-WALLIS-MOORE-CME-XAUXAG-MTURNPOINT-RV-2026/source.md`.

The sources support a state-dependent relative carrier, intermarket-spread
lineage, and strict local-extrema arithmetic. The thirteen-month sample,
below-null-mean boundary, contrarian direction, CFD mapping, execution, and
risk are QM hypotheses; no source result transfers.

## 7. Risk Model

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg begins at half the frozen-stop risk allowance;
balancing may only reduce the larger target notional. Realized mismatch must
not exceed 20%. Both news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deploy/live manifest, portfolio admission, correlation
waiver, portfolio-gate change, current-month signal price, signal-strength
sizing, external feed, retry, scale-in, grid, martingale, pyramid, target,
trail, break-even move, or partial exit.

## Framework Alignment

- no_trade: exact symbols/period/ID/slots and locked risk/news/Friday inputs.
- trade_entry: consume month first, synchronize endpoints, reject ties, count
  eleven local triples, enforce the integer boundary, map contrarian sides,
  check spread/ATR/stops, balance notionals, and submit atomically.
- trade_management: malformed-package repair, later-month exit, stale repair.
- trade_close: framework close helper, broker hard stops, kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-31 | approved source build | G0-approved card; governed magics `412460000`/`412460001`; one logical Q02 preset |
