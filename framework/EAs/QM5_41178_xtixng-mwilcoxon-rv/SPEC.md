# QM5_41178_xtixng-mwilcoxon-rv - Strategy Spec

**EA ID:** QM5_41178

**Slug:** `xtixng-mwilcoxon-rv`

**Strategy ID:** `VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026_S01`

**Source:** `VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-27

## 1. Strategy Logic

On the first executable synchronized `XTIUSD.DWX`/`XNGUSD.DWX` D1 bar of a
new broker-calendar month, exclude the current month and select the latest
exactly timestamp-matched close pair in each of the immediately prior twelve
consecutive broker months. Form
`s[i]=ln(XTI_close[i])-ln(XNG_close[i])`, oldest to newest.

Fix `O=s[0..5]` and `N=s[6..11]`. With ties forbidden, count every one of the
36 cross-block comparisons. `U_new` is the count for which a newer ratio is
strictly above an older ratio; `U_old` is the complementary count. Independently
compute the newer block's strict combined-rank sum and require
`W_new-21=U_new` and `U_new+U_old=36`.

`U_new>=24` maps to SELL XTI / BUY XNG; `U_new<=12` maps to BUY XTI / SELL
XNG; interior values and exact ties consume flat. The exposure is one atomic,
opposite-side, equal-target-notional package held to the next broker month
under one aggregate fixed-risk ceiling and frozen per-leg ATR hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xng_symbol` | `XNGUSD.DWX` | exact companion |
| `strategy_endpoint_count` | 12 | synchronized completed months |
| `strategy_block_size` | 6 | exact older/newer block size |
| `strategy_u_lower` | 12 | inclusive long-ratio boundary |
| `strategy_u_upper` | 24 | inclusive short-ratio boundary |
| `strategy_history_bars_d1` | 900 | bounded synchronized D1 scan per symbol |
| `strategy_entry_window_minutes` | 180 | first-month-bar execution window |
| `strategy_max_endpoint_gap_days` | 10 | prior-month freshness guard |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal target absolute notionals |
| `strategy_max_notional_mismatch_fraction` | 0.20 | package validity cap |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_xti_max_spread_points` | 1500 | XTI entry-cost guard |
| `strategy_xng_max_spread_points` | 3000 | XNG entry-cost guard |
| `strategy_deviation_points` | 20 | framework order deviation contract |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host/traded slot 0: exact `XTIUSD.DWX`, D1, magic `411780000`.
- Companion/traded slot 1: exact `XNGUSD.DWX`, D1, magic `411780001`.
- Logical symbol: `QM5_41178_XTI_XNG_MWILCOXON_RV_D1`.
- The two legs are one strategy package; neither is a standalone signal.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: twelve consecutive synchronized completed broker month ends.
- Trigger: inclusive `U_new<=12` or `U_new>=24`, traded contrarian.
- Hold: first tick in a later broker month, with forty-day stale repair.

## 5. Expected Behaviour

- Approximately 4 to 8 completed packages per full post-warm-up year; Q02
  retires below four.
- Symmetric contrarian oil/gas relative-value exposure.
- One aggregate fixed-risk package and one consumed attempt per broker month.
- Any ratio tie or interior U value consumes flat.
- Q09 alone owns any realized portfolio-correlation conclusion.

## 6. Source Citation

Jose A. Villar and Frederick L. Joutz (2006), *The Relationship Between Crude
Oil and Natural Gas Prices*, U.S. Energy Information Administration; David J.
Ramberg and John E. Parsons (2012), *The Weak Tie Between Natural Gas and Oil
Prices*, *The Energy Journal* 33(2), 13-35, DOI
`10.5547/01956574.33.2.2`; H. B. Mann and D. R. Whitney (1947), *The Annals
of Mathematical Statistics* 18(1), 50-60, DOI
`10.1214/aoms/1177730491`; and pinned R Core `stats::wilcox.test` source
and manual.

Canonical bounded packet:
`strategy-seeds/sources/VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026/source.md`.

The sources support a weak, time-varying oil/gas relationship and exact
two-sample ordinal arithmetic. The sample, split, thresholds, contrarian
direction, continuous-CFD mapping, execution, and risk are disclosed QM
hypotheses; no source result transfers.

## 7. Risk Model

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg begins at half the aggregate frozen-stop risk
allowance; balancing may only reduce the larger target notional. The EA
requires no more than 20% realized notional mismatch. Both news axes and
Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deploy or live manifest, portfolio admission,
correlation waiver, portfolio-gate change, current-month signal price,
average-rank tie handling, signal-strength sizing, external feed, retry,
scale-in, grid, martingale, pyramid, target, trail, break-even move, or
partial exit.

## Framework Alignment

- no_trade: exact symbols/period/ID/slots and locked risk/news/Friday inputs.
- trade_entry: consume-first month state, synchronized endpoint selection,
  chronological ratios, fixed blocks, exact U complement and rank-sum
  invariants, inclusive contrarian gate, spread/quote/ATR/stop checks,
  equal-notional sizing, and atomic submission.
- trade_management: malformed-package repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-27 | approved source build | G0-approved card; governed magics `411780000`/`411780001`; one logical Q02 preset |
