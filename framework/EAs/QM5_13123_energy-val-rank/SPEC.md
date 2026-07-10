# QM5_13123_energy-val-rank - Strategy Spec

**EA ID:** QM5_13123
**Slug:** `energy-val-rank`
**Strategy ID:** `AMP-VALUE-2013_XTI_XNG_S01`
**Source:** `AMP-VALUE-2013`
**Author:** Codex
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA implements a low-frequency paired energy value rule. On the first D1
bar of each broker month it computes each leg's value score as the log of its
mean completed D1 close at the 54 through 66 prior month boundaries divided by
its latest completed month-end close. It buys the higher-value leg and sells
the lower-value leg. Each leg receives half of fixed package risk.

The rule is pure cross-sectional long-horizon value. It is not energy momentum,
short-horizon reversal, carry, calendar seasonality, skew, ratio z-score
reversion, or the existing XNG RSI logic.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_anchor_near_months` | 54 | nearest historical value anchor |
| `strategy_anchor_far_months` | 66 | farthest historical value anchor |
| `strategy_history_bars` | 1900 | bounded D1 endpoint buffer |
| `strategy_max_boundary_gap_days` | 10 | endpoint freshness cap |
| `strategy_atr_period_d1` | 20 | hard-stop ATR period |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop multiple |
| `strategy_max_hold_days` | 35 | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | XNG spread cap |
| `strategy_deviation_points` | 20 | order deviation |

## 3. Symbol Universe

- Logical basket: `QM5_13123_ENERGY_VALUE_D1`.
- Host/traded slot 0: `XTIUSD.DWX`.
- Traded slot 1: `XNGUSD.DWX`.
- Standalone leg evaluation is invalid; Q02 must dispatch the logical basket.

## 4. Timeframe

- Base timeframe: D1.
- Decision cadence: first tradable D1 bar of each broker month.
- Formation: latest completed month-end close and 13 synchronized endpoints
  spanning 54 through 66 completed months.
- Holding period: until next month transition, maximum 35 days.

## 5. Expected Behaviour

- Expected packages/year: approximately 12 when both histories are valid.
- Typical hold: one broker month.
- Regime preference: long-horizon relative mispricing between crude oil and
  natural gas that converges without requiring a directional energy view.
- Risk: high because of XNG gaps, legging, the two-asset carrier, and CFD close
  proxies for commodity spot prices.

## 6. Source Citation

Asness, Moskowitz, and Pedersen (2013), "Value and Momentum Everywhere",
*Journal of Finance* 68(3), 929-985, DOI https://doi.org/10.1111/jofi.12021,
plus the article's Internet Appendix, DOI https://doi.org/10.1111/jofi.12025.

The source's diversified 27-commodity results are not imported into this
two-CFD carrier. The EA preserves the long-horizon commodity value definition
and cross-sectional dollar-neutral direction, while using completed D1 CFD
closes as an explicitly testable spot proxy.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest Q02+ | `RISK_FIXED` | 1000 per package, equal split |
| Live | not authorized | no live setfile or manifest |

Each leg receives a frozen `ATR(20) * 3.5` broker-side stop. The manager closes
orphans, invalid composition, month-old packages, and positions beyond 35 days.
Friday close is disabled only for the source-aligned monthly hold. No T_Live,
AutoTrading, deploy manifest, portfolio gate, or admission file is touched.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | initial approved-card build | strict compile/build PASS; logical-basket Q02 queued as work item `f50a1355-50ff-4637-a4f8-c482adc5abee` |
