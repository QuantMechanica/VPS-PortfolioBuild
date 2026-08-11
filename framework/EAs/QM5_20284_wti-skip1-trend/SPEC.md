# QM5_20284_wti-skip1-trend — Strategy Spec

**EA ID:** QM5_20284
**Slug:** `wti-skip1-trend`
**Source:** `MOP-WTI-SKIP1-2026` (see `strategy-seeds/sources/MOP-WTI-SKIP1-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-12

---

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, reconstruct
fourteen consecutive completed WTI month-end closes. Validate but exclude the
newest completed monthly return, then compute the exact twelve-month return
ending one month before the decision. Buy on a positive delayed return or sell
on a negative delayed return. Exact zero or invalid state consumes the month
flat. Every entry has a frozen `3.5 * ATR(20,D1)` hard stop, no take-profit,
monthly renewal, and a forty-day stale exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trend_months` | `12` | `[12]` | Exact older completed-month interval |
| `strategy_skip_months` | `1` | `[1]` | Newest completed interval excluded |
| `strategy_history_bars` | `500` | `[500]` | Bounded D1 endpoint reconstruction |
| `strategy_atr_period` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `1500` | `[1500]` | Entry spread ceiling in WTI points |

All values are locked for the baseline. No optimization or alternate endpoint
rule is authorized.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — registered Darwinex WTI route and the only authorized carrier.

**Explicitly NOT for:**

- `XNGUSD.DWX` — already represented in the book and governed separately.
- `XBRUSD.DWX` — distinct benchmark and not source-equivalent to this contract.
- `XAUUSD.DWX` and `XAGUSD.DWX` — metals do not satisfy the WTI carrier lock.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | Completed broker months reconstructed from D1; `ATR(20,D1)` |
| Bar gating | One `QM_IsNewBar()` consume, then broker-month transition check |

The current broker month and newest completed monthly return contribute no
signal return.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11–12 after fourteen completed month ends; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Expected drawdown profile | Sparse fixed-risk WTI trend losses with gap and delayed-reversal exposure |
| Regime preference | Persistent crude-oil direction surviving one-month signal delay |
| Win rate target (qualitative) | Low to medium; expectancy must come from slow trend packages |

The WTI carrier and delayed statistic are diversification hypotheses only.
Q09 owns any realized portfolio-overlap conclusion.

---

## 6. Source Citation

**Source ID:** `MOP-WTI-SKIP1-2026`
**Source type:** peer-reviewed paper with bounded QM mechanization
**Pointer:** `strategy-seeds/sources/MOP-WTI-SKIP1-2026/source.md`
**R1–R4 verdict (Q00):** all PASS; see
`strategy-seeds/cards/approved/QM5_20284_wti-skip1-trend_card.md`

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum,"
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The source establishes the broad own-return
trend family and includes WTI; excluding the newest completed month is an
explicit QM hypothesis, not an author result.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02–Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Not authorized by this build |
| Full live (post-Q13 PASS) | RISK_PERCENT | Not authorized by this build |

The mission creates only a backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. `QM_FrameworkInit` enforces the
environment-to-risk-mode contract.

## 8. Exact Statistical Contract

For fourteen positive finite completed month-end closes in reverse
chronological order:

```text
M0  = end(t-1), deliberately skipped
M1  = end(t-2), trend endpoint
M13 = end(t-14), trend start

skipped_return = ln(M0 / M1)
trend_return   = ln(M1 / M13)
```

Buy for `trend_return > 0`, sell for `trend_return < 0`, and stay flat for
exact zero or invalid state. `skipped_return` must be finite but cannot affect
eligibility, direction, or size.

## 9. Non-Duplicate Boundary

`QM5_12603` ends a thresholded trailing return at the newest observation.
`QM5_20239` trades the same older interval only after an opposing newest
month. `QM5_20258` votes nested horizons sharing the newest endpoint.
`QM5_20280` uses four months ending at that endpoint. This EA always excludes
`M0/M1`, trades the nonzero sign of `M1/M13`, and never gates on the skipped
return. The endpoint set, excluded interval, absence of a skipped-return gate,
and monthly lifecycle are jointly load-bearing.

## 10. Kill Criteria

Retire below five completed packages per full post-warm-up year, on
nonpositive governed economics, or on later portfolio-correlation rejection.
Fail on endpoint discontinuity, current-month leakage, inclusion of the
skipped interval, a skipped-return gate, wrong return orientation, wrong-side
entry, repeated attempt, missing hard stop, hold beyond forty days, risk
mismatch, or nondeterminism. No post-result rescue parameter is authorized.

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
| v2 | 2026-08-11 | Initial V5 implementation and Q01 validation | Strict compile, target build check, P1 artifact validation, and independent skipped-month vectors PASS |
| v3 | 2026-08-12 | Paced Q02 handoff stopped at CPU ceiling | Target-only dry run selected one priority row; binding 7/7 tester sample prohibited enqueue |

## 12. Q01 Status

PASS. Strict compile completed with zero errors and zero warnings; the targeted
build check completed with zero failures and zero warnings; P1 artifact
validation found the EA directory and current `.ex5`; and independent vectors
proved endpoint orientation, exclusion invariance, difference from both the
ordinary trailing rule and the pullback gate, exact-zero handling, short-side
direction, and cross-year month continuity. Evidence:

- `D:/QM/reports/compile/20260811_223924/summary.csv`
- `D:/QM/reports/framework/21/build_check_20260811_223840.json`
- `D:/QM/reports/pipeline/QM5_20284/P1/P1_QM5_20284_result.json`
- `docs/test_skip1_reference.py`

## 13. Q02 Handoff

Not enqueued. The target-only dry run selected exactly one priority-track
`XTIUSD.DWX` row with 1,103 pending rows against the 7,000 queue ceiling. The
binding path-anchored sample at `2026-08-11T22:42:22.8387848Z` then found
seven executing T1-T10 factory terminals (`T2,T5,T6,T7,T8,T9,T10`) against
the hard ceiling of seven. The OWNER-approved stop rule therefore prohibited
the apply. Immediate readback remained zero work items for `QM5_20284`.
Evidence: `docs/ops/evidence/2026-08-12_qm5_20284_wti_skip1_trend_q01_cpu_ceiling_stop.md`.
