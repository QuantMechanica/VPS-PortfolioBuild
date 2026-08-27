# QM5_41181_xauxag-mkendall-rv - Strategy Spec

**EA ID:** QM5_41181

**Slug:** `xauxag-mkendall-rv`

**Strategy ID:** `SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026_S01`

**Source:** `SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-27

## 1. Strategy Logic

On the first executable synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 bar of
a new broker month, exclude the current month and select the latest exactly
timestamp-matched close pair in each of the immediately prior thirteen
consecutive broker months. Form
`r[i]=ln(XAU_close[i])-ln(XAG_close[i])`, oldest to newest.

For all 78 `i<j` pairs, add +1 when the newer ratio is higher and -1 when it
is lower. Exact ties consume flat. `S>=14` maps to SELL XAU / BUY XAG;
`S<=-14` maps to BUY XAU / SELL XAG; interior scores consume flat. This is
the no-tie pairwise ordinal score `tau=S/78`, not a runtime significance
test. Score magnitude never changes risk.

The exposure is one atomic, opposite-side, equal-target-notional package held
for one broker month with one aggregate fixed-risk ceiling and frozen per-leg
ATR hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_endpoint_count` | 13 | synchronized completed months |
| `strategy_score_threshold` | 14 | inclusive absolute pair-score boundary |
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

- Slot 0: exact `XAUUSD.DWX`, D1, magic `411810000`.
- Slot 1: exact `XAGUSD.DWX`, D1, magic `411810001`.
- Logical symbol: `QM5_41181_XAU_XAG_MKENDALL_RV_D1`.
- The legs are one package; neither is a standalone signal.

## 4. Timeframe

- Signal and execution: D1.
- Formation: thirteen consecutive synchronized completed month ends.
- Trigger: inclusive `abs(S)>=14`, traded contrarian.
- Hold: first tick in a later broker month, with forty-day stale repair.

## 5. Expected Behaviour

- Approximately 5-8 packages/full post-warm-up year; retire below five.
- Symmetric contrarian gold/silver relative-value exposure.
- One aggregate fixed-risk package and one consumed attempt per month.
- Any ratio tie or interior pair score consumes flat.
- Q09 alone owns realized portfolio-correlation conclusions.

## 6. Source Citation

Karsten Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`; official CME Group "Gold & Silver Ratio
Spread" research; and the governed pairwise-rank arithmetic extraction from
Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`.

Canonical packet:
`strategy-seeds/sources/SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026/source.md`.

The sources support a state-dependent relative carrier, intermarket-spread
lineage, and arithmetic precedent. The threshold, contrarian direction, CFD
mapping, execution, and risk are QM hypotheses; no source result transfers.

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
- trade_entry: consumed month, synchronized endpoints, all 78 comparisons,
  score invariants, inclusive contrarian gate, spread/ATR/stop checks,
  equal-notional sizing, and atomic submission.
- trade_management: malformed-package repair, later-month exit, stale repair.
- trade_close: framework close helper, broker hard stops, kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-27 | approved source build | G0-approved card; governed magics `411810000`/`411810001`; one logical Q02 preset |
