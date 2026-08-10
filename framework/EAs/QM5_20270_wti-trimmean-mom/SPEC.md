# QM5_20270_wti-trimmean-mom - Strategy Spec

**EA ID:** QM5_20270  
**Slug:** `wti-trimmean-mom`  
**Source:** `MOP-TSMOM-2012_XTI_TRIM12_S19`  
**Card:** `strategy-seeds/cards/approved/QM5_20270_wti-trimmean-mom_card.md`  
**Last revised:** 2026-08-10

## 1. Strategy Logic

On the first processed `XTIUSD.DWX` D1 bar of a genuine broker-month
transition, reconstruct thirteen consecutive completed broker-month-end closes
in chronological order. Form twelve disjoint monthly log returns, sort a copy
ascending, delete indexes 0, 1, 10, and 11, and calculate the arithmetic mean
of indexes 2 through 9 with divisor eight. Buy when the trimmed mean is
positive, sell when it is negative, and consume the month flat when it is
exactly zero or invalid.

Close the prior package at the next month boundary before considering the new
month. Maintain one persisted attempt per broker month, one position, one
frozen ATR hard stop, and no take-profit. This is a fixed-tail robust statistic
on monthly returns, not cumulative TSMOM, return-sign breadth, the two-center
median, rank trend, regression, calendar logic, or an oscillator.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_return_months` | 12 | 12 | Disjoint completed monthly returns |
| `strategy_trim_each_tail` | 2 | 2 | Sorted observations removed per tail |
| `strategy_history_bars_d1` | 800 | 800 | Bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | 20 | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | 3.5 | 3.5 | Frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | 1500 | WTI entry spread ceiling |

No baseline parameter sweep is authorized.

## 3. Symbol Universe

- `XTIUSD.DWX` only.
- Magic slot 0, registered magic `202700000`.
- Single-position, single-symbol EA.
- Runtime uses only native MT5 price, calendar, ATR, quote, position, deal, and
  framework state.

## 4. Timeframe

- Host timeframe: D1 only.
- Formation endpoints: completed broker-month closes reconstructed from D1
  bars; no current-month endpoint is allowed.
- Decision/renewal clock: first processed D1 bar of each genuine new broker
  month.

## 5. Expected Behaviour

- Approximately twelve completed monthly packages per full post-warm-up year;
  Q02 retires the EA below five.
- Symmetric long/short WTI exposure driven by the middle eight monthly returns
  after fixed deletion of two observations from each tail.
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
`strategy-seeds/sources/MOP-WTI-TRIMMEAN-2026/source.md`. The trimmed-mean rule
is a transparent QM hypothesis, not a source performance claim.

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
- **Trade Entry:** persist month attempt, reconstruct endpoints, compute and
  sort twelve returns, calculate the exact middle-eight mean, then validate
  spread, quote, ATR, stop, sizing, and place one order.
- **Trade Management:** repair malformed owned state and close prior-month or
  forty-day-stale exposure before entry-only gates.
- **Trade Close:** framework close helper, frozen broker stop, and kill switch.

## 9. Non-Duplicate Boundary

The pre-allocation checker found no exact or fuzzy identity across 4,327
registry rows and 443 cards. The exact twelve disjoint returns, ascending sort,
deletion of indexes 0, 1, 10, and 11, retained indexes 2 through 9, divisor
eight, symmetric mapping, monthly attempt, and renewal lifecycle are load-
bearing. `QM5_20269` instead uses only the two center returns.

## 10. Safety Boundary

Only research, deterministic allocation, build, strict compile/Q01, one
`RISK_FIXED` backtest setfile, and one paced non-live Q02 handoff are
authorized. Do not run a manual backtest or touch live artifacts, AutoTrading,
`T_Live`, deploy manifests, the portfolio gate, portfolio admission, or a
correlation waiver.

## 11. Q01 Status

- Strict compile: PASS, zero errors and zero warnings; summary
  `D:/QM/reports/compile/20260810_093222/summary.csv`.
- Target build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260810_093222.json`.
- P1 artifact validation: PASS at
  `D:/QM/reports/pipeline/QM5_20270/P1/P1_QM5_20270_result.json`.
- Backtest set build hash:
  `409f58f6b9537c64171835f155868ea7c74802db63ced3209c5d61e52b08efb2`.

## 12. Q02 Handoff

Not started. Q01 has passed. Exactly one paced `XTIUSD.DWX` D1 work item may
be enqueued only while live factory utilization remains below the binding CPU
ceiling.
