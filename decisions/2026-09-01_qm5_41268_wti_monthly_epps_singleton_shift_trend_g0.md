# QM5_41268 WTI Monthly Epps-Singleton Distribution-Shift Trend - G0

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Verdict: `APPROVED`
- EA identity: `QM5_41268_wti-mepps-shift-tr`
- Strategy ID: `AI-CODEX-WTI-MEPPS-SHIFT-20260901_S01`
- Approved card:
  `strategy-seeds/cards/approved/QM5_41268_wti-mepps-shift-tr_card.md`
- Source approval:
  `decisions/2026-09-01_wti_monthly_epps_singleton_shift_trend_source_approval.md`
- Source approval commit: `9245d4e12e`
- EA-ID allocation commit: `6e20f5cf10`

## Authority And Scope

The current explicit OWNER mission authorizes one new, non-duplicate,
structural low-frequency commodity/energy sleeve, identifies direct WTI trend
or seasonality as eligible, requires reputable-source criteria and fixed-risk
backtest setfiles, and asks for one Q02 enqueue. This G0 approves the exact
card for build, deterministic reference tests, strict Q01, and one paced
non-live Q02 handoff if whole-host CPU remains below the stated ceiling.

It does not pre-approve activity, economics, robustness, decorrelation,
portfolio admission, deployment, or live use.

## Locked Hypothesis

At the first executable D1 bar of a new normalized broker month:

1. reconstruct fifty-one completed WTI D1 closes and fifty adjacent log
   returns;
2. split returns chronologically into fixed old/recent blocks of twenty-five;
3. compute the source-default Epps-Singleton four-feature statistic using
   pooled linear semi-IQR scaling, biased covariances, and a guarded full-rank
   inverse;
4. require `W>=3.356693980033321`, the chi-square-four median;
5. continue the sign of the recent twenty-five-return sum for one broker
   month; and
6. use one fixed-risk, stop-protected WTI position with no intramonth flip.

The median gate, fixed blocks, full-rank-only inverse, direction, CFD carrier,
risk, and lifecycle are pre-result QM choices. No source reports this exact
strategy.

## R1-R4 Verdict

| gate | verdict | reason |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | One approved governed AI source contains the origin trail, complete-read MOP WTI carrier packet, Epps-Singleton publisher/author record with explicit body-access boundary, and complete signed-tag-pinned SciPy documentation/source. |
| R2 | `PASS` | Exact clock, data, percentiles, Fourier features, covariance, inverse, statistic gate, side, attempt, fixed risk, hard stop, spread, and lifecycle are locked. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Exact registered `XTIUSD.DWX` D1 history plus native MT5 state supplies every runtime input. |
| R4 | `PASS` | Deterministic closed-form native arithmetic, one position per magic, no ML, prohibited signal indicator, external runtime feed, grid, martingale, scale-in, or randomization. |

## Source And Claim Boundary

Moskowitz, Ooi, and Pedersen support only broad own-return continuation and
explicit WTI membership. Epps-Singleton and official pinned SciPy evidence
support only the two-sample empirical-characteristic-function arithmetic and
reference distribution. The paper body access limit is explicit and no
hidden formula or result is inferred.

No source efficacy, WTI-only alpha, p-value, frequency, CFD equivalence,
profit factor, drawdown, cost, correlation, or portfolio statistic transfers.

## Duplicate Verdict

The fail-closed corrected-root receipt
`artifacts/qm5_wti_mepps_shift_tr_preallocation_dedup_20260901.json`, SHA-256
`239D9D85B296F529E01D092031C1457E92E263259B2CEC5879577B5FC460CF69`,
returned CLEAN across 4,767 registry rows, 1,404 cards, and 45 Wiki nodes.

Manual review separates this fixed daily-return ECF/covariance quadratic form
from monthly empirical-CDF, energy-distance, Wasserstein, raw mean-location,
rank-scale, change-point, and unconditional momentum implementations.

Verdict:
`CLEAN_DISTINCT_WTI_MONTHLY_FIXED_25_BY_25_DAILY_RETURN_EPPS_SINGLETON_ECF_DISTRIBUTION_SHIFT_MEDIAN_GATE_RECENT_RETURN_CONTINUATION`.

## Frequency Prior And Falsification

The chi-square-four median gives a rough one-half asymptotic state prior, or
about six monthly states per year before dependent overlap, neutral direction,
data, rank, and execution gates. This is not a market measurement. Q02 must
retire the candidate below five completed positions in any full post-warm-up
year or on nonpositive governed economics. No statistic, threshold, block,
direction, risk, or hold rescue is authorized.

## Build Authorization

Development may build exactly the approved card after governed magic slot 0
exists. Required deliverables are:

1. `framework/EAs/QM5_41268_wti-mepps-shift-tr/` with a card-of-record copy;
2. exact slot-zero magic `412680000` for `XTIUSD.DWX` and regenerated resolver;
3. one structural `.mq5`, reference parity tests, `SPEC.md`, and one D1
   `RISK_FIXED=1000` backtest setfile;
4. card/schema/build guards and strict governed Q01 compile PASS; and
5. one paced Q02 work item only if a fresh five-sample whole-host CPU maximum
   remains below 97 percent.

Excluded: manual tester launch, optimization, live/demo/shadow/stress presets,
portfolio-gate edits, correlation waiver, portfolio admission, deploy/live
manifest, `T_Live`, and AutoTrading.

## Safety Boundary

G0 authorizes build and non-live pipeline handoff only. Q02 owns activity and
economics, later unchanged gates own robustness, and Q09 alone may establish
realized decorrelation. No live or portfolio authority is created here.

