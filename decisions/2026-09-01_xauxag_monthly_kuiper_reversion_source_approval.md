# XAU/XAG Monthly Kuiper Reversion - Source Approval

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded XAU/XAG structural hypothesis, one Strategy Card, one
  branch build, strict Q01, and one paced non-live logical-basket Q02 enqueue
- Proposed slug: `xauxag-mkuiper-rv`
- Proposed strategy ID: `AI-CODEX-XAUXAG-MKUIPER-RV-20260901_S01`
- Source ID: `AI-CODEX-XAUXAG-MKUIPER-RV-20260901`

## Authority and ordering

The current OWNER mission authorizes one new reputable-source, structural,
low-frequency commodity/energy sleeve and expressly identifies a market-
neutral-style gold/silver ratio basket as eligible. This record approves the
bounded source before card extraction. It does not pre-approve activity,
economics, robustness, decorrelation, portfolio admission, deployment, or
live use.

## Approved source and mechanic

The complete governed source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MKUIPER-RV-20260901/source.md`, with
its prompt/output and retrieval trail beside it. Schweikert (2018), Kuiper
(1960), the official CME ratio record, and the pinned official CRAN
`twosamples` source support only the relationship carrier and the two-sample
distribution-distance arithmetic. The trading conjunction is a pre-result QM
synthesis:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..12
r[i] = q[i+1] - q[i], i=0..11
old = r[0..5]; recent = r[6..11]; require all r pairwise distinct
V = max(F_recent-F_old) + max(F_old-F_recent)
tail_count = count over all C(12,6)=924 labels where V_perm >= V_observed
qualify iff V >= 0.5 and tail_count <= 798
SELL XAU / BUY XAG iff recent pooled-rank sum > 39
BUY XAU / SELL XAG iff recent pooled-rank sum < 39
FLAT otherwise
```

Use thirteen synchronized completed broker-month endpoints, consume one
attempt per month, exact `XAUUSD.DWX`/`XAGUSD.DWX` D1, equal target notionals,
aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, frozen per-leg
`3.5*ATR(20,D1)` hard stops, 1,500/500-point spread ceilings, next-month exit,
and forty-day stale repair.

## Gate decision

| Gate | Verdict | Basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | Durable prompt/output/source record, complete governed peer-reviewed carrier evidence, official exchange carrier evidence, complete Kuiper paper read, and pinned official software source with explicit claim limits. |
| R2 | `PASS` | Exact clock, synchronization, state object, split, ties, statistic, enumeration, boundary, side, attempt, risk, package, and lifecycle. |
| R3 | `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK` | Registered native XAU/XAG D1 history and MT5 state only. |
| R4 | `PASS` | Deterministic bounded arithmetic; no ML, banned signal indicator, external feed, grid, martingale, or scale-in. |

## Duplicate decision

The fail-closed corrected-root receipt
`artifacts/qm5_xauxag_mkuiper_rv_preallocation_dedup_20260901.json`, SHA-256
`CBEA9419A218F75324605F679CEC778FEC42D513A0E6A2E5BB516BAE46A4D5F7`,
returned one same-carrier fuzzy match across 4,762 registry rows, 1,399 cards,
and 45 Wiki nodes, with no exact identity.

Manual review separates the closest monthly XAU/XAG rules. On strict pooled
label path `RROROROOROOR`, this rule has `V=1/2` and qualifies while
`QM5_41187`'s maximum signed KS gap is only `1/3` and
`QM5_41260`'s Anderson-Darling tail is 532, so both are flat. On
`RROROROROORO`, this rule has `V=1/3` and is flat while `QM5_41260` qualifies
at Anderson-Darling tail 428. Complements reverse side without changing these
qualifier disagreements.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_ADJACENT_RATIO_CHANGE_FIXED_SIX_BY_SIX_TWO_SAMPLE_KUIPER_DPLUS_PLUS_DMINUS_EXACT_924_LABEL_HALF_DISTANCE_CONTRARIAN_BASKET`.

## Safety boundary

The 760 directional rank assignments that satisfy the locked boundary imply
`760/77 = 9.87012987` states per twelve combinatorial monthly attempts; this
is a market-free design prior, not a trade, significance, or performance
claim. Q02 must retire below five completed packages in any full post-warm-up
year. Q09 alone owns realized correlation.

Authorized after G0 and clean registries: branch-only build, reference tests,
strict Q01, three fixed-risk basket/component backtest presets, and one paced
logical-basket Q02 enqueue if CPU admission permits. Excluded: manual tester
run, optimization, live/demo/shadow/stress presets, component-leg Q02 rows,
portfolio-gate changes, deploy/live manifests, `T_Live`, AutoTrading,
portfolio admission, and correlation waiver.
