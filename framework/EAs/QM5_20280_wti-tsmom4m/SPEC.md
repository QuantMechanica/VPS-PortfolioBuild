# QM5_20280_wti-tsmom4m - Strategy Spec

**EA ID:** QM5_20280
**Slug:** `wti-tsmom4m`
**Source:** `MOP-WTI-TSMOM4-2026`
**Card:** `strategy-seeds/cards/approved/QM5_20280_wti-tsmom4m_card.md`
**Author of this spec:** Codex
**Last revised:** 2026-08-11

## 1. Strategy Logic

On the first processed `XTIUSD.DWX` D1 bar of a genuine broker-month
transition, reconstruct five consecutive completed broker-month-end closes in
chronological order. Buy when the exact four-completed-month log return
`ln(C[4]/C[0])` is positive, sell when it is negative, and consume the month
flat when it is exactly zero or invalid.

Close the prior package at the next month boundary before considering a new
entry. Maintain one persisted attempt per broker month, one position, one
frozen ATR hard stop, and no take-profit. This is an exact completed-calendar-
month WTI return sign, not a D1-bar approximation, sign vote, return average,
weighted estimator, regression, calendar rule, or oscillator.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_return_months` | 4 | 4 | Exact completed broker-month return interval |
| `strategy_history_bars_d1` | 400 | 400 | Bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | 20 | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | 3.5 | 3.5 | Frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | 1500 | WTI entry spread ceiling |

No baseline parameter sweep is authorized.

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` only — the card is a direct WTI structural-trend carrier.
- Magic slot 0, intended magic `202800000`.

**Explicitly NOT for:**

- XAU, XAG, XNG, indices, FX, and synthetic or external futures curves — the
  approved hypothesis and source mapping are WTI-specific.

Runtime uses only native MT5 price, calendar, ATR, spread, quote, position,
deal, and framework state.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | Completed broker-month endpoints reconstructed from D1 bars |
| Bar gating | `QM_IsNewBar()` plus a genuine `PERIOD_MN1` key transition |

No current-month endpoint is allowed.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11-12; Q02 retires below 5 |
| Typical hold time | One broker month, bounded by 40 calendar days |
| Expected drawdown profile | High; WTI gap, reversal, roll/basis, and single-carrier risk |
| Regime preference | Persistent medium-horizon crude-oil trend |
| Win rate target (qualitative) | Unknown before governed testing |

Prior exposure closes before replacement even when the direction is unchanged.
Friday close and both news axes are disabled for the full-month native-price
package.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

**Source ID:** `MOP-WTI-TSMOM4-2026`
**Source type:** peer-reviewed paper bounded mechanization
**Pointer:** `strategy-seeds/sources/MOP-WTI-TSMOM4-2026/source.md`
**R1-R4 verdict (Q00):** all PASS per
`strategy-seeds/cards/approved/QM5_20280_wti-tsmom4m_card.md`

The complete-read parent is `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.
The four-completed-month WTI interval is a transparent pre-result QM
mechanization, not a source performance claim.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | `RISK_FIXED` | $1,000 per position |
| Live | not authorized | n/a |

The backtest setfile locks `RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`. Each
entry receives one frozen `3.5 * ATR(20,D1)` broker hard stop. No profit
target, trail, break-even, partial close, scale-in, grid, martingale, or
pyramid is allowed.

## 8. Framework Alignment

- **No-Trade:** exact EA/symbol/D1/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap state guards.
- **Trade Entry:** persist the month attempt, reconstruct five endpoints,
  compute the exact four-month log-return sign, then validate spread, quote,
  ATR, stop, sizing, and place one order.
- **Trade Management:** repair malformed owned state and close prior-month or
  forty-day-stale exposure before entry-only gates.
- **Trade Close:** framework close helper, frozen broker stop, and kill switch.

## 9. Non-Duplicate Boundary

The pre-allocation checker found no exact identity across 4,345 registry rows
and 456 cards. Expected fuzzy same-source matches were manually resolved: WTI
own-return carriers exist at one, two, three, six, nine, and twelve months,
but not at exactly four completed broker months. The five endpoints,
continuity, `(C[0],C[4])` orientation, symmetric direction, monthly attempt,
and renewal lifecycle are load-bearing.

## 10. Safety Boundary

Only research, deterministic allocation, build, strict compile/Q01, one
`RISK_FIXED` backtest setfile, and one paced non-live Q02 handoff are
authorized. Do not run a manual backtest or touch live artifacts,
AutoTrading, `T_Live`, deploy manifests, the portfolio gate, portfolio
admission, or a correlation waiver.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-11 | Initial build from approved card | Magic allocated; implementation and Q01 PASS |

## 11. Q01 Status

- Strict compile: PASS with zero errors and zero warnings; summary
  `D:/QM/reports/compile/20260811_132811/summary.csv`.
- Target build check: PASS with zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260811_132811.json`.
- P1 artifact validation: PASS at
  `D:/QM/reports/pipeline/QM5_20280/P1/P1_QM5_20280_result.json`.
- Exact four-month reference vectors: PASS for endpoint/path identity,
  positive, negative, exact-zero, chronology reversal, invalid inputs, and
  three-/six-month neighbor divergence.
- Backtest set build hash:
  `eff9f719bd94d121b371c44c954d200c7ec4a5cf303cdf5ceda22a0fb2950a38`.

## 12. Q02 Handoff

`NOT_ENQUEUED_CPU_CEILING`. The target-only dry run selected exactly one
priority-track `XTIUSD.DWX` row with zero existing work items. The binding
`2026-08-11T13:34:23.4269163Z` path-anchored sample then found seven executing
T1-T10 terminals (`T1`, `T2`, `T3`, `T5`, `T7`, `T8`, and `T10`) against the
ceiling of seven. No apply-mode enqueue, dispatch, or manual backtest was run.
A later paced operator may take a fresh immediate capacity sample and enqueue
exactly one current-binary row only when the factory count is below seven.
