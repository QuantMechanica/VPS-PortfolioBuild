# QM5_41248_xauxag-mpettitt-rv - Strategy Spec

**EA ID:** QM5_41248

**Slug:** `xauxag-mpettitt-rv`

**Strategy ID:** `SCHWEIKERT-PETTITT-CME-XAUXAG-MSHIFT-RV-2026_S01`

**Source:** `SCHWEIKERT-PETTITT-CME-XAUXAG-MSHIFT-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-31

## 1. Strategy Logic

On the first executable synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 bar of a
new broker-calendar month, exclude the current month and select the latest
exactly timestamp-matched close pair in each of the immediately prior
thirteen consecutive broker months. Form
`s[i]=ln(XAU_close[i])-ln(XAG_close[i])`, oldest to newest.

Strict-rank `s[0..12]` from 1 through 13. For `k=1..12`, compute
`U[k]=2*sum(rank[0..k-1])-14*k`. Exact ratio ties consume flat. Require one
and only one split attaining `Ustar=max(abs(U[k]))`, and require `K=4..9`.
Negative `U[K]` means the later ratio is higher and maps to SELL XAU / BUY
XAG; positive `U[K]` maps to BUY XAU / SELL XAG. A tied maximum or edge split
consumes flat. Statistic magnitude never changes risk.

The exposure is one atomic, opposite-side, equal-notional package held for
one broker month with one aggregate fixed-risk ceiling and frozen per-leg ATR
hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_endpoint_count` | 13 | synchronized completed months |
| `strategy_min_change_index` | 4 | first allowed Pettitt split |
| `strategy_max_change_index` | 9 | last allowed Pettitt split |
| `strategy_history_bars_d1` | 900 | bounded synchronized D1 scan per symbol |
| `strategy_entry_window_minutes` | 180 | first-month-bar execution window |
| `strategy_max_endpoint_gap_days` | 10 | prior-month freshness guard |
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

- Host/traded slot 0: exact `XAUUSD.DWX`, D1, magic `412480000`.
- Companion/traded slot 1: exact `XAGUSD.DWX`, D1, magic `412480001`.
- Logical symbol: `QM5_41248_XAU_XAG_MPETTITT_RV_D1`.
- The two legs are one strategy package; neither is a standalone signal.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: thirteen consecutive synchronized completed broker month ends.
- Trigger: one unique Pettitt maximum at a central `K=4..9`, traded
  contrarian to the signed ratio shift.
- Hold: first tick in a later broker month, with forty-day stale repair.

## 5. Expected Behaviour

- Approximately 4 to 8 completed packages per full post-warm-up year; Q02
  retires below four.
- Symmetric contrarian gold/silver relative-value exposure.
- One aggregate fixed-risk package and one consumed attempt per broker month.
- Any ratio tie, tied maximum, or edge split consumes flat.
- Q09 alone owns any realized portfolio-correlation conclusion.

## 6. Source Citation

Karsten Schweikert (2018), *Are gold and silver cointegrated? New evidence
from quantile cointegrating regressions*, *Journal of Banking & Finance* 88,
DOI `10.1016/j.jbankfin.2017.11.010`; CME Group, *Gold & Silver Ratio
Spread*; A. N. Pettitt (1979), *Applied Statistics* 28(2), DOI
`10.2307/2346729`; and pinned CRAN `trend` 1.1.7 method files.

Canonical bounded packet:
`strategy-seeds/sources/SCHWEIKERT-PETTITT-CME-XAUXAG-MSHIFT-RV-2026/source.md`.

The sources support a state-dependent gold/silver relation, an official
intermarket-spread carrier, and the exact rank-sum change-point method. The
horizon, central band, contrarian direction, CFD mapping, execution, and risk
are disclosed QM hypotheses; no source result transfers.

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
- trade_entry: consumed month, synchronized endpoint selection,
  chronological ratios, strict ranks, exact Pettitt path invariants, unique
  central maximum, contrarian side, spread/quote/ATR/stop checks,
  equal-notional sizing, and atomic submission.
- trade_management: magic-scoped persisted signal direction, malformed-package
  repair (including reversed sides after restart), later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-31 | approved source build | G0-approved card; governed magics `412480000`/`412480001`; one logical Q02 preset |
