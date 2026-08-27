# QM5_41175_xtixng-mpettitt-rv - Strategy Spec

**EA ID:** QM5_41175

**Slug:** `xtixng-mpettitt-rv`

**Strategy ID:** `VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026_S01`

**Source:** `VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-27

## 1. Strategy Logic

On the first executable synchronized `XTIUSD.DWX`/`XNGUSD.DWX` D1 bar of a
new broker-calendar month, exclude the current month and select the latest
exactly timestamp-matched close pair in each of the immediately prior
thirteen consecutive broker months. Form
`s[i]=ln(XTI_close[i])-ln(XNG_close[i])`, oldest to newest.

Strict-rank `s[0..12]` from 1 through 13. For `k=1..12`, compute
`U[k]=2*sum(rank[0..k-1])-14*k`. Exact ratio ties consume flat. Require one
and only one split attaining `Ustar=max(abs(U[k]))`, and require `K=4..9`.
Negative `U[K]` means the later ratio is higher and maps to SELL XTI / BUY
XNG; positive `U[K]` maps to BUY XTI / SELL XNG. A tied maximum or edge split
consumes flat. Statistic magnitude never changes risk.

The exposure is one atomic, opposite-side, equal-notional package held for
one broker month with one aggregate fixed-risk ceiling and frozen per-leg ATR
hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xng_symbol` | `XNGUSD.DWX` | exact companion |
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
| `strategy_xti_max_spread_points` | 1500 | XTI entry-cost guard |
| `strategy_xng_max_spread_points` | 3000 | XNG entry-cost guard |
| `strategy_deviation_points` | 20 | framework order deviation contract |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host/traded slot 0: exact `XTIUSD.DWX`, D1, magic `411750000`.
- Companion/traded slot 1: exact `XNGUSD.DWX`, D1, magic `411750001`.
- Logical symbol: `QM5_41175_XTI_XNG_MPETTITT_RV_D1`.
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
- Symmetric contrarian oil/gas relative-value exposure.
- One aggregate fixed-risk package and one consumed attempt per broker month.
- Any ratio tie, tied maximum, or edge split consumes flat.
- Q09 alone owns any realized portfolio-correlation conclusion.

## 6. Source Citation

Villar and Joutz (2006), U.S. EIA, *The Relationship Between Crude Oil and
Natural Gas Prices*; Ramberg and Parsons (2012), *The Energy Journal* 33(2),
DOI `10.5547/01956574.33.2.2`; A. N. Pettitt (1979), *Applied Statistics*
28(2), DOI `10.2307/2346729`; and pinned CRAN `trend` 1.1.7 method files.

Canonical bounded packet:
`strategy-seeds/sources/VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026/source.md`.

The sources support a weak state-dependent energy relation and the exact
rank-sum change-point method. The horizon, central band, contrarian direction,
CFD mapping, execution, and risk are disclosed QM hypotheses; no source
result transfers.

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
| v0 | 2026-08-27 | approved source build | G0-approved card; governed magics `411750000`/`411750001`; one logical Q02 preset |
