# QM5_13121_energy-tfmom - Strategy Spec

**EA ID:** QM5_13121
**Slug:** `energy-tfmom`
**Strategy ID:** `CLARE-TFMOM-2014_XTI_XNG_S01`
**Source:** `CLARE-TFMOM-2014`
**Author:** Codex
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA implements a low-frequency paired energy momentum rule with absolute
trend confirmation. On the first D1 bar of each broker month it ranks XTI and
XNG by synchronized 12-completed-month returns. It trades only when the winner
is above its own seven-completed-month close mean and the loser is below its
mean. Fixed package risk is divided with 60-D1 inverse-volatility weights.

The rule is not raw XTI/XNG momentum (`QM5_12733`), 12/18 momentum-reversal
(`QM5_13120`), skew, carry, ratio reversion, or `QM5_12567` commodity RSI.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_momentum_months` | 12 | completed-month relative rank |
| `strategy_trend_months` | 7 | per-leg trend mean |
| `strategy_volatility_days` | 60 | inverse-volatility weight window |
| `strategy_history_bars` | 450 | bounded D1 endpoint buffer |
| `strategy_max_boundary_gap_days` | 10 | endpoint freshness cap |
| `strategy_atr_period_d1` | 20 | hard-stop ATR period |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop multiple |
| `strategy_max_hold_days` | 35 | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | XNG spread cap |
| `strategy_deviation_points` | 20 | order deviation |

## 3. Symbol Universe

- Logical basket: `QM5_13121_ENERGY_TFMOM_D1`.
- Host/traded slot 0: `XTIUSD.DWX`.
- Traded slot 1: `XNGUSD.DWX`.
- Standalone leg evaluation is invalid; Q02 must dispatch the logical basket.

## 4. Timeframe

- Base timeframe: D1.
- Decision cadence: first tradable D1 bar of each broker month.
- Formation: completed month-end endpoints and 60 completed daily returns.
- Holding period: until next month transition, maximum 35 days.

## 5. Expected Behaviour

- Expected packages/year: approximately 5-9; retire below 5/year at Q02.
- Typical hold: one broker month.
- Regime preference: persistent cross-energy leadership confirmed by absolute
  trend divergence.
- Risk: high because of XNG gaps, legging, and the narrow two-asset carrier.

## 6. Source Citation

Clare, Seaton, Smith, and Thomas (2014), "Trend following, risk parity and
momentum in commodity futures", *International Review of Financial Analysis*
31, 1-12, DOI https://doi.org/10.1016/j.irfa.2013.10.001.

The source's 28-future results are not imported into this two-CFD carrier.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest Q02+ | `RISK_FIXED` | 1000 per package, inverse-vol split |
| Live | not authorized | no live setfile or manifest |

Each leg receives a frozen `ATR(20) * 3.5` broker-side stop. The manager closes
orphans, invalid composition, month-old packages, and positions beyond 35 days.
Friday close is disabled only for the source-aligned monthly hold. No T_Live,
AutoTrading, deploy manifest, portfolio gate, or admission file is touched.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | initial approved-card build | strict compile/build PASS; logical-basket Q02 queued as work item `3dc3cec3-3691-4bdd-9f67-fa6b245be574` |
