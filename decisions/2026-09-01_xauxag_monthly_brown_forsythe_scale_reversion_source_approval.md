# XAU/XAG Monthly Brown-Forsythe Scale Reversion - Source Approval

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded XAU/XAG structural hypothesis, one Strategy Card, one
  branch build, strict Q01, and one paced non-live logical-basket Q02 enqueue
- Proposed slug: `xauxag-mbf-scale-rv`
- Proposed strategy ID: `AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901_S01`
- Source ID: `AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901`

## Authority And Ordering

The current OWNER mission authorizes one new reputable-source, structural,
low-frequency commodity/energy sleeve and expressly identifies a market-
neutral-style gold/silver ratio-reversion basket as eligible. This record
approves the bounded source before card extraction. It does not pre-approve
activity, economics, robustness, decorrelation, portfolio admission,
deployment, or live use.

## Approved Source And Mechanic

The complete governed source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MBF-SCALE-RV-20260901/source.md`, with
its origin prompt/output and retrieval trail beside it. Schweikert (2018),
Brown and Forsythe (1974), the official CME ratio record, NIST, and signed-
tag-pinned SciPy source support only the relationship carrier and median-
centered scale arithmetic. The trading conjunction is a pre-result QM
synthesis:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..12
r[i] = q[i+1] - q[i], i=0..11
old = r[0..5]; recent = r[6..11]
m_old/m_recent = even medians of the two fixed blocks
z = absolute deviations from each block's own median
compute exact Brown-Forsythe W; require finite nondegenerate arithmetic
qualify iff mean(z_recent) > mean(z_old) beyond relative 1e-12 tolerance
SELL XAU / BUY XAG iff m_recent > m_old beyond tolerance
BUY XAU / SELL XAG iff m_recent < m_old beyond tolerance
FLAT otherwise
```

Use thirteen synchronized completed broker-month endpoints, consume one
attempt per month, exact `XAUUSD.DWX`/`XAGUSD.DWX` D1, equal target notionals,
aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, frozen per-leg
`3.5*ATR(20,D1)` hard stops, 1,500/500-point spread ceilings, next-month exit,
and forty-day stale repair. `W` is a diagnostic arithmetic guard, not an F
critical-value or p-value gate.

## Gate Decision

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | Durable source record, complete governed peer-reviewed carrier evidence, official exchange evidence, named peer-reviewed Brown-Forsythe record with explicit access boundary, complete official NIST formula, and pinned official SciPy source. |
| R2 | `PASS` | Exact clock, synchronization, state object, split, medians, deviations, statistic, scale condition, side, attempt, risk, package, and lifecycle. |
| R3 | `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK` | Registered native XAU/XAG D1 history and MT5 state only. |
| R4 | `PASS` | Deterministic bounded arithmetic; no ML, banned signal indicator, external feed, grid, martingale, or scale-in. |

## Duplicate Decision

The fail-closed corrected-root receipt
`artifacts/qm5_xauxag_mbf_scale_rv_preallocation_dedup_20260901.json` returned
one same-carrier fuzzy match across 4,764 registry rows, 1,401 cards, and 45
Wiki nodes, with no exact identity. Receipt SHA-256:
`9715671276140E339ACBD27B1F855EC12353FF52010448CEE116821FB36CA95F`.

Manual review resolves the closest monthly XAU/XAG rules. `QM5_41260` and
`QM5_41263` discard magnitude into pooled ranks and qualify through full
distribution-path statistics and exact label tails; this source preserves
within-block magnitudes, centers each fixed block separately on its median,
qualifies only recent absolute-deviation expansion, and uses the block-median
shift for side. `QM5_20263` is a daily ratio-level rolling median/MAD fresh
cross, not a fixed monthly two-block scale comparison. `QM5_41247` searches a
chronological CUSUM change point rather than comparing fixed group-specific
median deviations.

Three fixed no-tie fixtures in the source produce Brown-Forsythe-only,
rank-path-only, and opposite-side decisions. Therefore carrier, sample, and
clock overlap do not collapse the decision function into a prior build.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_ADJACENT_RATIO_CHANGE_FIXED_SIX_BY_SIX_BROWN_FORSYTHE_MEDIAN_CENTERED_RECENT_SCALE_EXPANSION_MEDIAN_SHIFT_CONTRARIAN_BASKET`.

## Safety Boundary

Equal-block label-swap symmetry implies approximately six qualifying scale
states per twelve monthly attempts before ties and execution gates. This is a
market-free design prior, not a trade or performance result. Q02 must retire
below five completed packages in every full post-warm-up year. Q09 alone owns
realized correlation.

Authorized after G0 and clean registries: branch-only build, reference tests,
strict Q01, three fixed-risk basket/component backtest presets, and one paced
logical-basket Q02 enqueue if CPU admission permits. Excluded: manual tester
run, optimization, live/demo/shadow/stress presets, component-leg Q02 rows,
portfolio-gate changes, deploy/live manifests, `T_Live`, AutoTrading,
portfolio admission, and correlation waiver.
