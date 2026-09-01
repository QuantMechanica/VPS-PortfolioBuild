# WTI Monthly Mood Squared-Rank Scale Trend - Source Approval

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural WTI hypothesis, one Strategy Card, one branch
  build, strict Q01, and one paced non-live Q02 enqueue
- Proposed slug: `wti-mmood-scale-tr`
- Proposed strategy ID: `AI-CODEX-WTI-MMOOD-SCALE-20260901_S01`
- Source ID: `AI-CODEX-WTI-MMOOD-SCALE-20260901`

## Authority And Ordering

The current OWNER mission authorizes one new reputable-source, structural,
low-frequency commodity/energy sleeve and expressly identifies direct WTI
trend or seasonality as eligible. This durable record approves the bounded
source before card extraction. It does not pre-approve activity, economics,
robustness, decorrelation, portfolio admission, deployment, or live use.

## Approved Source And Mechanic

The complete governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MMOOD-SCALE-20260901/source.md`, with its
origin prompt/output and retrieval record beside it. Moskowitz, Ooi, and
Pedersen (2012), Mood (1954), and signed-tag-pinned official SciPy evidence
support only the WTI monthly continuation carrier and squared-rank scale
arithmetic. The trading conjunction is pre-result QM synthesis:

```text
r[i] = ln(C[i+1]/C[i]), i=0..11, from 13 completed WTI month ends
old = r[0..5]; recent = r[6..11]
pool raw returns; reject any anchored relative-1e-12 tie
assign ranks 1..12; require rank sum 78
M_old = sum((R_old-6.5)^2)
E0=71.5; Var0=364; z=(M_old-E0)/sqrt(Var0)
qualify recent scale non-contraction iff M_old <= 71.5
BUY iff sum(recent)>+1e-12; SELL iff sum(recent)<-1e-12; FLAT otherwise
```

Use exact `XTIUSD.DWX` D1, one consumed attempt per broker month, fixed
`RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen `3.5*ATR(20,D1)` hard stop, a
1,500-point spread ceiling, next-month exit, and forty-day stale repair. The
standardized statistic is a fail-closed arithmetic diagnostic, not a normal-
probability, p-value, significance, or risk-scaling gate.

## Gate Decision

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | Durable AI prompt/output/source trail, complete-read peer-reviewed WTI carrier evidence, named peer-reviewed Mood record with explicit body-access boundary, and complete signed-tag-pinned official SciPy method/source evidence. |
| R2 | `PASS` | Exact clock, endpoints, returns, fixed membership, anchored tie rejection, ranks, score, expectation, variance, inclusive gate, side, attempt, risk, stop, spread, and lifecycle. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native WTI D1 history and MT5 state only. |
| R4 | `PASS` | Deterministic bounded arithmetic; no ML, banned signal indicator, external feed, grid, martingale, or scale-in. |

## Duplicate Decision

The fail-closed corrected-root receipt
`artifacts/qm5_wti_mmood_scale_tr_preallocation_dedup_20260901.json`, SHA-256
`CFE1AC425C20CD89B2196F25432B2E5640D3D5F44618BE182F8F7207BA77CA5F`,
returned no exact identity and the expected fuzzy `QM5_41261` and
`QM5_41266` matches across 4,766 registry rows, 1,403 cards, and 45 Wiki
nodes.

Manual review resolves both. Ansari-Bradley assigns symmetric end weights to
raw ranks and gates on an exact label tail. Fligner-Killeen ranks block-
median absolute deviations and maps them to normal scores. Mood instead uses
one pooled raw-return rank assignment, squares distances from rank center,
and compares its first-group score with a fixed expectation; it neither
centers returns nor enumerates a permutation tail. The two fixed fixtures in
the source prove decision disagreement in both directions while both closest
other neighbors remain flat.

Verdict:
`FUZZY_NEIGHBORS_RESOLVED_DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_RAW_RETURN_POOLED_INTEGER_RANK_MOOD_SQUARED_RANK_RECENT_SCALE_NONCONTRACTION_CUMULATIVE_RETURN_CONTINUATION`.

## Safety Boundary

Of 924 unique-rank label assignments, 498 qualify the inclusive
non-contraction state, giving an approximately 6.47-per-year pre-result prior
before neutral direction, data, and execution gates. It is not a market
trade-count or performance result. Q02 must retire below five completed
positions in any full post-warm-up year. Q09 alone owns realized portfolio
correlation.

Authorized after G0 and clean registries: branch-only build, reference tests,
strict Q01, one fixed-risk WTI backtest preset, and one paced Q02 enqueue if
CPU admission permits. Excluded: manual tester run, optimization,
live/demo/shadow/stress presets, portfolio-gate changes, deploy/live
manifests, `T_Live`, AutoTrading, portfolio admission, and correlation waiver.

