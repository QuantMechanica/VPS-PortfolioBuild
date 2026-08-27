# QM5_41186_xtixng-median-runs-rv - Strategy Spec

**EA ID:** QM5_41186

**Slug:** `xtixng-median-runs-rv`

**Strategy ID:** `VILLAR-NIST-XTIXNG-MEDRUN-RV-2026_S01`

**Source:** `VILLAR-NIST-XTIXNG-MEDRUN-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-27

## 1. Strategy Logic

On the first executable synchronized `XTIUSD.DWX`/`XNGUSD.DWX` D1 bar of a
new broker-calendar month, exclude the current month and select the latest
exactly timestamp-matched close pair in each of the immediately prior
thirteen consecutive broker months. Form
`L[i]=ln(XTI_close[i])-ln(XNG_close[i])`, oldest to newest.

Strict-rank `L[0..12]` from 1 through 13. Omit the unique rank seven, map
ranks below seven to `-1` and ranks above seven to `+1`, require six of each,
and count `R=1+sum(B[k]!=B[k-1])` over the resulting twelve-state sequence.
The omission bridges the median's chronological neighbors. At inclusive
`R<=7`, newest rank above seven maps to SELL XTI / BUY XNG and newest rank
below seven maps to BUY XTI / SELL XNG. More than seven runs, newest median,
or any invalid/tied path consumes flat.

The exposure is one atomic, opposite-side, equal-target-notional energy
package held to the next broker month with one aggregate fixed-risk ceiling
and frozen per-leg ATR hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xng_symbol` | `XNGUSD.DWX` | exact companion |
| `strategy_endpoint_count` | 13 | synchronized completed months |
| `strategy_max_runs` | 7 | inclusive maximum qualifying runs |
| `strategy_history_bars_d1` | 900 | bounded synchronized D1 scan per symbol |
| `strategy_entry_window_minutes` | 180 | first-month-bar execution window |
| `strategy_max_endpoint_gap_days` | 10 | newest endpoint freshness guard |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal target absolute notionals |
| `strategy_max_notional_mismatch_fraction` | 0.20 | package validity cap |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_xti_max_spread_points` | 1500 | XTI entry-cost guard |
| `strategy_xng_max_spread_points` | 3000 | XNG entry-cost guard |
| `strategy_deviation_points` | 20 | framework order deviation contract |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All strategy parameters are singleton-locked for the Q02 baseline.

## 3. Symbol Universe

- Host/traded slot 0: exact `XTIUSD.DWX`, D1, magic `411860000`.
- Companion/traded slot 1: exact `XNGUSD.DWX`, D1, magic `411860001`.
- Logical symbol: `QM5_41186_XTI_XNG_MEDRUN_RV_D1`.
- The two legs are one strategy package; neither is a standalone signal.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: thirteen consecutive synchronized completed broker month ends.
- Trigger: inclusive `R<=7` with a nonmedian newest ratio, traded contrarian.
- Hold: first tick in a later broker month, with forty-day stale repair.

## 5. Expected Behaviour

- Approximately 5 to 8 completed packages per full post-warm-up year; Q02
  retires below five in any such year.
- Contrarian oil/gas relative-value exposure with no index or metal leg.
- One aggregate fixed-risk package and one consumed attempt per broker month.
- Any tied ratio, invalid permutation, newest median, or `R>7` consumes flat.
- Q09 alone owns any realized portfolio-correlation conclusion.

## 6. Source Citation

Jose A. Villar and Frederick L. Joutz (2006), *The Relationship Between Crude
Oil and Natural Gas Prices*, U.S. Energy Information Administration; David J.
Ramberg and John E. Parsons (2012), *The Weak Tie Between Natural Gas and Oil
Prices*, *The Energy Journal* 33(2), DOI `10.5547/01956574.33.2.2`; and the
NIST/SEMATECH e-Handbook section 1.3.5.13, *Runs Test for Detecting
Non-randomness*.

Canonical bounded packet:
`strategy-seeds/sources/VILLAR-NIST-XTIXNG-MEDRUN-RV-2026/source.md`.

The sources support a weak, time-varying oil/gas relationship and the named
median-dichotomy run definition. The exact sample, threshold, contrarian
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
average-rank tie handling, p-value, fitted hedge ratio, signal-strength
sizing, external feed, retry, scale-in, grid, martingale, pyramid, target,
trail, break-even move, or partial exit.

## Framework Alignment

- no_trade: exact symbols/period/ID/slots and locked risk/news/Friday inputs.
- trade_entry: consumed month, synchronized endpoints, chronological ratios,
  strict ranks, median omission, six/six invariant, complete run count,
  inclusive contrarian gate, spread/quote/ATR/stop checks, equal-notional
  sizing, and atomic submission.
- trade_management: malformed-package repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-27 | approved source build | G0-approved card; governed magics `411860000`/`411860001`; one logical Q02 preset |
