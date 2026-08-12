# QM5_20285_wti-huber-mom — Strategy Spec

**EA ID:** QM5_20285
**Slug:** `wti-huber-mom`
**Source:** `MOP-WTI-HUBER-2026` (see `strategy-seeds/sources/MOP-WTI-HUBER-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-12

---

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, reconstruct
thirteen consecutive completed WTI month-end closes and form twelve adjacent
chronological log returns. Estimate their even-sample median and raw MAD,
freeze `delta = 1.5 * 1.4826 * MAD`, and run exactly 32 Huber reweighted-mean
updates from the median. Buy for a positive final location and sell for a
negative one. Exact zero or invalid state consumes the month flat. Every entry
has a frozen `3.5 * ATR(20,D1)` hard stop, no take-profit, monthly renewal,
and a forty-day stale exit.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_months` | `12` | `[12]` | Adjacent completed monthly log returns |
| `strategy_huber_tuning` | `1.5` | `[1.5]` | Normalized influence threshold |
| `strategy_mad_normalizer` | `1.4826` | `[1.4826]` | Raw-MAD scale normalization |
| `strategy_huber_steps` | `32` | `[32]` | Exact re-centering updates |
| `strategy_history_bars_d1` | `800` | `[800]` | Bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `1500` | `[1500]` | Entry spread ceiling in WTI points |

All values are locked for baseline. No optimization or alternate estimator is
authorized.

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — registered Darwinex WTI route and only authorized carrier.

**Explicitly NOT for:**

- `XNGUSD.DWX` — already represented in the book and governed separately.
- `XBRUSD.DWX` — distinct benchmark and not source-equivalent to this route.
- `XAUUSD.DWX` and `XAGUSD.DWX` — metals do not satisfy the WTI carrier lock.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | Completed broker months reconstructed from D1; `ATR(20,D1)` |
| Bar gating | One `QM_IsNewBar()` consume, then broker-month transition check |

The current broker month contributes no signal endpoint.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11–12 after thirteen completed month ends; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Expected drawdown profile | Sparse fixed-risk WTI trend losses with gap and delayed-reversal exposure |
| Regime preference | Persistent broad crude-oil direction not dominated by a single monthly shock |
| Win rate target | Low to medium; expectancy must come from slow trend packages |

The WTI carrier and bounded-influence statistic are diversification hypotheses
only. Q09 owns any realized portfolio-overlap conclusion.

## 6. Source Citation

**Source ID:** `MOP-WTI-HUBER-2026`
**Source type:** peer-reviewed trading paper with bounded statistical
mechanization
**Pointer:** `strategy-seeds/sources/MOP-WTI-HUBER-2026/source.md`
**R1–R4 verdict (G0):** all PASS; see
`strategy-seeds/cards/approved/QM5_20285_wti-huber-mom_card.md`

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, establishes the broad monthly own-price trend
family and includes WTI. Huber (1964), DOI `10.1214/aoms/1177703732`, supplies
statistical lineage only. Neither source tests the locked QM statistic.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02–Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Not authorized by this build |
| Full live (post-Q13 PASS) | RISK_PERCENT | Not authorized by this build |

The mission creates one backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Framework initialization enforces
the environment-to-risk-mode contract.

## 8. Exact Statistical Contract

For thirteen positive finite completed month-end closes, oldest to newest:

```text
r[i] = ln(C[i+1] / C[i]), i=0..11
m = even median(r)
MAD = even median(abs(r-m))
delta = 1.5 * 1.4826 * MAD
mu[0] = m
mu[j+1] = sum(w[i,j]*r[i]) / sum(w[i,j]), j=0..31
w[i,j] = 1 if abs(r[i]-mu[j]) <= delta
         delta/abs(r[i]-mu[j]) otherwise
```

The scale freezes before iteration. All 32 updates execute. Buy for
`mu[32] > 0`, sell for `mu[32] < 0`, and consume exact zero or invalid state
flat.

## 9. Non-Duplicate Boundary

`QM5_20277` performs one fixed-tail Winsor replacement. `QM5_20282` performs
one median-centered three-raw-MAD cap and equal-weight mean. This EA freezes a
normalized scale but re-centers residual-dependent weights through exactly 32
updates. Median, trimmed mean, quartile trimean, pseudomedian, cumulative,
vote/run, regression, rank, path-efficiency, and skip-month systems use other
functionals or endpoints. The median/MAD definitions, constants, frozen
delta, weight equation, and update count are jointly load-bearing.

## 10. Kill Criteria

Retire below five completed packages per full post-warm-up year, on
nonpositive governed economics, or on later portfolio-correlation rejection.
Fail on endpoint discontinuity, current-month leakage, wrong return
orientation, wrong median/MAD/scale, mutable delta, wrong weights, other-than-
32 updates, wrong-side entry, repeated attempt, missing hard stop, hold beyond
forty days, risk mismatch, or nondeterminism. No post-result rescue parameter
is authorized.

## 11. Safety Boundary

Research, deterministic allocation, build, strict compile/Q01, one fixed-risk
backtest set, and one paced non-live Q02 enqueue only. No manual backtest,
live/demo/shadow/stress/optimization set, `T_Live` access, AutoTrading change,
deploy manifest, portfolio-gate edit, portfolio admission, or correlation
waiver is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-12 | Initial scaffold from approved card | Build pending |
| v2 | 2026-08-12 | Initial V5 implementation and Q01 validation | Strict compile, target build check, P1 artifact validation, and independent Huber vectors PASS |
| v3 | 2026-08-12 | Paced Q02 handoff | One current-binary WTI row enqueued below the path-anchored factory CPU ceiling |

## 12. Q01 Status

PASS. Strict compile completed with zero errors and zero warnings; the target
build check completed with zero failures and zero warnings; P1 artifact
validation found the EA directory and current `.ex5`; and independent vectors
proved return orientation, even median/MAD, fixed Huber updates, sign
divergence from both Winsor and MAD-cap neighbors, exact-zero handling,
zero-MAD fail-closed behavior, and cross-year month continuity. Evidence:

- `D:/QM/reports/compile/20260812_000246/summary.csv`
- `D:/QM/reports/framework/21/build_check_20260812_000245.json`
- `D:/QM/reports/pipeline/QM5_20285/P1/P1_QM5_20285_result.json`
- `framework/EAs/QM5_20285_wti-huber-mom/docs/test_huber_reference.py`

## 13. Q02 Handoff

ENQUEUED. The target-only dry run selected one never-tested priority-track
row for `QM5_20285 / XTIUSD.DWX`. The binding path-anchored capacity sample
found three exact T1-T10 tester processes against the ceiling of seven. The
bounded apply created work item `3e3d87c9-3d4e-4188-8ae6-4840a5259a11` for
Q02. Immediate readback found attempt 0 active on T6 with no verdict; the
resident fleet claimed it without a mission-issued dispatch tick or terminal
launch. This is a handoff, not a Q02 result.
