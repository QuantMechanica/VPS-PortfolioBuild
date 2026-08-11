# QM5_20279_wti-expw-mom - Strategy Spec

**EA ID:** QM5_20279
**Slug:** `wti-expw-mom`
**Source:** `MOP-TSMOM-2012_XTI_EXPW12_S27`
**Card:** `strategy-seeds/cards/approved/QM5_20279_wti-expw-mom_card.md`
**Last revised:** 2026-08-11

## 1. Strategy Logic

On the first processed `XTIUSD.DWX` D1 bar of a genuine broker-month
transition, reconstruct thirteen consecutive completed broker-month-end closes
in chronological order. Form twelve adjacent monthly log returns. Give the
newest return age zero and each older return one additional completed month of
age. Apply the fixed weight `2^(-age/3.0)`, normalize by the twelve-weight
total, buy when the result is positive, sell when it is negative, and consume
the month flat when it is exactly zero or invalid.

Close the prior package at the next month boundary before considering the new
month. Maintain one persisted attempt per broker month, one position, one
frozen ATR hard stop, and no take-profit. This is a fixed exponential-recency
monthly-return estimator, not a sorted-return statistic, linear weight,
endpoint return, horizon vote, price regression, calendar rule, or oscillator.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_return_months` | 12 | 12 | Adjacent completed monthly returns |
| `strategy_half_life_months` | 3.0 | 3.0 | Fixed base-two recency half-life |
| `strategy_history_bars_d1` | 800 | 800 | Bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | 20 | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | 3.5 | 3.5 | Frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | 1500 | WTI entry spread ceiling |

No baseline parameter sweep is authorized.

## 3. Symbol Universe

- `XTIUSD.DWX` only.
- Magic slot 0, intended magic `202790000`.
- Single-position, single-symbol EA.
- Runtime uses only native MT5 price, calendar, ATR, quote, position, deal,
  and framework state.
- It explicitly does not trade XAU, XAG, XNG, indices, FX, or external futures
  curves; the purpose is a direct WTI energy carrier.

## 4. Timeframe

- Host timeframe: D1 only.
- Formation endpoints: completed broker-month closes reconstructed from D1
  bars; no current-month endpoint is allowed.
- Decision/renewal clock: first processed D1 bar of each genuine new broker
  month.

## 5. Expected Behaviour

- Approximately eleven to twelve completed monthly packages per full post-
  warm-up year; Q02 retires the EA below five.
- Symmetric long/short WTI exposure driven by the sign of the normalized
  base-two exponential mean of twelve completed monthly returns.
- All twelve return magnitudes contribute. The newest weight is one and the
  weight halves every three months. Signal magnitude never scales risk.
- Prior package closes before any replacement entry, even when direction is
  unchanged.
- Friday close and news axes are disabled for the full-month native-price
  package. A forty-day stale exit and broker hard stop remain binding.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The complete-read parent packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the bounded extraction is
`strategy-seeds/sources/MOP-WTI-EXPW-2026/source.md`. Exponential recency
weighting and the three-month half-life are transparent QM hypotheses, not
source performance claims.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Q02-Q10 backtest | `RISK_FIXED` | 1000 |
| Live | not authorized | n/a |

The backtest setfile locks `RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`. Each
entry receives one frozen `3.5 * ATR(20,D1)` broker hard stop. No profit target,
trail, break-even, partial close, scale-in, grid, martingale, or pyramid is
allowed.

## 8. Framework Alignment

- **No-Trade:** exact EA/symbol/D1/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap state guards.
- **Trade Entry:** persist month attempt, reconstruct endpoints, compute twelve
  chronological returns, apply exact ages and `2^(-age/3.0)` weights, normalize,
  then validate spread, quote, ATR, stop, sizing, and place one order.
- **Trade Management:** repair malformed owned state and close prior-month or
  forty-day-stale exposure before entry-only gates.
- **Trade Close:** framework close helper, frozen broker stop, and kill switch.

## 9. Non-Duplicate Boundary

The pre-allocation checker found no exact or fuzzy identity across 4,344
registry rows and 455 cards. `QM5_20278` uses arithmetic weights `1..12`; this
rule uses a constant exponential decay rate with a fixed three-month
half-life. Sorted robust estimators discard chronology, quarterly vote
discards magnitude, and regression/rank/path/high-low cards use different
state objects. The exact endpoints, return orientation, age mapping, base two,
half-life, normalization, symmetric direction, monthly attempt, and renewal
lifecycle are load-bearing.

## 10. Safety Boundary

Only research, deterministic allocation, build, strict compile/Q01, one
`RISK_FIXED` backtest setfile, and one paced non-live Q02 handoff are
authorized. Do not run a manual backtest or touch live artifacts, AutoTrading,
`T_Live`, deploy manifests, the portfolio gate, portfolio admission, or a
correlation waiver.

## 11. Q01 Status

- Strict compile: PASS with zero errors and zero warnings; summary
  `D:/QM/reports/compile/20260811_111716/summary.csv`.
- Target build check: PASS with zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260811_111759.json`.
- P1 artifact validation: PASS at
  `D:/QM/reports/pipeline/QM5_20279/P1/P1_QM5_20279_result.json`.
- Independent statistic reference vectors: PASS, including a sample where the
  exponential kernel is short while the linear, median, trimmed, and
  Winsorized estimators remain long.
- Backtest set build hash:
  `4e60ca04da6ad5097fd291fac676bf72cf218bc2341bbdbab9c03ea5ed9670eb`.

## 12. Q02 Handoff

NOT QUEUED. Capacity must be sampled using the governed path-anchored T1-T10
factory count immediately before any bounded enqueue. Stop if the ceiling is
binding; do not dispatch or run a manual backtest.
