# QM5_41185_xauxag-fracd-rv - Strategy Spec

**EA ID:** QM5_41185

**Slug:** `xauxag-fracd-rv`

**Strategy ID:** `YAYA-CME-XAUXAG-FRACD-RV-2026_S01`

**Source:** `YAYA-CME-XAUXAG-FRACD-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-27

## 1. Strategy Logic

On the first executable synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 bar of a
new broker month, the EA exact-joins 316 completed daily close pairs in strict
chronological order and forms
`s[t]=ln(XAU_close[t])-ln(XAG_close[t])`.

It constructs exactly 64 fixed coefficients of `(1-L)^0.40` by
`w[0]=1` and `w[k]=w[k-1]*(k-1-0.40)/k`. The resulting 253 filtered outputs
are split into a 252-output baseline and one held-out latest output. The EA
uses the baseline sample mean and sample standard deviation (denominator 251),
requires sample deviation above `1e-12`, and calculates the latest z-score.

`z>=+0.50` maps to SELL XAU / BUY XAG; `z<=-0.50` maps to BUY XAU / SELL XAG;
an interior or invalid state consumes the month flat. Signal magnitude never
changes risk. The exposure is one atomic, opposite-side,
equal-target-notional package held for one broker month with one aggregate
fixed-risk ceiling and frozen per-leg ATR hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_pair_count_d1` | 316 | synchronized completed D1 pairs |
| `strategy_frac_lags` | 64 | exact fixed recurrence length |
| `strategy_baseline_outputs` | 252 | prior outputs in baseline |
| `strategy_frac_order` | 0.40 | fixed fractional-difference order |
| `strategy_entry_abs_z` | 0.50 | inclusive held-out extreme boundary |
| `strategy_history_bars_d1` | 700 | bounded exact-join scan per leg |
| `strategy_entry_window_minutes` | 180 | first-month-bar execution window |
| `strategy_max_endpoint_gap_days` | 10 | completed endpoint freshness guard |
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

- Slot 0: exact `XAUUSD.DWX`, D1, magic `411850000`.
- Slot 1: exact `XAGUSD.DWX`, D1, magic `411850001`.
- Logical symbol: `QM5_41185_XAU_XAG_FRACD_RV_D1`.
- The legs are one package; neither is a standalone signal.

## 4. Timeframe

- Signal and execution: D1.
- Formation: exactly 316 synchronized completed daily close pairs.
- Trigger: inclusive held-out `abs(z)>=0.50`, traded contrarian.
- Hold: first tick in a later broker month, with forty-day stale repair.

## 5. Expected Behaviour

- Approximately 6-9 packages/full post-warm-up year; retire below five.
- Symmetric contrarian gold/silver relative-value exposure.
- One aggregate fixed-risk package and one consumed attempt per month.
- A sub-threshold or invalid filter state consumes flat.
- Q09 alone owns realized portfolio-correlation conclusions.

## 6. Source Citation

Karsten Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021), *Resources
Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; and official CME
Group “Gold & Silver Ratio Spread” research.

Canonical packet:
`strategy-seeds/sources/YAYA-CME-XAUXAG-FRACD-RV-2026/source.md`.

The sources support a state-dependent fractional relationship and the
intermarket ratio carrier. Fixed filtering, the threshold, contrarian
direction, CFD mapping, execution, and risk are QM hypotheses; no source
result transfers.

## 7. Risk Model

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg begins at half the frozen-stop risk allowance;
balancing may only reduce the larger target notional. Realized mismatch must
not exceed 20%. Both news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deploy/live manifest, portfolio admission, correlation
waiver, portfolio-gate change, current-bar signal price, fitted memory order,
signal-strength sizing, external feed, retry, scale-in, grid, martingale,
pyramid, target, trail, break-even move, or partial exit.

## Framework Alignment

- no_trade: exact symbols/period/ID/slots and locked risk/news/Friday inputs.
- trade_entry: consumed month, exact-joined history, fixed recurrence,
  held-out baseline, inclusive contrarian gate, spread/ATR/stop checks,
  equal-notional sizing, and atomic submission.
- trade_management: malformed-package repair, later-month exit, stale repair.
- trade_close: framework close helper, broker hard stops, kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-27 | approved source build | G0-approved card; governed magics `411850000`/`411850001`; one logical Q02 preset |
