# QM5_20206_xauxag-momivol — Strategy Spec

**EA ID:** QM5_20206  
**Slug:** `xauxag-momivol`  
**Strategy ID:** `FUERTES-MOMIVOL-2015_XAU_XAG_S04`  
**Source:** `FUERTES-MOMIVOL-2015`  
**Author of this spec:** Codex  
**Last revised:** 2026-08-03

## 1. Strategy Logic

The EA runs one D1 logical basket from `XAUUSD.DWX`. On the first genuine host
bar of a new broker month, it aligns 64 completed daily closes for XTI, XNG,
XAU, and XAG. It forms 63 equal-weight commodity-factor returns, estimates
separate XAU and XAG OLS residual standard deviations, and compares the same
metals' 63-D1 momentum. It buys the higher-momentum metal and shorts the other
only when the momentum winner is also the lower-IVol metal. A tie or rank
conflict consumes the month and stays flat.

Per-leg ATR risk weights target equal dollar notional inside one package
`RISK_FIXED` budget. The package is rejected when broker-rounded notional
proxies differ by more than 20%. It closes on the next month transition, after
35 days, or on an orphan, missing stop, or invalid composition.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_signal_lookback_d1` | 63 | 63 | completed momentum and OLS observations |
| `strategy_atr_period_d1` | 20 | 20 | D1 hard-stop ATR |
| `strategy_atr_sl_mult` | 3.0 | 3.0 | frozen stop multiple |
| `strategy_max_notional_mismatch_pct` | 20.0 | 20.0 | maximum rounded dollar-notional mismatch |
| `strategy_max_hold_days` | 35 | 35 | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | 1500 | XAU spread cap |
| `strategy_xag_max_spread_pts` | 3000 | 3000 | XAG spread cap |
| `strategy_deviation_points` | 20 | 20 | basket order deviation |

The four-symbol factor, 63-return OLS estimators, 63-D1 relative momentum,
strict high-momentum/low-IVol agreement, XAU/XAG carrier, equal-notional target,
monthly renewal, and no same-month retry are locked.

## 3. Symbol Universe

**Designed for:**

- `XAUUSD.DWX` — host and traded magic slot 0.
- `XAGUSD.DWX` — traded magic slot 1.
- `XTIUSD.DWX` — read-only commodity-factor member.
- `XNGUSD.DWX` — read-only commodity-factor member.

**Explicitly not for:**

- standalone XAU or XAG evaluation;
- XTI/XNG orders, because the energy symbols are factor observations only;
- index or FX carriers.

Logical symbol: `QM5_20206_XAU_XAG_MOMIVOL_D1`.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-symbol refs | synchronized D1 closes for all four inputs |
| Bar gating | `QM_IsNewBar()` on the XAU D1 host |
| Signal cadence | first tradable host bar of each broker month |

The current open D1 bar is excluded from momentum and OLS inputs.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 5-8 packages after warm-up; retire below five |
| Typical hold time | one broker month, maximum 35 calendar days |
| Expected drawdown profile | high; XAG gaps, legging, and narrow rank breadth can dominate |
| Regime preference | persistent relative metal strength aligned with low residual risk |
| Win rate target | unknown; Q02 must establish |

Realized market neutrality and portfolio decorrelation are not claimed.

## 6. Source Citation

**Source ID:** `FUERTES-MOMIVOL-2015`  
**Source type:** peer-reviewed paper  
**Pointer:** `strategy-seeds/sources/FUERTES-MOMIVOL-2015/source.md`  
**Primary DOI:** https://doi.org/10.1002/fut.21656  
**R1-R4 verdict:** PASS under the approved card.

The source uses a broad futures cross-section and traditional commodity
factors. This build uses four continuous-CFD factor proxies and two traded metal
legs, so Q02 is a strict carrier falsification. No source statistic is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per package |
| Live burn-in | not authorized | no live setfile |
| Full live | not authorized | portfolio admission required |

The EA divides fixed stop risk using each leg's relative ATR stop distance to
target equal dollar notional. It rejects more than 20% rounded mismatch. There
is no take-profit, trail, break-even, partial close, scale-in, grid, martingale,
or pyramid.

## 8. Four-Module Mapping

- **No-Trade:** exact host, locked inputs, synchronized history, factor
  variance, momentum/IVol ranks, agreement, spreads, ATR, lot/notional, magic,
  package, and attempt guards.
- **Entry:** monthly high-momentum/low-IVol agreement, equal-notional paired
  sizing, frozen hard stops, and atomic second-leg repair.
- **Management:** month transition, 35-day stale close, composition/stop
  validation, and orphan cleanup.
- **Close:** `QM_TM_ClosePosition` package exits plus broker hard stops.

## 9. Safety Boundary

This is a branch-only, backtest-risk build. No live setfile, `T_Live` change,
AutoTrading action, deploy manifest, portfolio gate change, admission artifact,
external runtime data, banned indicator, or trained model is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-03 | Initial build from approved S04 card | Q01/Q02 handoff only |

