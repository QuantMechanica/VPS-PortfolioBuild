# QM5_20288_wti-volnorm-mom — Strategy Spec

**EA ID:** QM5_20288
**Slug:** `wti-volnorm-mom`
**Source:** `MOP-WTI-VOLNORM-2026` (see
`strategy-seeds/sources/MOP-WTI-VOLNORM-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-12

---

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, reconstruct
thirteen consecutive completed WTI month-end closes and every completed daily
close-to-close log return connecting them. For each of the twelve month
intervals, divide the endpoint return by the L2 norm of that month's undemeaned
daily-return path. Give each normalized month one-twelfth weight. Buy for a
positive mean and sell for a negative mean; exact zero or invalid state
consumes the month flat. Every entry has a frozen `3.5 * ATR(20,D1)` hard stop,
no take-profit, monthly renewal, and a forty-day stale exit.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_months` | `12` | `[12]` | Fixed normalized broker-month intervals |
| `strategy_min_daily_returns` | `15` | `[15]` | Minimum daily returns per interval |
| `strategy_max_daily_returns` | `25` | `[25]` | Maximum daily returns per interval |
| `strategy_endpoint_tolerance` | `1e-10` | `[1e-10]` | Daily-sum versus endpoint identity tolerance |
| `strategy_history_bars_d1` | `800` | `[800]` | Bounded D1 path reconstruction |
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
| Multi-timeframe refs | Completed broker-month paths reconstructed from D1; `ATR(20,D1)` |
| Bar gating | One `QM_IsNewBar()` consume, then broker-month transition check |

The current broker month contributes no signal endpoint or daily return.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11–12 after thirteen completed month ends; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Expected drawdown profile | Sparse fixed-risk WTI trend losses with gap and delayed-reversal exposure |
| Regime preference | Broad crude-oil direction repeated across independently normalized months |
| Win rate target | Low to medium; expectancy must come from slow trend packages |

The WTI carrier and volatility-normalized statistic are diversification
hypotheses only. Q09 owns any realized portfolio-overlap conclusion.

## 6. Source Citation

**Source ID:** `MOP-WTI-VOLNORM-2026`
**Source type:** peer-reviewed trading paper with bounded QM statistical
mechanization
**Pointer:** `strategy-seeds/sources/MOP-WTI-VOLNORM-2026/source.md`
**R1–R4 verdict (G0):** all PASS; see
`strategy-seeds/cards/approved/QM5_20288_wti-volnorm-mom_card.md`

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, establishes the broad monthly own-price trend
family, uses volatility scaling, and includes WTI. The historical within-month
L2 normalization is a locked QM hypothesis; the paper does not test it.

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

For thirteen positive finite completed month-end closes and their daily paths:

```text
d[m,j] = ln(P[m,j+1] / P[m,j])
r[m]   = sum_j d[m,j]
e[m]   = ln(C[m+1] / C[m])
v[m]   = sqrt(sum_j d[m,j]^2)
u[m]   = r[m] / v[m]
score  = sum_m u[m] / 12
```

Every interval requires fifteen to twenty-five returns, positive `v[m]`, and
`abs(r[m]-e[m]) <= 1e-10`. Buy for `score > 0`, sell for `score < 0`, and
consume exact zero or invalid state flat. Do not demean, annualize, clip,
threshold, vote, or scale trade risk by the score.

## 9. Non-Duplicate Boundary

`QM5_20274` uses one twelve-month net return divided by the L1 sum of twelve
absolute monthly returns and applies a threshold. This EA forms twelve
separate monthly endpoint-over-daily-L2 ratios, weights them equally, and has
no signal threshold. WTI variance-ratio builds estimate fixed-horizon memory;
`QM5_13049` separately gates five-day momentum on low volatility. Robust-
location, cumulative, regression, rank, block, sign/run/vote, recency, and
skip-month systems use other observation objects or weights. The separate
daily path per month, L2 denominator, endpoint identity, equal month weights,
and final mean sign are load-bearing.

## 10. Kill Criteria

Retire below five completed packages per full post-warm-up year, on
nonpositive governed economics, or on later portfolio-correlation rejection.
Fail on endpoint discontinuity, current-month leakage, wrong daily-return
orientation, overlap/omission, interval count outside fifteen to twenty-five,
demeaning/annualization, nonpositive L2 norm, endpoint identity failure,
unequal weights, an alternate threshold/statistic, wrong-side entry, repeated
attempt, missing hard stop, hold beyond forty days, risk mismatch, or
nondeterminism. No post-result rescue parameter is authorized.

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
| v2 | 2026-08-12 | Initial V5 implementation and Q01 validation | Strict compile, target build check, P1 artifact validation, and independent volatility-normalized statistic vectors PASS |
| v3 | 2026-08-12 | Paced Q02 handoff | One current-binary WTI row enqueued below the path-anchored factory CPU ceiling |

## 12. Q01 Status

PASS. Strict compile completed with zero errors and zero warnings; the target
build check completed with zero failures and zero warnings; P1 artifact
validation found the EA directory and current `.ex5`; and independent vectors
proved positive, negative, and exact-zero direction, within-month L2 scale
invariance, one-shock equalization against eleven smooth opposite months,
endpoint-identity rejection, interval-count bounds, and zero-norm rejection.
Evidence:

- `D:/QM/reports/compile/20260812_060749/summary.csv`
- `D:/QM/reports/framework/21/build_check_20260812_060748.json`
- `D:/QM/reports/pipeline/QM5_20288/P1/P1_QM5_20288_result.json`
- `framework/EAs/QM5_20288_wti-volnorm-mom/docs/test_volnorm_reference.py`

## 13. Q02 Handoff

ENQUEUED. The target-only dry run selected one never-tested priority-track row
for `QM5_20288 / XTIUSD.DWX`. The binding path-anchored capacity sample found
three exact T1-T10 tester processes against the ceiling of seven. The bounded
apply created work item `9714bc6b-d11d-485e-b359-6e6cfa2c2ec5` for Q02.
Immediate readback found attempt 0 pending and unclaimed with no verdict. No
dispatch tick, terminal launch, or manual backtest was issued by this mission.
This is a handoff, not a Q02 result.
