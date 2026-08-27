# QM5_41180_xtixng-mspearman-rv - Strategy Spec

**EA ID:** QM5_41180

**Slug:** `xtixng-mspearman-rv`

**Strategy ID:** `VILLAR-SPEARMAN-XTIXNG-MRANK-RV-2026_S01`

**Source:** `VILLAR-SPEARMAN-XTIXNG-MRANK-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-27

## 1. Strategy Logic

On the first executable synchronized `XTIUSD.DWX`/`XNGUSD.DWX` D1 bar of a
new broker-calendar month, exclude the current month and select the latest
exactly timestamp-matched close pair in each of the immediately prior
thirteen consecutive broker months. Form
`s[i]=ln(XTI_close[i])-ln(XNG_close[i])`, oldest to newest.

Strict-rank `s[0..12]` from 1 through 13. Compute
`D=sum((rank[i]-(i+1))^2)` and `T=364-D`. Exact ties consume flat. `T>=104`
maps to SELL XTI / BUY XNG; `T<=-104` maps to BUY XTI / SELL XNG; interior
scores consume flat. This is exactly `abs(Spearman rho)>=2/7`, expressed with
integer arithmetic and traded contrarian. Score magnitude never changes risk.

The exposure is one atomic, opposite-side, equal-target-notional energy
package held for one broker month with one aggregate fixed-risk ceiling and
frozen per-leg ATR hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xng_symbol` | `XNGUSD.DWX` | exact companion |
| `strategy_endpoint_count` | 13 | synchronized completed months |
| `strategy_score_threshold` | 104 | inclusive absolute integer boundary |
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

- Host/traded slot 0: exact `XTIUSD.DWX`, D1, magic `411800000`.
- Companion/traded slot 1: exact `XNGUSD.DWX`, D1, magic `411800001`.
- Logical symbol: `QM5_41180_XTI_XNG_MSPEARMAN_RV_D1`.
- The two legs are one strategy package; neither is a standalone signal.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: thirteen consecutive synchronized completed broker month ends.
- Trigger: inclusive `abs(T)>=104`, traded contrarian.
- Hold: first tick in a later broker month, with forty-day stale repair.

## 5. Expected Behaviour

- Approximately 5 to 8 completed packages per full post-warm-up year; Q02
  retires below five.
- Contrarian oil/gas relative-value exposure with no index or metal leg.
- One aggregate fixed-risk package and one consumed attempt per broker month.
- Any ratio tie or interior rank score consumes flat.
- Q09 alone owns any realized portfolio-correlation conclusion.

## 6. Source Citation

Jose A. Villar and Frederick L. Joutz (2006), *The Relationship Between Crude
Oil and Natural Gas Prices*, U.S. Energy Information Administration; David J.
Ramberg and John E. Parsons (2012), *The Weak Tie Between Natural Gas and Oil
Prices*, *The Energy Journal* 33(2), DOI `10.5547/01956574.33.2.2`; C.
Spearman (1904), *The American Journal of Psychology* 15(1), DOI
`10.2307/1412159`; and pinned R Core `stats::cor` source and manual.

Canonical bounded packet:
`strategy-seeds/sources/VILLAR-SPEARMAN-XTIXNG-MRANK-RV-2026/source.md`.

The sources support a weak, time-varying oil/gas relationship and the named
rank-association arithmetic. The exact threshold, horizon, contrarian
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
- trade_entry: consumed month, synchronized endpoint selection,
  chronological ratios, strict ranks, exact D/T invariants, inclusive
  contrarian score gate, spread/quote/ATR/stop checks, equal-notional sizing,
  and atomic submission.
- trade_management: malformed-package repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-27 | approved source build | G0-approved card; governed magics `411800000`/`411800001`; one logical Q02 preset |
