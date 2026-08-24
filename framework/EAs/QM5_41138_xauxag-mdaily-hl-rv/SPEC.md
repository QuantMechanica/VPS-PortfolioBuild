# QM5_41138_xauxag-mdaily-hl-rv - Strategy Spec

**EA ID:** QM5_41138

**Slug:** `xauxag-mdaily-hl-rv`

**Strategy ID:** `SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026_S01`

**Source:** `SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-24

## 1. Strategy Logic

On the first executable synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 bar of a
new broker-calendar month, reconstruct every paired close in the immediately
completed month. Require 17 through 23 unique month-session pairs plus the
adjacent older synchronized boundary pair.

Starting at that older boundary, calculate one chronological gold-minus-silver
log-ratio return ending on every session in the completed month. Verify the
return sum against the direct endpoint. For all inclusive pairs
`0 <= i <= j < n`, form `(r[i]+r[j])/2` exactly once, producing 153 through
276 values. Sort those values and take the one central value for an odd count
or the arithmetic mean of the two central values for an even count. Fade a
strictly positive pseudomedian with SELL XAU / BUY XAG and a strictly negative
pseudomedian with BUY XAU / SELL XAG. Exact zero and malformed states consume
the month flat. The raw endpoint is diagnostic only and never gates direction.

The position is one atomic, opposite-side, equal-notional package held for one
broker month with one aggregate fixed-risk budget and frozen per-leg ATR hard
stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_history_bars_d1` | 45 | bounded synchronized D1 buffer |
| `strategy_min_month_sessions` | 17 | minimum month-ending returns |
| `strategy_max_month_sessions` | 23 | maximum month-ending returns |
| `strategy_max_pair_count` | 276 | bounded inclusive-pair array ceiling |
| `strategy_numerical_tolerance` | 1e-10 | endpoint/self-pair tolerance |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal target absolute notionals |
| `strategy_max_notional_mismatch_pct` | 20.0 | package validity cap |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_xau_max_spread_points` | 1500 | XAU entry-cost guard |
| `strategy_xag_max_spread_points` | 500 | XAG entry-cost guard |
| `strategy_deviation_points` | 20 | framework order deviation contract |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host/traded slot 0: exact `XAUUSD.DWX`, D1, magic `411380000`.
- Companion/traded slot 1: exact `XAGUSD.DWX`, D1, magic `411380001`.
- Logical symbol: `QM5_41138_XAU_XAG_MDAILY_HL_RV_D1`.
- The two legs are one strategy package; neither is a standalone signal.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: immediately completed synchronized broker-calendar month.
- Sample: adjacent older ratio close into every completed-month ratio close.
- Trigger: strict sign of the all-inclusive pairwise-average pseudomedian.
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
`strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`.

The sources support a state-dependent relative carrier and intermarket-spread
lineage. The governed method packet supplies exact inclusive-pair and median
arithmetic only. The completed-month daily horizon, pseudomedian translation,
fade direction, CFD mapping, execution, and risk are disclosed QM hypotheses;
no source result transfers.

## 7. Risk Model

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The EA targets equal absolute notionals and caps the sum
of normalized frozen-stop risk across both legs at one budget. Both news axes
and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio admission,
decorrelation claim, correlation waiver, portfolio-gate change, current-month
signal price, fitted center or scale, signal-strength sizing, external feed,
retry, scale-in, grid, martingale, pyramid, target, trail, break-even move, or
partial exit.

## Framework Alignment

- no_trade: exact symbols/period/ID/slots and locked risk/news/Friday inputs.
- trade_entry: month attempt, exact synchronized package, chronological
  returns, endpoint identity, inclusive self/cross-pair enumeration, exact
  dynamic pair count, odd/even median, contrarian sides, spread/quote/ATR/stop
  checks, equal-notional sizing, and atomic two-order submission.
- trade_management: malformed-package repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-24 | approved source build | G0-approved card; governed magics `411380000`/`411380001`; one logical Q02 preset |
