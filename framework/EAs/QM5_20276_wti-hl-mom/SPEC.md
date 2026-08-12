# QM5_20276_wti-hl-mom - Strategy Spec

**EA ID:** QM5_20276
**Slug:** `wti-hl-mom`
**Source:** `MOP-TSMOM-2012_XTI_HLRET12_S24`
**Card:** `strategy-seeds/cards/approved/QM5_20276_wti-hl-mom_card.md`
**Last revised:** 2026-08-11

## 1. Strategy Logic

On the first processed `XTIUSD.DWX` D1 bar of a genuine broker-month
transition, reconstruct thirteen consecutive completed broker-month-end closes
in chronological order. Form twelve adjacent monthly log returns and all 78
inclusive pairwise averages `(r[i]+r[j])/2` for `0 <= i <= j <= 11`. Sort the
averages and take the even-sample center `(sorted[38]+sorted[39])/2`. Buy when
it is positive, sell when it is negative, and consume exact-zero or invalid
states flat.

Close the prior package at the next month boundary before considering the new
month. Maintain one persisted attempt per broker month, one position, one
frozen ATR hard stop, and no take-profit. This is a robust return-location
statistic, not an unqualified cumulative return, raw-return median, trimmed
mean, pairwise price slope, sign statistic, calendar rule, or oscillator.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_endpoint_count` | 13 | 13 | Completed month-end observations |
| `strategy_return_count` | 12 | 12 | Adjacent completed monthly log returns |
| `strategy_pair_count` | 78 | 78 | Inclusive pairwise averages |
| `strategy_history_bars_d1` | 800 | 800 | Bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | 20 | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | 3.5 | 3.5 | Frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | 1500 | WTI entry spread ceiling |

No baseline parameter sweep is authorized.

## 3. Symbol Universe

- `XTIUSD.DWX` only.
- Magic slot 0, intended magic `202760000`.
- Single-position, single-symbol EA.
- Runtime uses only native MT5 price, calendar, ATR, quote, position, deal, and
  framework state.
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
- Symmetric long/short WTI exposure from the pseudomedian's sign.
- Prior package closes before any replacement entry, even when direction is
  unchanged.
- Friday close and news axes are disabled for the full-month native-price
  package. A forty-day stale exit and broker hard stop remain binding.
- The edge prefers persistent WTI own-return regimes but is deliberately less
  sensitive to a single extreme monthly return than cumulative momentum.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The complete-read parent packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the bounded extraction is
`strategy-seeds/sources/MOP-WTI-HLRET-2026/source.md`. The pairwise-average
pseudomedian is a transparent QM hypothesis, not a source performance claim.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Q02-Q10 backtest | `RISK_FIXED` | 1000 |
| Live | not authorized | n/a |

The backtest setfile locks `RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`. Each
entry receives one frozen `3.5 * ATR(20,D1)` broker hard stop. No profit
target, trail, break-even, partial close, scale-in, grid, martingale, or
pyramid is allowed.

## 8. Framework Alignment

- **No-Trade:** exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap state guards.
- **Trade Entry:** persist month attempt, reconstruct endpoints, calculate the
  twelve returns, enumerate and sort all 78 pairwise averages, then validate
  spread, quote, ATR, stop, sizing, and place one order.
- **Trade Management:** repair malformed owned state and close prior-month or
  forty-day-stale exposure before entry-only gates.
- **Trade Close:** framework close helper, frozen broker stop, and kill switch.

## 9. Non-Duplicate Boundary

The pre-allocation checker found no exact identity and surfaced only the
expected raw-median and trimmed-mean fuzzy siblings. The exact inclusive pair
enumeration, 78 averages, and center indexes distinguish this return-location
functional from those systems and from the 78 time-normalized price slopes in
`QM5_20271_wti-theilsen-tr`. The thirteen endpoints, twelve adjacent returns,
inclusive pairs, sort, center indexes, direction, monthly attempt, and renewal
lifecycle are load-bearing.

## 10. Safety Boundary

Only research, deterministic allocation, build, strict compile/Q01, one
`RISK_FIXED` backtest setfile, and one paced non-live Q02 handoff are
authorized. Do not run a manual backtest or touch live artifacts, AutoTrading,
`T_Live`, deploy manifests, the portfolio gate, portfolio admission, or a
correlation waiver.

## 11. Q01 Validation

Strict compilation passed with zero errors and zero warnings. The targeted
framework build check passed with zero failures and zero warnings, the
independent estimator reference test confirmed all 78 inclusive pairs and
center indexes 38/39, and P1 confirmed the EA directory and EX5 binary. No
manual smoke or backtest was run.

## 12. Q02 Handoff

One current-binary `XTIUSD.DWX` Q02 row was enqueued at
`2026-08-11T03:52:14+00:00`: work item
`dd8c4995-ea1d-4b8b-baa2-1cfbfb063b83`, attempt 0, no verdict, and
`priority_track=true`. Immediate readback was pending and unclaimed. The
binding pre-enqueue sample at `2026-08-11T03:50:29+00:00` found two executing
T1-T10 factory terminals against the ceiling of seven. This mission ran no
dispatch tick or manual backtest.
