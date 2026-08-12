# QM5_20282_wti-madcap-mom — Strategy Spec

**EA ID:** QM5_20282
**Slug:** `wti-madcap-mom`
**Source:** `MOP-WTI-MADCAP-2026` (see `strategy-seeds/sources/MOP-WTI-MADCAP-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, reconstruct
thirteen consecutive completed WTI month-end closes and form twelve adjacent
monthly log returns. Estimate their even-sample median and raw median absolute
deviation (MAD). Cap each original return symmetrically at three raw MADs
around the median, average all twelve capped returns, and buy on a positive
mean or sell on a negative mean. A nonpositive MAD, exact-zero mean, or invalid
state consumes the month flat. Every entry has a frozen
`3.5 * ATR(20,D1)` hard stop, no take-profit, monthly renewal, and a forty-day
stale exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_months` | `12` | `[12]` | Exact adjacent completed-month returns |
| `strategy_mad_cap_mult` | `3.0` | `[3.0]` | Symmetric raw-MAD cap width |
| `strategy_history_bars_d1` | `800` | `[800]` | Bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `1500` | `[1500]` | Entry spread ceiling in WTI points |

All values are locked for the baseline. No optimization or alternative
estimator is authorized.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — the registered Darwinex WTI route and the only authorized
  crude-oil carrier for this card.

**Explicitly NOT for:**

- `XNGUSD.DWX` — already represented in the book and governed by separate
  natural-gas logic.
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

The current broker month contributes no signal endpoint.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11–12 after thirteen completed month ends; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Expected drawdown profile | Sparse fixed-risk WTI trend losses with gap and reversal exposure |
| Regime preference | Persistent crude-oil direction with isolated monthly shocks |
| Win rate target (qualitative) | Low to medium; expectancy must come from robust trend packages |

The carrier and statistic are diversification hypotheses only. Q09 owns any
realized portfolio-overlap conclusion.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `MOP-WTI-MADCAP-2026`
**Source type:** peer-reviewed paper with bounded QM mechanization
**Pointer:** `strategy-seeds/sources/MOP-WTI-MADCAP-2026/source.md`
**R1–R4 verdict (Q00):** all PASS; see
`strategy-seeds/cards/approved/QM5_20282_wti-madcap-mom_card.md`

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum,"
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The source establishes the broad own-return
trend family and includes WTI; the median/MAD cap is an explicit QM
hypothesis, not an author result.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Not authorized by this build |
| Full live (post-Q13 PASS) | RISK_PERCENT | Not authorized by this build |

The mission creates only a backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. `QM_FrameworkInit` enforces the
ENV-to-risk-mode contract.

## 8. Exact Statistical Contract

For thirteen positive finite completed month-end closes `C[0]..C[12]`, oldest
to newest:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
M = median_even(r) = (sorted(r)[5] + sorted(r)[6]) / 2
D = median_even(abs(r - M))
L = M - 3 * D
U = M + 3 * D
c[i] = min(U, max(L, r[i]))
S = sum(c[i]) / 12
```

Buy for `S > 0`, sell for `S < 0`, and stay flat for `S == 0`, `D <= 0`, or
invalid state. `D` is raw, not consistency-scaled. All twelve original
observations remain equally weighted after capping.

## 9. Non-Duplicate Boundary

`QM5_20269` trades only the sample median. `QM5_20270` deletes fixed tails.
`QM5_20277` caps fixed order-statistic tails regardless of dispersion.
`QM5_20278` and `QM5_20279` weight returns by chronology. This EA uniquely
combines robust location and robust dispersion to define adaptive symmetric
bounds while retaining all twelve returns with equal post-cap weights. The two
sorts, center indexes, raw-MAD convention, three-MAD bounds, zero-MAD
rejection, and monthly lifecycle are jointly load-bearing.

## 10. Kill Criteria

Retire below five completed packages per full post-warm-up year, on
nonpositive governed economics, or on later portfolio-correlation rejection.
Fail on endpoint discontinuity, current-month leakage, reversed returns, wrong
sort or center indexes, scaled or nonpositive-MAD fallback, wrong cap,
asymmetry, divisor other than twelve, repeated monthly attempt, missing hard
stop, hold beyond forty days, risk mismatch, or nondeterminism. No post-result
rescue parameter is authorized.

## 11. Safety Boundary

Research, deterministic allocation, build, strict compile/Q01, one fixed-risk
backtest set, and one paced non-live Q02 enqueue only. No manual backtest,
live/demo/shadow/stress/optimization set, `T_Live` access, AutoTrading change,
deploy manifest, portfolio-gate edit, portfolio admission, or correlation
waiver is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-11 | Initial scaffold from approved card | Build commit pending |
| v2 | 2026-08-11 | Initial V5 implementation and Q01 validation | Strict compile, target build check, P1 artifact validation, and independent MAD-cap reference vectors PASS |
| v3 | 2026-08-11 | Paced Q02 handoff | One current-binary WTI row enqueued below the path-anchored factory CPU ceiling |

## 12. Q01 Status

- Strict compile: PASS with zero errors and zero warnings; summary
  `D:/QM/reports/compile/20260811_163516/summary.csv` and log
  `C:/QM/repo/framework/build/compile/20260811_163516/QM5_20282_wti-madcap-mom.compile.log`.
- Target build check: PASS with zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260811_163516.json`.
- P1 artifact validation: PASS at
  `D:/QM/reports/pipeline/QM5_20282/P1/P1_QM5_20282_result.json`.
- Independent statistic/clock reference vectors: PASS for positive, negative,
  exact-zero, zero-MAD, adaptive-cap divergence, endpoint orientation, and
  cross-year month continuity cases.
- Backtest set build hash:
  `6377c85f3a9f84b18a32653cd33925a60228a682adea6ef21ba94057ffca416f`.
- Compiled binary SHA-256:
  `356320796590ded3143a5a7271b58b21849654a356922fa2d93f09a37e66aa46`.

## 13. Q02 Handoff

One current-binary `XTIUSD.DWX` Q02 row was enqueued at
`2026-08-11T16:38:49+00:00`: work item
`0bf7e357-2686-4e5b-98f5-0eb8c65cf31e`, attempt 0, no verdict, and
`priority_track=true`. Immediate readback found it active and claimed by T5.
The binding path-anchored pre-enqueue sample at
`2026-08-11T16:38:48.9365981Z` found three executing T1-T10 factory
terminals, T1, T2, and T3, against the ceiling of seven. This mission ran no
dispatch tick or manual backtest.
