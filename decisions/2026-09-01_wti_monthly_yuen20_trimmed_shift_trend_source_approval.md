# WTI Monthly Yuen20 Trimmed-Shift Trend - Source Approval

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural WTI hypothesis, one Strategy Card, one branch
  build, strict Q01, and one paced non-live Q02 enqueue
- Proposed slug: `wti-myuen20-shift-tr`
- Proposed strategy ID: `AI-CODEX-WTI-MYUEN20-20260901_S01`
- Source ID: `AI-CODEX-WTI-MYUEN20-20260901`

## Authority and ordering

The current OWNER mission authorizes one new reputable-source, structural,
low-frequency commodity/energy sleeve and expressly identifies direct WTI
trend or seasonality as eligible. This durable record approves the bounded
source before card extraction. It does not pre-approve activity, economics,
robustness, decorrelation, portfolio admission, deployment, or live use.

## Approved source and mechanic

The complete governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MYUEN20-20260901/source.md`, with its
prompt/output and retrieval trail beside it. Moskowitz, Ooi, and Pedersen
(2012), Yuen (1974), and official pinned SciPy evidence support only the WTI
monthly continuation carrier and the robust unequal-variance trimmed-location
arithmetic. The trading conjunction is pre-result QM synthesis:

```text
21 completed WTI month ends -> 20 adjacent log returns
old = returns 0..9; recent = returns 10..19
sort each block; g=2; h=6
trimmed mean = mean of order statistics 3..8
Winsorize two values at each tail to order statistics 3 and 8
Winsorized variance divisor = h-1 = 5
t = (trimmed_recent-trimmed_old) / sqrt(wvar_old/6+wvar_recent/6)
BUY at t >= +0.75; SELL at t <= -0.75; FLAT otherwise
```

Use exact `XTIUSD.DWX` D1, one consumed attempt per broker month, fixed
`RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen `3.5*ATR(20,D1)` hard stop, a
1,500-point spread ceiling, next-month exit, and forty-day stale repair.

## Gate decision

| Gate | Verdict | Basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | Durable AI prompt/output/source trail, complete-read peer-reviewed WTI carrier evidence, named peer-reviewed Yuen record with access boundary, and complete official SciPy method/source evidence. |
| R2 | `PASS` | Exact clock, endpoints, return orientation, fixed blocks, trim, Winsorization, variance divisor, denominator, boundary, side, attempt, risk, stop, spread, and lifecycle. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native WTI D1 history and MT5 state only. |
| R4 | `PASS` | Deterministic bounded arithmetic; no ML, banned signal indicator, external feed, grid, martingale, or scale-in. |

## Duplicate decision

The fail-closed corrected-root receipt
`artifacts/qm5_wti_myuen20_shift_tr_preallocation_dedup_20260901.json`, SHA-256
`8D33C19E0A75BEFCCCDF8778DD44C89A844DAE48E0FCF64E7D37520BD3C26ED7`,
returned no exact identity and one expected fuzzy match across 4,763 registry
rows, 1,400 cards, and 45 Wiki nodes.

Manual review resolves `QM5_41249`: it uses raw six/six means and ordinary
variances plus recent-mean sign agreement. This candidate uses ten/ten
blocks, deletes two values per tail from each location, Winsorizes two values
per tail for each scale, uses effective trimmed size six, and follows the
trimmed-location shift. Two locked fixtures in the source prove decision
disagreement in both qualification directions.

Verdict:
`FUZZY_WELCH_RESOLVED_DISTINCT_WTI_MONTHLY_FIXED_TEN_BY_TEN_YUEN20_TRIMMED_LOCATION_UNEQUAL_WINSORIZED_SCALE_SHIFT_CONTINUATION`.

## Safety boundary

The `0.75` score is an activity boundary, not a significance claim. Retire on
zero trades or below five completed positions in any full post-warm-up year.
Q02 owns activity and economics; unchanged Q09 alone owns realized portfolio
correlation.

Authorized after G0 and clean registries: branch-only build, reference tests,
strict Q01, one fixed-risk WTI backtest preset, and one paced Q02 enqueue if
CPU admission permits. Excluded: manual tester run, optimization,
live/demo/shadow/stress presets, portfolio-gate changes, deploy/live manifests,
`T_Live`, AutoTrading, portfolio admission, and correlation waiver.
