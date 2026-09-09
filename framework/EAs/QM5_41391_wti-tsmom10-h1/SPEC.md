# QM5_41391_wti-tsmom10-h1 — Strategy Spec

**EA ID:** QM5_41391  
**Slug:** `wti-tsmom10-h1`  
**Source:** `MOP-WTI-TSMOM10-H2-2026`  
**Author of this spec:** Codex  
**Last revised:** 2026-09-09

## 1. Strategy Logic

On the first D1 bar of every new broker month, reconstruct eleven consecutive
completed WTI month-end closes and follow the sign of the exact ten-month log
return. Hold one package until the next broker-month boundary, then close and
reconsider. Equality or invalid state consumes the month flat; every entry has
a frozen `3.5*ATR(20,D1)` stop and no target.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_symbol` | `XTIUSD.DWX` | locked | Exact WTI carrier |
| `strategy_return_months` | `10` | `[10]` | Exact formation intervals |
| `strategy_hold_months` | `1` | `[1]` | Fixed monthly package clock |
| `strategy_history_bars_d1` | `300` | `[300]` | Bounded D1 history |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Stale repair |
| `strategy_max_spread_points` | `1500` | `[1500]` | Entry spread ceiling |

## 3. Symbol Universe

- `XTIUSD.DWX` — registered Darwinex WTI route and the only card-authorized
  carrier. XNG, Brent, and metals are separate contracts and are excluded.

## 4. Timeframe

Base timeframe is exact `D1`. Completed broker-month endpoints are
reconstructed from bounded D1 rates; the hard stop uses completed
`ATR(20,D1)`.

## 5. Expected Behaviour

Approximately twelve completed packages per full post-warm-up year, held for
about one calendar month and capped at 40 days. The preferred regime is a
persistent WTI direction; drawdown risk is sparse fixed-risk trend losses,
gaps, and reversal exposure. Q02 retires below five trades/year.

## 6. Source Citation

**Source ID:** `MOP-WTI-TSMOM10-H2-2026`. See
`strategy-seeds/sources/MOP-WTI-TSMOM10-H2-2026/source.md` and the R1-R4 record
in `strategy-seeds/cards/approved/QM5_41391_wti-tsmom10-h1_card.md`.

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

`QM5_41388` uses the same exact ten-month endpoints but a fixed odd-month,
two-month lifecycle. Existing monthly-renewal WTI siblings use one-, two-,
three-, four-, six-, nine-, or twelve-month formation, or additional composite
and filter logic. This identity combines exact ten-month endpoints with the
every-month one-month lifecycle.

## 9. Kill Criteria

Retire below five packages/year, on nonpositive governed economics, or on
later correlation rejection. Fail on endpoint discontinuity, current-month
leakage, skipped or repeated month attempts, missing stop, wrong rollover,
risk mismatch, or nondeterminism. No parameter rescue is authorized.

## 10. Safety Boundary

Branch build, strict Q01, one fixed-risk backtest set, and one paced non-live
Q02 enqueue only. No manual backtest, live/demo/shadow/stress/optimization
set, `T_Live`, AutoTrading, deploy manifest, portfolio-gate edit, admission,
or correlation waiver.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-09 | Initial build from approved card | PACER guarded build |

## 11. Q01 And Q02 Status

Q01 is pending the mandatory source-fresh PACER pin audit, deterministic
reference vectors, and governed strict compile. Q02 is not authorized until
Q01 passes and a fresh five-sample host-CPU window remains strictly below the
97% ceiling on both average and maximum. No manual tester launch is permitted.
