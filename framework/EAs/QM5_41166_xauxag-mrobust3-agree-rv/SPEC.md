# QM5_41166_xauxag-mrobust3-agree-rv - Strategy Spec

**EA ID:** QM5_41166

**Slug:** `xauxag-mrobust3-agree-rv`

**Strategy ID:** `SCHWEIKERT-THEILSEN-KOENKER-SIEGEL-CME-XAUXAG-MROBUST3-AGREE-RV-2026_S01`

**Source:** `SCHWEIKERT-THEILSEN-KOENKER-SIEGEL-CME-XAUXAG-MROBUST3-AGREE-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-26

## 1. Strategy Logic

On the first executable synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 bar of a
new broker-calendar month, exclude the current month and select the latest
exactly timestamp-matched close pair in each of the immediately prior
thirteen consecutive broker months. Form
`s[i]=ln(XAU_close[i])-ln(XAG_close[i])`, oldest to newest.

Compute three complete robust slopes over that same path:

1. Theil-Sen: enumerate all 78 forward pair slopes and average sorted indexes
   38 and 39.
2. LAD: evaluate every pair slope as a breakpoint, profile sorted residual
   index 6 as intercept, minimize the chronological thirteen-term absolute
   loss, retain candidates within `1e-12` of the minimum, and take their
   ordinary median.
3. Repeated median: calculate twelve forward-oriented slopes inside each of
   thirteen endpoint pivots, average sorted indexes 5 and 6 inside each
   pivot, and take sorted pivot-median index 6.

Fade only one unanimous strict sign. Three positive slopes map to SELL XAU /
BUY XAG; three negative slopes map to BUY XAU / SELL XAG. Any zero,
disagreement, invalid count, or nonfinite value consumes the month flat.

The exposure is one atomic, opposite-side, equal-notional package held for
one broker month with one aggregate fixed-risk ceiling and frozen per-leg ATR
hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_month_end_count` | 13 | synchronized completed months |
| `strategy_history_bars_d1` | 500 | bounded synchronized D1 scan per symbol |
| `strategy_entry_window_minutes` | 180 | first-month-bar execution window |
| `strategy_max_endpoint_gap_days` | 10 | prior-month freshness guard |
| `strategy_loss_tie_tolerance` | 1e-12 | fixed LAD equality convention |
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

- Host/traded slot 0: exact `XAUUSD.DWX`, D1, magic `411660000`.
- Companion/traded slot 1: exact `XAGUSD.DWX`, D1, magic `411660001`.
- Logical symbol: `QM5_41166_XAU_XAG_MROBUST3_AGREE_RV_D1`.
- The two legs are one strategy package; neither is a standalone signal.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: thirteen consecutive synchronized completed broker month ends.
- Trigger: unanimous strict sign of three exact robust slopes, traded
  contrarian.
- Hold: first tick in a later broker month, with a forty-day stale repair.

## 5. Expected Behaviour

- Approximately 5 to 12 completed packages per full post-warm-up year; Q02
  retires below five.
- Symmetric contrarian gold/silver relative-value exposure.
- One aggregate fixed-risk package and one consumed attempt per broker month.
- Both locked disagreement paths consume flat; exact positive and negative
  lines open the corresponding contrarian baskets.
- Q09 alone owns any realized portfolio-correlation conclusion.

## 6. Source Citation

Karsten Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`; Andrew F. Siegel (1982), *Biometrika*
69(1), 242-244, DOI `10.1093/biomet/69.1.242`; CME Group, "Gold & Silver
Ratio Spread"; governed exact Theil-Sen and Koenker-Bassett LAD method
packets.

Canonical bounded packet:
`strategy-seeds/sources/SCHWEIKERT-THEILSEN-KOENKER-SIEGEL-CME-XAUXAG-MROBUST3-AGREE-RV-2026/source.md`.

The sources support the state-dependent relative carrier, robust statistical
lineage, and exchange intermarket-spread lineage. The exact unanimous
conjunction, horizon, contrarian direction, CFD mapping, execution, and risk
are disclosed QM hypotheses; no source result transfers.

## 7. Risk Model

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg begins at half of the aggregate frozen-stop
risk allowance; balancing may only reduce the larger target notional. The EA
requires no more than 20% realized notional mismatch. Both news axes and
Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deploy or live manifest, portfolio admission,
correlation waiver, portfolio-gate change, current-month signal price,
majority fallback, signal-strength sizing, external feed, retry, scale-in,
grid, martingale, pyramid, target, trail, break-even move, or partial exit.

## Framework Alignment

- no_trade: exact symbols/period/ID/slots and locked risk/news/Friday inputs.
- trade_entry: consumed month, synchronized endpoint selection,
  chronological ratios, all three estimators, strict consensus, contrarian
  sides, spread/quote/ATR/stop checks, equal-notional sizing, and atomic
  submission.
- trade_management: malformed-package repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-26 | approved source build | G0-approved card; governed magics `411660000`/`411660001`; one logical Q02 preset |
