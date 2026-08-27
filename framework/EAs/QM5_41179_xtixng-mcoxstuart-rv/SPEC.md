# QM5_41179_xtixng-mcoxstuart-rv - Strategy Spec

**EA ID:** QM5_41179

**Slug:** `xtixng-mcoxstuart-rv`

**Strategy ID:** `VILLAR-COX-STUART-XTIXNG-MPAIRSIGN-RV-2026_S01`

**Source:** `VILLAR-COX-STUART-XTIXNG-MPAIRSIGN-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-27

## 1. Strategy Logic

On the first executable synchronized `XTIUSD.DWX`/`XNGUSD.DWX` D1 bar of a
new broker-calendar month, exclude the current month and select the latest
exactly timestamp-matched close pair in each of the immediately prior fourteen
consecutive broker months. Form
`s[i]=ln(XTI_close[i])-ln(XNG_close[i])`, oldest to newest.

Compare the two sample halves through seven fixed Cox-Stuart differences
`d[i]=s[i+7]-s[i]`, `i=0..6`. Any exact tie consumes the month flat. At least
five positive differences map to SELL XTI / BUY XNG; at least five negative
differences map to BUY XTI / SELL XNG; a 4/3 split is flat. Difference
magnitudes never change direction or risk.

The exposure is one atomic, opposite-side, equal-notional package held for
one broker month with one aggregate fixed-risk ceiling and frozen per-leg ATR
hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xng_symbol` | `XNGUSD.DWX` | exact companion |
| `strategy_endpoint_count` | 14 | synchronized completed months |
| `strategy_pair_count` | 7 | exact half-sample pairs |
| `strategy_signs_required` | 5 | strict directional threshold |
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

- Host/traded slot 0: exact `XTIUSD.DWX`, D1, magic `411790000`.
- Companion/traded slot 1: exact `XNGUSD.DWX`, D1, magic `411790001`.
- Logical symbol: `QM5_41179_XTI_XNG_MCOXSTUART_RV_D1`.
- The two legs are one strategy package; neither is a standalone signal.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: fourteen consecutive synchronized completed broker month ends.
- Trigger: at least five of seven strict lag-seven signs, traded contrarian.
- Hold: first tick in a later broker month, with a forty-day stale repair.

## 5. Expected Behaviour

- Approximately 5 to 8 completed packages per full post-warm-up year; Q02
  retires below five.
- Symmetric contrarian oil/gas relative-value exposure.
- One aggregate fixed-risk package and one consumed attempt per broker month.
- Any tie and every 4/3 split consume flat.
- Q09 alone owns any realized portfolio-correlation conclusion.

## 6. Source Citation

Jose A. Villar and Frederick L. Joutz (2006), *The Relationship Between Crude
Oil and Natural Gas Prices*, U.S. EIA; David J. Ramberg and John E. Parsons
(2012), "The Weak Tie Between Natural Gas and Oil Prices," *The Energy
Journal* 33(2), DOI `10.5547/01956574.33.2.2`; D. R. Cox and Alan Stuart
(1955), *Biometrika* 42(1-2), 80-95, DOI `10.1093/biomet/42.1-2.80`; and the
official NIST Dataplot Cox Stuart Test.

Canonical bounded packet:
`strategy-seeds/sources/VILLAR-COX-STUART-XTIXNG-MPAIRSIGN-RV-2026/source.md`.

The sources support the weak, state-dependent oil/gas carrier, binding adverse
evidence, and half-sample paired-sign method. The exact
5-of-7 threshold, horizon, contrarian direction, CFD mapping, execution, and
risk are disclosed QM hypotheses; no source result transfers.

## 7. Risk Model

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg begins at half of the aggregate frozen-stop
risk allowance; balancing may only reduce the larger target notional. The EA
requires no more than 20% realized notional mismatch. Both news axes and
Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deploy or live manifest, portfolio admission,
correlation waiver, portfolio-gate change, current-month signal price,
alternate pairing, signal-strength sizing, external feed, retry, scale-in,
grid, martingale, pyramid, target, trail, break-even move, or partial exit.

## Framework Alignment

- no_trade: exact symbols/period/ID/slots and locked risk/news/Friday inputs.
- trade_entry: consumed month, synchronized endpoint selection,
  chronological ratios, seven paired differences, tie rejection, 5-of-7
  contrarian sides, spread/quote/ATR/stop checks, equal-notional sizing, and
  atomic submission.
- trade_management: malformed-package repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-27 | approved source build | G0-approved card; governed magics `411790000`/`411790001`; one logical Q02 preset |
