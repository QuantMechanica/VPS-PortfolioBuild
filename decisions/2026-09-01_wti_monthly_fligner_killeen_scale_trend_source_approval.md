# WTI Monthly Fligner-Killeen Scale Trend - Source Approval

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural WTI hypothesis, one Strategy Card, one branch
  build, strict Q01, and one paced non-live Q02 enqueue
- Proposed slug: `wti-mfk-scale-tr`
- Proposed strategy ID: `AI-CODEX-WTI-MFK-SCALE-20260901_S01`
- Source ID: `AI-CODEX-WTI-MFK-SCALE-20260901`

## Authority And Ordering

The current OWNER mission authorizes one new reputable-source, structural,
low-frequency commodity/energy sleeve and expressly identifies direct WTI
trend or seasonality as eligible. This durable record approves the bounded
source before card extraction. It does not pre-approve activity, economics,
robustness, decorrelation, portfolio admission, deployment, or live use.

## Approved Source And Mechanic

The complete governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MFK-SCALE-20260901/source.md`, with its
origin prompt/output and retrieval record beside it. Moskowitz, Ooi, and
Pedersen (2012), Fligner and Killeen (1976), and signed-tag-pinned official
SciPy evidence support only the WTI monthly continuation carrier and the
median-centered normal-score scale arithmetic. The trading conjunction is a
pre-result QM synthesis:

```text
r[i] = ln(C[i+1]/C[i]), i=0..11, from 13 completed WTI month ends
old = r[0..5]; recent = r[6..11]
z = absolute deviation from each block's own even median
pool z; assign deterministic midranks R
a(R) = Phi^-1(0.5 + R/(2*13))
compute finite, nondegenerate two-group Fligner-Killeen statistic
qualify iff mean(a_recent) > mean(a_old) beyond relative 1e-12 tolerance
BUY iff sum(recent)>+1e-12; SELL iff sum(recent)<-1e-12; FLAT otherwise
```

Use exact `XTIUSD.DWX` D1, one consumed attempt per broker month, fixed
`RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen `3.5*ATR(20,D1)` hard stop, a
1,500-point spread ceiling, next-month exit, and forty-day stale repair. The
statistic is a fail-closed arithmetic diagnostic, not a chi-square critical-
value, p-value, significance, or risk-scaling gate.

## Gate Decision

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | Durable AI prompt/output/source trail, complete-read peer-reviewed WTI carrier evidence, named peer-reviewed Fligner-Killeen record with explicit full-body access boundary, and complete signed-tag-pinned official SciPy method/source evidence. |
| R2 | `PASS` | Exact clock, endpoints, returns, fixed membership, even medians, deviations, midranks, normal scores, statistic, scale direction, trade side, attempt, risk, stop, spread, and lifecycle. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native WTI D1 history and MT5 state only. |
| R4 | `PASS` | Deterministic bounded arithmetic; no ML, banned signal indicator, external feed, grid, martingale, or scale-in. |

## Duplicate Decision

The fail-closed corrected-root receipt
`artifacts/qm5_wti_mfk_scale_tr_preallocation_dedup_20260901.json`, SHA-256
`26F24CE6AB0AA859ACC4B6711B1F4DD2C07DDBD33744CB078F623DBFE031AF70`,
returned no exact identity and one expected fuzzy match across 4,765 registry
rows, 1,402 cards, and 45 Wiki nodes.

Manual review resolves `QM5_41261_wti-mab-scale-tr`. Ansari-Bradley ranks the
raw returns once, assigns symmetric end ranks `1,2,3,4,5,6,6,5,4,3,2,1`,
enumerates all 924 six-label allocations, and qualifies a recent low score
tail. This candidate first subtracts each block's own median, ranks the pooled
absolute deviations with ties retained as midranks, maps those ranks through
fixed normal scores, and qualifies only a higher recent mean score. It has no
924-label tail gate. `QM5_41250` recomputes raw median absolute deviations
for all 924 label allocations and applies an upper-tail cap; this candidate
never relabels observations and preserves the pooled normal-score path.

Two fixed raw-return fixtures prove decision disagreement:

```text
FK-only:
[6.75,-4.25,0.50,5.00,7.50,4.50 | -3.00,-3.25,6.25,-6.25,2.50,-2.75]
A_old/A_recent = 0.7476358421 / 0.7715454367; FK X2 = 0.0064536333
=> FK qualifies SELL; Ansari-Bradley score 22 is flat; permutation-MAD
   recent-minus-old = -0.50 is flat.

Neighbor-only:
[5.25,-1.75,-6.75,3.50,-4.50,7.50 | 6.25,4.25,-6.25,0.25,7.75,-2.00]
A_old/A_recent = 0.8197335318 / 0.6994477469; FK X2 = 0.1633384683
=> FK flat; Ansari-Bradley score 21 qualifies BUY; permutation-MAD is flat.
```

Verdict:
`FUZZY_ANSARI_BRADLEY_RESOLVED_DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_GROUP_MEDIAN_ABSOLUTE_DEVIATION_POOLED_MIDRANK_NORMAL_SCORE_FLIGNER_KILLEEN_RECENT_SCALE_EXPANSION_CUMULATIVE_RETURN_CONTINUATION`.

## Safety Boundary

Swapping equal old/recent labels swaps the two group score means. Across all
924 six-label assignments of twelve distinct ranks, exactly 462 place the
recent score above the older score. That gives an approximately six-per-year
market-free activity prior before deviation ties, neutral direction, data,
and execution gates. It is not a market trade-count or performance result.
Q02 must retire below five completed positions in every full post-warm-up
year. Q09 alone owns realized portfolio correlation.

Authorized after G0 and clean registries: branch-only build, reference tests,
strict Q01, one fixed-risk WTI backtest preset, and one paced Q02 enqueue if
CPU admission permits. Excluded: manual tester run, optimization,
live/demo/shadow/stress presets, portfolio-gate changes, deploy/live
manifests, `T_Live`, AutoTrading, portfolio admission, and correlation waiver.

