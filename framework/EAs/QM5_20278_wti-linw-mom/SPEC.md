# QM5_20278_wti-linw-mom - Strategy Spec

**EA ID:** QM5_20278
**Slug:** `wti-linw-mom`
**Source:** `MOP-TSMOM-2012_XTI_LINW12_S26`
**Card:** `strategy-seeds/cards/approved/QM5_20278_wti-linw-mom_card.md`
**Last revised:** 2026-08-11

## 1. Strategy Logic

On the first processed `XTIUSD.DWX` D1 bar of a genuine broker-month
transition, reconstruct thirteen consecutive completed broker-month-end closes
in chronological order. Form twelve adjacent monthly log returns. Multiply
the oldest return by one, the next by two, and so on through weight twelve for
the newest return. Divide the weighted sum by exactly 78. Buy when the result
is positive, sell when it is negative, and consume the month flat when it is
exactly zero or invalid.

Close the prior package at the next month boundary before considering the new
month. Maintain one persisted attempt per broker month, one position, one
frozen ATR hard stop, and no take-profit. This is a chronological linear-
recency return estimator, not a sorted-return statistic, endpoint return,
single-horizon rule, sign vote, price regression, calendar rule, or oscillator.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_return_months` | 12 | 12 | Adjacent completed monthly returns |
| `strategy_weight_start` | 1 | 1 | Oldest-return integer weight |
| `strategy_weight_step` | 1 | 1 | Weight increment per newer return |
| `strategy_weight_total` | 78 | 78 | Fixed normalization divisor |
| `strategy_history_bars_d1` | 800 | 800 | Bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | 20 | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | 3.5 | 3.5 | Frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | 1500 | WTI entry spread ceiling |

No baseline parameter sweep is authorized.

## 3. Symbol Universe

- `XTIUSD.DWX` only.
- Magic slot 0, intended magic `202780000`.
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
- Symmetric long/short WTI exposure driven by the sign of the chronological
  `1..12` weighted mean of twelve completed monthly returns.
- All twelve return magnitudes contribute; the newest receives twelve times
  the oldest observation's weight. Signal magnitude never scales risk.
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
`strategy-seeds/sources/MOP-WTI-LINW-2026/source.md`. Linear recency weighting
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
- **Trade Entry:** persist month attempt, reconstruct endpoints, compute twelve
  chronological returns, apply weights `1..12` and divisor 78, then validate
  spread, quote, ATR, stop, sizing, and place one order.
- **Trade Management:** repair malformed owned state and close prior-month or
  forty-day-stale exposure before entry-only gates.
- **Trade Close:** framework close helper, frozen broker stop, and kill switch.

## 9. Non-Duplicate Boundary

The pre-allocation checker found no exact identity across 4,343 registry rows
and 454 cards. It surfaced three expected same-source robust-location cards;
those sort returns and discard chronology. This rule preserves chronological
order and gives every adjacent return a unique integer weight. The quarterly
vote discards magnitude, the OLS card fits price levels with an `R^2` gate,
and index MAC(5) is a four-day SP500 contrarian rule. The exact endpoints,
return orientation, vector `1..12`, total 78, symmetric trend mapping, monthly
attempt, and renewal lifecycle are load-bearing.

## 10. Safety Boundary

Only research, deterministic allocation, build, strict compile/Q01, one
`RISK_FIXED` backtest setfile, and one paced non-live Q02 handoff are
authorized. Do not run a manual backtest or touch live artifacts, AutoTrading,
`T_Live`, deploy manifests, the portfolio gate, portfolio admission, or a
correlation waiver.

## 11. Q01 Status

Pending implementation, strict compile, targeted build check, statistic
reference test, and P1 artifact validation.

## 12. Q02 Handoff

Not enqueued. Q02 may receive exactly one `XTIUSD.DWX` D1 current-binary row
only after Q01 PASS and a binding factory CPU-ceiling check.
