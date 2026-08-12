# QM5_20272_wti-qtrvote-tr - Strategy Spec

**EA ID:** QM5_20272  
**Slug:** `wti-qtrvote-tr`  
**Source:** `MOP-TSMOM-2012_XTI_QTRVOTE12_S21`  
**Card:** `strategy-seeds/cards/approved/QM5_20272_wti-qtrvote-tr_card.md`  
**Last revised:** 2026-08-10

## 1. Strategy Logic

On the first processed `XTIUSD.DWX` D1 bar of a genuine broker-month
transition, reconstruct thirteen consecutive completed broker-month-end closes
in chronological order. Form four non-overlapping three-month log returns over
boundary pairs `(0,3)`, `(3,6)`, `(6,9)`, and `(9,12)`. Buy when at least
three are strictly positive, sell when at least three are strictly negative,
and consume all other states flat. Exact-zero blocks are neutral.

Close the prior package at the next month boundary before considering the new
month. Maintain one persisted attempt per broker month, one position, one
frozen ATR hard stop, and no take-profit. This is a disjoint quarterly-block
sign consensus, not a nested cumulative-horizon vote, adjacent-month sign
count, regression, rank trend, robust average, calendar rule, or oscillator.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_endpoint_count` | 13 | 13 | Completed month-end observations |
| `strategy_block_months` | 3 | 3 | Non-overlapping return width |
| `strategy_consensus_required` | 3 | 3 | Same-sign blocks required |
| `strategy_history_bars_d1` | 800 | 800 | Bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | 20 | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | 3.5 | 3.5 | Frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | 1500 | WTI entry spread ceiling |

No baseline parameter sweep is authorized.

## 3. Symbol Universe

- `XTIUSD.DWX` only.
- Magic slot 0, intended magic `202720000`.
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

- Approximately ten completed monthly packages per full post-warm-up year;
  Q02 retires the EA below five.
- Symmetric long/short WTI exposure only after a three-of-four consensus among
  four disjoint quarterly path segments.
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
`strategy-seeds/sources/MOP-WTI-QTRVOTE-2026/source.md`. The quarter-block
vote is a transparent QM hypothesis, not a source performance claim.

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
- **Trade Entry:** persist month attempt, reconstruct endpoints, calculate the
  four exact block returns and strict sign consensus, then validate spread,
  quote, ATR, stop, sizing, and place one order.
- **Trade Management:** repair malformed owned state and close prior-month or
  forty-day-stale exposure before entry-only gates.
- **Trade Close:** framework close helper, frozen broker stop, and kill switch.

## 9. Non-Duplicate Boundary

The pre-allocation checker found no exact identity and two expected
shared-source fuzzy matches across 4,332 registry rows and 445 cards. The exact
thirteen month ends, boundary indexes `0,3,6,9,12`, disjoint log returns,
neutral zeros, strict three-of-four threshold, symmetric mapping, monthly
attempt, and renewal lifecycle are load-bearing. The cumulative-horizon vote,
adjacent-sign, OLS, rank, median, trimmed-mean, and Theil-Sen WTI paths use
materially different estimators.

## 10. Safety Boundary

Only research, deterministic allocation, build, strict compile/Q01, one
`RISK_FIXED` backtest setfile, and one paced non-live Q02 handoff are
authorized. Do not run a manual backtest or touch live artifacts, AutoTrading,
`T_Live`, deploy manifests, the portfolio gate, portfolio admission, or a
correlation waiver.

## 11. Q01 Status

- Strict compile: PASS, zero errors and zero warnings; summary
  `D:/QM/reports/compile/20260810_153630/summary.csv`.
- Target build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260810_153630.json`.
- P1 artifact validation: PASS at
  `D:/QM/reports/pipeline/QM5_20272/P1/P1_QM5_20272_result.json`.
- Backtest set build hash:
  `a7e2111cef52a1ba022f6a693ba4438043829f6b96f938ec3adaa1656652c673`.

## 12. Q02 Handoff

One current-binary `XTIUSD.DWX` D1 Q02 row was enqueued at
`2026-08-10T15:42:40+00:00`: work item
`4fe84586-d791-4bbd-84ef-82aa0de5d0f1`, pending, attempt 0, unclaimed, and
`priority_track=true` on immediate readback. The binding pre-enqueue sample
found four executing T1-T10 factory terminals against the ceiling of seven.
No dispatch tick or backtest was run by the build mission.
