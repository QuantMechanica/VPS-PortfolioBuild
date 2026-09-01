# WTI Monthly Lepage Location-Scale Shift Trend - Source Approval

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE_AFTER_MANUAL_DISTINCT_REVIEW`
- Scope: one bounded structural WTI hypothesis, one Strategy Card, one branch
  build, strict Q01, and one paced non-live Q02 enqueue
- Proposed slug: `wti-mlepage-shift-tr`
- Proposed strategy ID: `AI-CODEX-WTI-MLEPAGE-SHIFT-20260901_S01`
- Source ID: `AI-CODEX-WTI-MLEPAGE-SHIFT-20260901`

## Authority And Ordering

The current OWNER mission authorizes one new reputable-source, structural,
low-frequency commodity/energy sleeve and expressly identifies direct WTI
trend or seasonality as eligible. This durable record approves the bounded
source before Strategy Card extraction. It does not pre-approve activity,
economics, robustness, realized decorrelation, portfolio admission,
deployment, or live use.

## Approved Source And Mechanic

The complete governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MLEPAGE-SHIFT-20260901/source.md`, with
its origin prompt/output and retrieval record beside it. Moskowitz, Ooi, and
Pedersen (2012), Lepage (1971), the complete Hussain and Tsagris (2025)
preprint, and complete CRAN `LePage` 1.0 source support only the WTI
continuation carrier and classical joint location-scale rank arithmetic. The
trading conjunction is pre-result QM synthesis:

```text
51 completed WTI D1 closes -> 50 adjacent log returns
old = first 25; recent = last 25; require all 50 returns distinct
rank the pooled returns 1..50
W = sum(recent pooled ranks)
A = sum(min(rank, 51-rank) for recent ranks)
L = (W-637.5)^2/2656.25 + (A-325)^2/(32500/49)
qualify joint location-scale shift iff L>=1.3862943611198906
BUY iff sum(recent)>+1e-12; SELL iff sum(recent)<-1e-12; FLAT otherwise
```

Use exact `XTIUSD.DWX` D1, one consumed attempt per broker month, fixed
`RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen `3.5*ATR(20,D1)` hard stop, a
1,500-point spread ceiling, next-month exit, and forty-day stale repair. The
chi-square-two median is a disclosed activity gate, not a conventional
significance or efficacy claim.

## Gate Decision

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | Durable AI prompt/output/source trail; complete-read peer-reviewed WTI carrier evidence; original Lepage publisher metadata with body-access boundary; complete 20-page author preprint and complete official CRAN 1.0 source. |
| R2 | `PASS` | Exact month clock, close/return blocks, strict ranks, two component moments, joint statistic, threshold, direction, attempt, risk, stop, spread, and lifecycle are fixed. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native WTI D1 history and MT5 state only. |
| R4 | `PASS` | Deterministic bounded sorting/rank arithmetic; no ML, banned signal indicator, external feed, grid, martingale, or scale-in. |

## Duplicate Decision

The fail-closed corrected-root receipt
`artifacts/qm5_wti_mlepage_shift_tr_preallocation_dedup_20260901.json`,
SHA-256
`FFF74031E1A7636A78816E6EB0AB67B6CA2731467577CA4D656D96A4B52C2A97`,
checked 4,769 registry rows, 1,406 cards, and 45 Wiki nodes. It returned one
fuzzy match at score `0.6666666666666666`, `QM5_41268_wti-mepps-shift-tr`,
and therefore correctly required manual review.

The match is not the same mechanic. `QM5_41268` constructs trigonometric
empirical-characteristic-function features, biased within-block covariance,
a pooled 4x4 covariance, and a guarded matrix inverse. This source uses no
Fourier feature, scale estimate, covariance, matrix inverse, or value spacing
after ranking. It combines the standardized pooled-rank Wilcoxon location
component and symmetric end-rank Ansari-Bradley scale component. A fixed rank
fixture with recent ranks
`{1,2,4,5,7,8,9,10,12,13,16,23,25,28,29,30,34,37,38,39,40,41,43,45,48}`
has component squares `0.9600941176470589` and `1.356923076923077`; neither
alone reaches the gate, while their joint Lepage statistic
`2.317017194570136` qualifies. This joint ordinal state cannot be reduced to
the Epps-Singleton ECF/covariance state.

The nearest single-axis builds are also distinct:

- `QM5_41176` applies a six-by-six Mann-Whitney location threshold to twelve
  completed monthly endpoint prices, not fifty daily returns and not a joint
  location-scale statistic.
- `QM5_41261` applies a six-by-six Ansari-Bradley lower-tail boundary to twelve
  completed monthly returns, not a standardized joint statistic.
- `QM5_41266` and `QM5_41267` are scale-only monthly-return gates; neither can
  qualify from combined sub-threshold location and scale evidence.

Manual verdict:
`DISTINCT_WTI_MONTHLY_FIXED_25_BY_25_DAILY_RETURN_LEPAGE_JOINT_WILCOXON_ANSARI_BRADLEY_LOCATION_SCALE_CHI_SQUARE_TWO_MEDIAN_GATE_RECENT_RETURN_CONTINUATION`.

## Safety Boundary

The asymptotic chi-square-two median implies a rough six-state-per-year prior
before dependence, strict-tie, direction, data, and execution gates. It is
not a WTI trade-count or performance result. Q02 must retire the candidate if
any full post-warm-up year has fewer than five completed positions. Q09 alone
owns realized portfolio correlation.

Authorized after G0 and clean registries: branch-only build, deterministic
reference tests, strict Q01, one fixed-risk WTI backtest preset, and one paced
non-live Q02 enqueue if CPU admission permits. Excluded: manual tester run,
optimization, live/demo/shadow/stress presets, portfolio-gate changes,
deploy/live manifests, `T_Live`, AutoTrading, portfolio admission, and any
correlation waiver.
