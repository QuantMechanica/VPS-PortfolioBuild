# QM5_20281_wti-tsmom-h2 — Strategy Spec

**EA ID:** QM5_20281
**Slug:** `wti-tsmom-h2`
**Source:** `MOP-WTI-TSMOM-H2-2026` (see `strategy-seeds/sources/MOP-WTI-TSMOM-H2-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

On the first D1 bar of each genuine odd-numbered broker month, reconstruct
thirteen consecutive completed WTI month-end closes. Buy when the exact log
return from the oldest to newest endpoint is positive and sell when it is
negative. Keep one package through the intervening even-month transition, then
close and reconsider it at the next odd-month boundary. Exact-zero or invalid
state consumes the bimonthly period flat. Every entry has a frozen
`3.5 * ATR(20,D1)` hard stop, no take-profit, and a seventy-day stale exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_months` | `12` | `[12]` | Exact completed-month formation intervals |
| `strategy_hold_months` | `2` | `[2]` | Fixed non-overlapping package clock |
| `strategy_rebalance_month_parity` | `1` | `[1]` | Odd-month decision epoch |
| `strategy_history_bars_d1` | `800` | `[800]` | Bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `70` | `[70]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `1500` | `[1500]` | Entry spread ceiling in WTI points |

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — the registered Darwinex WTI route and the only authorized
  crude-oil carrier for this card.

**Explicitly NOT for:**

- `XNGUSD.DWX` — already represented in the book and has separate one- and
  two-month trend/contrarian mechanics.
- `XBRUSD.DWX` — Brent is a distinct benchmark and is not source-equivalent to
  this WTI-only execution contract.
- `XAUUSD.DWX` and `XAGUSD.DWX` — metals do not satisfy the WTI carrier lock.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | Native completed broker months reconstructed from D1; `ATR(20,D1)` |
| Bar gating | One `QM_IsNewBar()` consume, then `QM_CalendarPeriodKey(PERIOD_MN1, symbol, shift)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 6 after thirteen completed month ends; retire below 5 |
| Typical hold time | About two calendar months, capped at 70 days |
| Expected drawdown profile | Sparse fixed-risk WTI trend losses with gap and reversal exposure |
| Regime preference | Persistent crude-oil directional regimes |
| Win rate target (qualitative) | Low to medium; expectancy must come from larger trend packages |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `MOP-WTI-TSMOM-H2-2026`
**Source type:** peer-reviewed paper with bounded QM mechanization
**Pointer:** `strategy-seeds/sources/MOP-WTI-TSMOM-H2-2026/source.md`
**R1–R4 verdict (Q00):** all PASS; see
`strategy-seeds/cards/approved/QM5_20281_wti-tsmom-h2_card.md`

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The source establishes the broad own-return
formation/holding family and includes WTI; the non-overlapping odd-month
implementation is an explicit QM hypothesis.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). This mission creates only the backtest set.

## 8. Non-Duplicate Boundary

`QM5_12603` renews the same twelve-month WTI direction monthly. This EA uses a
fixed odd-month epoch, holds through even-month transitions, and produces six
non-overlapping packages per year. `QM5_20013` shares the clock but trades a
two-month natural-gas return contrarian; `QM5_13139` is a two-leg XTI/XNG
coefficient-of-variation rank basket. The formation/holding pair and lifecycle
are jointly load-bearing.

## 9. Kill Criteria

Retire below five completed packages per full post-warm-up year, on nonpositive
governed economics, or on later portfolio-correlation rejection. Fail on an
even-month attempt, premature even-month rollover, endpoint discontinuity,
wrong return orientation, repeated bimonthly attempt, missing hard stop, hold
beyond seventy days, risk mismatch, or nondeterminism. No post-result rescue
parameter is authorized.

## 10. Safety Boundary

Research, deterministic allocation, build, strict compile/Q01, one fixed-risk
backtest set, and one paced non-live Q02 enqueue only. No manual backtest,
live/demo/shadow/stress/optimization set, T_Live access, AutoTrading change,
deploy manifest, portfolio-gate edit, portfolio admission, or correlation
waiver is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-11 | Initial scaffold from approved card | Build commit pending |
| v2 | 2026-08-11 | Initial V5 implementation and Q01 validation | Strict compile, target build check, P1 artifact validation, and independent reference vectors PASS |
| v3 | 2026-08-11 | Paced Q02 handoff | One current-binary WTI row enqueued below the path-anchored factory CPU ceiling |

## 11. Q01 Status

- Strict compile: PASS with zero errors and zero warnings; summary
  `D:/QM/reports/compile/20260811_150844/summary.csv` and log
  `C:/QM/repo/framework/build/compile/20260811_150844/QM5_20281_wti-tsmom-h2.compile.log`.
- Target build check: PASS with zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260811_150911.json`.
- P1 artifact validation: PASS at
  `D:/QM/reports/pipeline/QM5_20281/P1/P1_QM5_20281_result.json`.
- Independent statistic/clock reference vectors: PASS for month continuity,
  positive/negative/zero direction, endpoint identity, non-conjunction,
  six odd-month decisions, even-month hold, and odd-month rollover.
- Backtest set build hash:
  `a594314869a2da7593b85033736f0b949a45edf880be260750a14500e6f607ef`.

## 12. Q02 Handoff

One current-binary `XTIUSD.DWX` Q02 row was enqueued at
`2026-08-11T15:15:32+00:00`: work item
`fab14b85-52c0-4fb1-96d9-10b6c8fb9628`, attempt 0, no verdict, and
`priority_track=true`. Immediate readback was pending and unclaimed. The
binding path-anchored pre-enqueue sample at
`2026-08-11T15:15:26.6767388Z` found three executing T1-T10 factory
terminals, T1, T5, and T10, against the ceiling of seven. This mission ran no
dispatch tick or manual backtest.
