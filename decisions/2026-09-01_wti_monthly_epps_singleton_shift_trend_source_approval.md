# WTI Monthly Epps-Singleton Distribution-Shift Trend - Source Approval

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural WTI hypothesis, one Strategy Card, one branch
  build, strict Q01, and one paced non-live Q02 enqueue
- Proposed slug: `wti-mepps-shift-tr`
- Proposed strategy ID: `AI-CODEX-WTI-MEPPS-SHIFT-20260901_S01`
- Source ID: `AI-CODEX-WTI-MEPPS-SHIFT-20260901`

## Authority And Ordering

The current OWNER mission authorizes one new reputable-source, structural,
low-frequency commodity/energy sleeve and expressly identifies direct WTI
trend or seasonality as eligible. This durable record approves the bounded
source before card extraction. It does not pre-approve activity, economics,
robustness, decorrelation, portfolio admission, deployment, or live use.

## Approved Source And Mechanic

The complete governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MEPPS-SHIFT-20260901/source.md`, with its
origin prompt/output and retrieval record beside it. Moskowitz, Ooi, and
Pedersen (2012), Epps and Singleton (1986), and signed-tag-pinned official
SciPy evidence support only the WTI continuation carrier and empirical-
characteristic-function two-sample arithmetic. The trading conjunction is
pre-result QM synthesis:

```text
51 completed WTI D1 closes -> 50 adjacent log returns
old = first 25; recent = last 25
sigma = pooled semi-IQR; t=(0.4,0.8)/sigma
g=[cos(t1*r),cos(t2*r),sin(t1*r),sin(t2*r)]
est_cov=2*biased_cov(old)+2*biased_cov(recent)
W=50*(mean_old-mean_recent)'*inverse(est_cov)*(mean_old-mean_recent)
qualify full-rank distribution shift iff W>=3.356693980033321
BUY iff sum(recent)>+1e-12; SELL iff sum(recent)<-1e-12; FLAT otherwise
```

Use exact `XTIUSD.DWX` D1, one consumed attempt per broker month, fixed
`RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen `3.5*ATR(20,D1)` hard stop, a
1,500-point spread ceiling, next-month exit, and forty-day stale repair. The
chi-square-four median threshold is a disclosed activity gate, not a
conventional significance or efficacy claim.

## Gate Decision

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | Durable AI prompt/output/source trail, complete-read peer-reviewed WTI carrier evidence, named peer-reviewed Epps-Singleton record with explicit body-access boundary, and complete signed-tag-pinned official SciPy method/source evidence. |
| R2 | `PASS` | Exact clock, close/return blocks, percentile convention, Fourier features, covariance, inverse guards, statistic, threshold, side, attempt, risk, stop, spread, and lifecycle. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native WTI D1 history and MT5 state only. |
| R4 | `PASS` | Deterministic bounded arithmetic; no ML, banned signal indicator, external feed, grid, martingale, or scale-in. |

## Duplicate Decision

The fail-closed corrected-root receipt
`artifacts/qm5_wti_mepps_shift_tr_preallocation_dedup_20260901.json`, SHA-256
`239D9D85B296F529E01D092031C1457E92E263259B2CEC5879577B5FC460CF69`,
returned CLEAN across 4,767 registry rows, 1,404 cards, and 45 Wiki nodes.

Manual review also separates this daily-return ECF/covariance quadratic form
from the existing monthly Cramer-von Mises, energy-distance, Wasserstein,
mean-location, pooled-rank scale, change-point, and raw-momentum builds.
Verdict:
`CLEAN_DISTINCT_WTI_MONTHLY_FIXED_25_BY_25_DAILY_RETURN_EPPS_SINGLETON_ECF_DISTRIBUTION_SHIFT_MEDIAN_GATE_RECENT_RETURN_CONTINUATION`.

## Safety Boundary

The full-rank chi-square-four median implies a rough six-state-per-year
asymptotic prior before dependence, direction, data, and execution gates. It
is not a WTI trade-count or performance result. Q02 must retire below five
completed positions in any full post-warm-up year. Q09 alone owns realized
portfolio correlation.

Authorized after G0 and clean registries: branch-only build, reference tests,
strict Q01, one fixed-risk WTI backtest preset, and one paced Q02 enqueue if
CPU admission permits. Excluded: manual tester run, optimization,
live/demo/shadow/stress presets, portfolio-gate changes, deploy/live
manifests, `T_Live`, AutoTrading, portfolio admission, and correlation waiver.

