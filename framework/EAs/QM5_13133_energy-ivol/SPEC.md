# QM5_13133_energy-ivol - Strategy Spec

**EA ID:** QM5_13133
**Slug:** `energy-ivol`
**Strategy ID:** `FUERTES-MOMIVOL-2015_XTI_XNG_S02`
**Source:** `FUERTES-MOMIVOL-2015`
**Author of this spec:** Codex
**Last revised:** 2026-07-11

## 1. Strategy Logic

The EA runs one D1 logical basket from `XTIUSD.DWX`. On the first host bar of a
new broker month, it computes 252 synchronized daily returns for XTI, XNG, XAU,
and XAG, forms their equal-weight commodity factor, and estimates separate XTI
and XNG OLS residual standard deviations. It buys the lower-IVol energy leg and
shorts the higher-IVol leg.

Per-leg ATR risk weights target equal dollar notional after stop translation.
The package is rejected when broker-rounded notional proxies differ by more
than 20%, and it closes on the next month transition, after 35 days, or on an
orphan or invalid composition.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_ivol_lookback_d1` | 252 | 21, 63, 126, 252 | completed daily OLS observations |
| `strategy_atr_period_d1` | 20 | 14-30 | D1 hard-stop ATR |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | frozen stop multiple |
| `strategy_max_notional_mismatch_pct` | 20.0 | 10-30 | maximum post-rounding dollar-notional mismatch |
| `strategy_max_hold_days` | 35 | locked | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | 1000-2500 | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | 2000-4500 | XNG spread cap |
| `strategy_deviation_points` | 20 | 10-50 | basket order deviation |

The four-symbol equal-weight factor, OLS residual-volatility rank, low-IVol
direction, equal-notional target, monthly renewal, and no same-month re-entry
are locked.

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` - WTI crude-oil CFD, host and traded magic slot 0.
- `XNGUSD.DWX` - natural-gas CFD, traded magic slot 1.
- `XAUUSD.DWX` - read-only commodity-factor member.
- `XAGUSD.DWX` - read-only commodity-factor member.

**Explicitly NOT for:**

- Standalone metal orders - XAU/XAG are factor observations only.
- Indices and FX - the approved hypothesis is a relative energy carrier.

Logical symbol: `QM5_13133_XTI_XNG_IVOL_D1`.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none; all four inputs use synchronized D1 closes |
| Bar gating | `QM_IsNewBar()` on the XTI D1 host |
| Signal cadence | first tradable host bar of each broker month |

The current open D1 bar is excluded from all OLS inputs.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 12 package entries after warm-up; retire below five |
| Typical hold time | one broker month, maximum 35 calendar days |
| Expected drawdown profile | high; XNG gaps, legging, and factor translation can dominate |
| Regime preference | persistent cross-sectional energy residual-risk dispersion |
| Win rate target (qualitative) | unknown; Q02 must establish |

The carrier targets equal dollar notional within a 20% lot-rounding tolerance.
Realized market neutrality and portfolio decorrelation are not claimed.

## 6. Source Citation

**Source ID:** `FUERTES-MOMIVOL-2015`
**Source type:** peer-reviewed paper
**Pointer:** `strategy-seeds/sources/FUERTES-MOMIVOL-2015/source.md`
**Primary DOI:** https://doi.org/10.1002/fut.21656
**R1-R4 verdict (Q00):** all PASS; see
`artifacts/cards_approved/QM5_13133_energy-ivol.md`.

The source uses a 27-future cross-section and traditional commodity factors.
This implementation uses four continuous CFD factor proxies and two traded
energy legs, so Q02 is a strict carrier falsification and no source statistic
is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per package |
| Live burn-in (Q13) | not authorized | no live setfile |
| Full live (post-Q13 PASS) | not authorized | portfolio allocation required |

The EA splits fixed stop risk in proportion to each leg's relative ATR stop,
which targets equal dollar notional. It rejects rounded lots with more than 20%
notional mismatch. There is no TP, trail, break-even, partial close, scale-in,
grid, martingale, or pyramiding.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-11 | Initial build from approved card | task a480301d-56c8-489e-bb2f-3594eacecec5 |

## 8. Four-Module Mapping

- **No-Trade:** exact host, estimator, synchronized history, factor variance,
  OLS residual, spread, ATR, lot, notional, magic, package, and attempt guards.
- **Entry:** monthly low/high IVol rank, equal-notional paired sizing, and
  frozen hard stops.
- **Management:** month transition, 35-day stale close, deal-history restart
  guard, composition validation, and orphan cleanup.
- **Close:** `QM_TM_ClosePosition` package exits plus broker hard stops.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, admission artifact, external runtime data, banned indicator, or ML
is authorized.
