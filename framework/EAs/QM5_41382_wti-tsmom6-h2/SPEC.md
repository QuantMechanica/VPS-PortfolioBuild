# QM5_41382_wti-tsmom6-h2 — Strategy Spec

**EA ID:** QM5_41382
**Slug:** `wti-tsmom6-h2`
**Source:** `MOP-WTI-TSMOM6-H2-2026`
**Author of this spec:** Codex
**Last revised:** 2026-09-07

## 1. Strategy Logic

On the first D1 bar of each odd broker month, reconstruct seven consecutive
completed WTI month-end closes and follow the sign of the exact six-month log
return. Hold one package through the intervening even month, then close and
reconsider at the next odd-month boundary. Equality or invalid state consumes
the period flat; every entry has a frozen `3.5*ATR(20,D1)` stop and no target.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_symbol` | `XTIUSD.DWX` | locked | Exact WTI carrier |
| `strategy_return_months` | `6` | `[6]` | Exact formation intervals |
| `strategy_hold_months` | `2` | `[2]` | Fixed package clock |
| `strategy_rebalance_month_parity` | `1` | `[1]` | Odd-month epoch |
| `strategy_history_bars_d1` | `300` | `[300]` | Bounded D1 history |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen stop multiple |
| `strategy_max_hold_days` | `70` | `[70]` | Stale repair |
| `strategy_max_spread_points` | `1500` | `[1500]` | Entry spread ceiling |

## 3. Symbol Universe

- `XTIUSD.DWX` — registered Darwinex WTI route and the only card-authorized
  carrier. XNG, Brent, and metals are separate contracts and are excluded.

## 4. Timeframe

Base timeframe is exact `D1`. Completed broker-month endpoints are
reconstructed from bounded D1 rates; the hard stop uses completed
`ATR(20,D1)`.

## 5. Expected Behaviour

Approximately six completed packages per full post-warm-up year, held for
about two calendar months and capped at 70 days. The preferred regime is a
persistent WTI direction; drawdown risk is sparse fixed-risk trend losses,
gaps, and reversal exposure. Q02 retires below five trades/year.

## 6. Source Citation

**Source ID:** `MOP-WTI-TSMOM6-H2-2026`. See
`strategy-seeds/sources/MOP-WTI-TSMOM6-H2-2026/source.md` and the R1-R4 record
in `strategy-seeds/cards/approved/QM5_41382_wti-tsmom6-h2_card.md`.

Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, Journal of
Financial Economics 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02–Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

This mission creates only the backtest set. It does not authorize live use.

## 8. Non-Duplicate Boundary

`QM5_20059` renews the same six-month direction monthly. `QM5_20281` uses
the same bimonthly clock but a twelve-month formation. `QM5_41379` and
`QM5_41380` use three- and one-month formations. This identity combines the
exact six-month endpoints with the fixed odd-month two-month lifecycle.

## 9. Kill Criteria

Retire below five packages/year, on nonpositive governed economics, or on
later correlation rejection. Fail on endpoint discontinuity, current-month
leakage, even-month action, repeated attempt, missing stop, wrong rollover,
risk mismatch, or nondeterminism. No parameter rescue is authorized.

## 10. Safety Boundary

Branch build, strict Q01, one fixed-risk backtest set, and one paced non-live
Q02 enqueue only. No manual backtest, live/demo/shadow/stress/optimization
set, `T_Live`, AutoTrading, deploy manifest, portfolio-gate edit, admission,
or correlation waiver.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-07 | Initial build from approved card | PACER guarded build |
| v2 | 2026-09-07 | Q01 validation | Governed compile PASS with compiler zero errors/warnings |
| v3 | 2026-09-07 | Q02 CPU admission | Stopped before enqueue at 100.0% CPU versus 97% ceiling |

## 11. Q01 And Q02 Status

Q01 passed under work item `2ba18bd3-a6f3-485f-bf5f-a7ace6af202d`:
`COMPILE_OK`, compiler zero errors/warnings, and strict build check PASS with
three nonfailing card-resolution advisories. Reference vectors and card lint
passed, and the PACER framework-input pin audit returned zero findings after
the final source write and before compile enqueue.

Q02 was not enqueued. Fresh CPU samples were
`[99.7, 100.0, 100.0, 99.4, 99.8]`; the 100.0% maximum breached the binding
97% ceiling, so execution stopped without creating a Q02 work item.
