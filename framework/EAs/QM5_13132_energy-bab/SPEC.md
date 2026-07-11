# QM5_13132_energy-bab - Strategy Spec

**EA ID:** QM5_13132
**Slug:** `energy-bab`
**Strategy ID:** `FRAZZINI-BAB-2014_XTI_XNG_S01`
**Source:** `FRAZZINI-BAB-2014`
**Author of this spec:** Codex
**Last revised:** 2026-07-11

## 1. Strategy Logic

The EA runs one D1 logical basket from `XTIUSD.DWX`. On the first host bar of
a new broker month, it forms an inverse-volatility XTI/XNG benchmark and
estimates each leg's beta from 252 completed daily observations using the
current benchmark return plus five lags. It shrinks both betas halfway toward
one, buys the lower-beta leg, shorts the higher-beta leg, and targets equal
beta exposure through inverse-beta notional scaling.

Both legs receive frozen ATR hard stops. The package closes at the next month
transition, after 35 days, or immediately on an orphan or invalid composition.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_beta_observations` | 252 | locked | completed daily regression observations |
| `strategy_dimson_lags` | 5 | locked | lagged benchmark returns in each beta regression |
| `strategy_beta_shrink_weight` | 0.5 | locked | raw-beta weight; remainder is beta one |
| `strategy_history_bars` | 320 | 300-380 | bounded retrieval and warm-up buffer |
| `strategy_min_beta` | 0.10 | 0.05-0.10 | fail-closed floor before inverse-beta sizing |
| `strategy_max_beta_mismatch_pct` | 20.0 | 10-30 | maximum post-rounding beta-exposure mismatch |
| `strategy_atr_period_d1` | 20 | 14-30 | D1 hard-stop ATR |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | frozen stop multiple |
| `strategy_max_hold_days` | 35 | locked | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | 1000-2500 | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | 2000-4500 | XNG spread cap |
| `strategy_deviation_points` | 20 | 10-50 | basket order deviation |

The one-year observations, five lags, 0.5 shrinkage, equal-risk benchmark,
low-beta direction, inverse-beta notional target, monthly renewal, and no
same-month re-entry are locked.

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` - WTI crude-oil CFD, host and traded magic slot 0.
- `XNGUSD.DWX` - natural-gas CFD, traded magic slot 1.

**Explicitly NOT for:**

- XAU/XAG - existing ratio and precious-metal sleeves use different economic
  mechanics.
- Indices and FX - active BAB and low-beta relative-value builds already cover
  those universes.

Logical symbol: `QM5_13132_XTI_XNG_BAB_D1`.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none; both legs use synchronized D1 bars |
| Bar gating | `QM_IsNewBar()` on the XTI D1 host |
| Signal cadence | first tradable host bar of each broker month |

The current open D1 bar is excluded from all beta inputs.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 12 package entries after warm-up; retire below five |
| Typical hold time | one broker month, maximum 35 calendar days |
| Expected drawdown profile | high; XNG gaps, funding shocks, and legging can dominate |
| Regime preference | persistent cross-sectional energy beta dispersion |
| Win rate target (qualitative) | unknown; Q02 must establish |

The carrier is beta-matched by construction within a 20% lot-rounding
tolerance. Dollar neutrality and portfolio decorrelation are not claimed.

## 6. Source Citation

**Source ID:** `FRAZZINI-BAB-2014`
**Source type:** peer-reviewed paper / official NBER working paper
**Pointer:** `strategy-seeds/sources/FRAZZINI-BAB-2014/source.md`
**Primary DOI:** https://doi.org/10.1016/j.jfineco.2013.10.005
**R1-R4 verdict (Q00):** all PASS; see
`artifacts/cards_approved/QM5_13132_energy-bab.md`.

The source uses 24 commodity futures and excess returns. This implementation
uses two continuous CFDs and raw close returns, so Q02 is a strict carrier
falsification and no source performance number is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per package |
| Live burn-in (Q13) | not authorized | no live setfile |
| Full live (post-Q13 PASS) | not authorized | portfolio allocation required |

The EA splits fixed stop risk in proportion to relative ATR divided by beta,
which targets inverse-beta notional exposure under the two frozen stops. It
rejects broker-rounded lots whose beta exposure differs by more than 20%.
There is no TP, trail, break-even, partial close, scale-in, grid, martingale,
or pyramiding.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-11 | Initial build from approved card | mission-directed Q01 build |

## 8. Four-Module Mapping

- **No-Trade:** exact host, locked estimator, synchronized history, matrix,
  beta, spread, ATR, lot, mismatch, magic, package, and monthly-attempt guards.
- **Entry:** equal-risk benchmark, two Dimson regressions, beta shrinkage,
  low/high rank, inverse-beta paired sizing, and frozen hard stops.
- **Management:** month transition, 35-day stale close, deal-history restart
  guard, composition validation, and orphan cleanup.
- **Close:** `QM_TM_ClosePosition` for package exits plus broker hard stops.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, admission artifact, external runtime data, banned indicator, or
ML is authorized.
