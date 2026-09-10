# QM5_41416_xauxag-wrelvote-flip-fade — Strategy Spec

- EA ID: QM5_41416
- Slug: `xauxag-wrelvote-flip-fade`
- Strategy ID: `FMR-CME-XAUXAG-WRELVOTE-FLIP-FADE-20260910_S01`
- Source: `FMR-CME-XAUXAG-WRELVOTE-FLIP-FADE-20260910`
- Author: Codex
**Last revised:** 2026-09-10

## 1. Strategy Logic

At the first tradable `XAUUSD.DWX` D1 bar of a new broker week, reconstruct
the final synchronized XAU/XAG close pairs from the five immediately preceding
consecutive weeks. Each week must contain three to five synchronized sessions.
Form four adjacent XAU-minus-XAG weekly log returns. Compare the strict sign
majority in the older `[d0,d1,d2]` window with the newer `[d1,d2,d3]` window.
Trade only when that majority reverses, fading the new relative winner for
one week. A tie, invalid endpoint, no flip, or late attachment consumes flat.

## 2. Parameters

| Parameter | Value |
|---|---:|
| `strategy_history_bars_d1` | 50 |
| `strategy_min_sessions_per_week` | 3 |
| `strategy_max_sessions_per_week` | 5 |
| `strategy_signal_epsilon` | 1e-10 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_notional_ratio` | 1.0 |
| `strategy_max_notional_mismatch_pct` | 20.0 |
| `strategy_max_hold_days` | 10 |
| `strategy_host_max_spread_points` | 1500 |
| `strategy_companion_max_spread_points` | 500 |
| `strategy_deviation_points` | 20 |

All strategy parameters are locked for Q02.

## 3. Symbol Universe

- Host: exact `XAUUSD.DWX`, D1, slot 0.
- Companion: exact `XAGUSD.DWX`, D1, slot 1.
- Logical symbol: `QM5_41416_XAU_XAG_WRELVOTE_FLIP_FADE_D1`.
- One equal-notional, opposed-leg research package; neither leg is standalone.

## 4. Lifecycle And Risk

The package exits on the first tick of the next broker week, with a ten-day
stale repair. Each leg has a frozen `3.5*ATR(20,D1)` hard stop. Q02 uses one
aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and weight 1. Both news
axes and framework Friday close are off. Atomic orphan and malformed-package
repair precedes entry gates.

## 5. Source And Non-Duplicate Boundary

Fuertes, Miffre, and Rallis (*Journal of Banking & Finance*, 2010, DOI
`10.1016/j.jbankfin.2010.04.009`) support commodity momentum lineage. Yang,
Goncu, and Pantelous support commodity reversal lineage. CME defines the
gold/silver ratio and intermarket-spread carrier. The overlapping weekly
majority flip is an untested QM translation. `QM5_41414` follows the same
newly flipped majority. The energy-carrier
analogue is economically different, while the nearest XAU/XAG sibling uses
exact three-return alternation rather than four returns and two overlapping
votes.

## 6. Safety Boundary

No live/demo/shadow/stress/optimization setfile, manual backtest, AutoTrading,
`T_Live`, deploy/live manifest, portfolio-gate change, portfolio admission,
correlation waiver, external feed, retry, scale-in, grid, pyramid, target,
trail, break-even move, or partial exit is authorized.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-09-10 | approved build identity |

