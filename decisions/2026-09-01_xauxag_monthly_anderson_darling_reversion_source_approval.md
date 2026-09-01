# XAU/XAG Monthly Anderson-Darling Reversion - Source Approval

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded XAU/XAG market-neutral-style structural-reversion
  hypothesis, one Strategy Card, one branch build, strict Q01, and one paced
  non-live Q02 enqueue
- Proposed strategy ID: `AI-CODEX-XAUXAG-MAD2-RV-20260901_S01`
- Source ID: `AI-CODEX-XAUXAG-MAD2-RV-20260901`

## Authority And Ordering

The current explicit OWNER mission authorizes one new reputable-source,
structural low-frequency commodity sleeve outside the certified directional
XAU/SP500/NDX/XNG book, identifies a market-neutral gold/silver basket as an
eligible route, requires fixed-risk backtesting, and requests Q02 enqueue.
This durable record approves the bounded source before Strategy Card
extraction. It does not pre-approve economics, robustness, realized
decorrelation, portfolio admission, deployment, or live use.

## Approved Source Record

The complete bounded source is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MAD2-RV-20260901/source.md`. Its
supporting evidence is:

1. Schweikert (2018), *Are gold and silver cointegrated?*, *Journal of
   Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`; complete governed packet
   `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
   `7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`.
2. CME Group, *Gold & Silver Ratio Spread*; official governed packet
   `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.
3. Scholz and Stephens (1987), *K-Sample Anderson-Darling Tests*, *Journal of
   the American Statistical Association* 82(399), 918-924, DOI
   `10.1080/01621459.1987.10478517`; complete article retrieval and SHA-256
   receipt in
   `strategy-seeds/sources/AI-CODEX-XAUXAG-MAD2-RV-20260901/retrieval_route_scholz_stephens_adk_20260901.json`.
4. SciPy 1.13.1 official `anderson_ksamp` documentation and pinned source at
   commit `44e4ebaac992fde33f04638b99629d23973cb9b2`; receipt in
   `strategy-seeds/sources/AI-CODEX-XAUXAG-MAD2-RV-20260901/retrieval_route_scipy_anderson_ksamp_20260901.json`.

The relationship and exchange records support the carrier only. The method
records support the continuous no-tie pooled-rank statistic, tail weighting,
and rank-permutation evaluation only. The trading conjunction is disclosed QM
synthesis fixed before market testing.

## Approved Bounded Extraction

At the first tradable D1 tick of a genuine broker-month transition:

- reconstruct thirteen consecutive synchronized completed XAU/XAG month-end
  close pairs and twelve adjacent gold-minus-silver log-ratio changes,
  excluding every current-month price;
- compare fixed old/recent blocks of six with the continuous no-tie two-
  sample Anderson-Darling statistic over all eleven pooled-rank cuts;
- enumerate all 924 six-label assignments and require the inclusive exact
  upper tail to satisfy `tail_count<=452` and
  `2*tail_count<=assignment_count`;
- fade the sign of the recent pooled-rank sum around its neutral value 39;
- consume one attempt per broker month before fallible gates;
- use exact XAUUSD.DWX/XAGUSD.DWX, D1, one aggregate fixed-risk USD 1,000
  package, equal target notionals, frozen `3.5*ATR(20,D1)` hard stops, no
  target, 1,500/500-point spread ceilings, next-month exit, and forty-day
  stale repair.

The inclusive half-tail is an activity boundary, not a p-value or
statistical-significance claim. Exact enumeration leaves 448 directional
states among 924 assignments, about 5.82 per twelve market-free monthly
attempts. Q02 must prove realized activity and economics.

## Reputable-Source Criteria

| Gate | Verdict | Basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | Complete peer-reviewed relationship and method records, official exchange and pinned software records, hashes, adverse findings, and explicit translation boundary. |
| R2 | `PASS` | Exact clock, synchronization, endpoints, changes, blocks, formula, pooled ranks, all 924 assignments, inclusive boundary, side, attempt, aggregate risk, atomicity, and lifecycle. |
| R3 | `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK` | Registered native XAU/XAG D1 inputs; synchronization, basis, financing, and legging risks remain. |
| R4 | `PASS` | Deterministic native arithmetic and framework state only; no ML, banned signal indicator, external runtime feed, grid, or martingale. |

## Dedup Decision

The fail-closed canonical receipt
`artifacts/qm5_xauxag_mad2_rv_preallocation_dedup_20260901.json` found no
exact identity and conservative shared-carrier fuzzy matches. Manual review
resolves the candidate as distinct:

- it uses adjacent monthly ratio changes, not KS or Mann-Whitney ratio levels;
- it accumulates all eleven tail-weighted squared pooled-rank discrepancies,
  not one maximum ECDF gap or one rank sum;
- it enumerates the full 924-label exact tail, not a fitted critical table;
- it has no rolling median/MAD scale, OLS residual, time-split change point,
  daily cross, or convergence exit; and
- exact label fixtures give both disagreement directions versus the closest
  KS neighbor: `RROROROROORO` qualifies here at tail 428 but KS is flat,
  while `RORRROOORORO` is flat here at tail 484 but qualifies KS.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_ADJACENT_RATIO_CHANGE_FIXED_SIX_BY_SIX_CONTINUOUS_ANDERSON_DARLING_FULL_TAIL_WEIGHTED_RANK_PATH_EXACT_924_LABEL_HALF_TAIL_CONTRARIAN_BASKET`.

## Kill And Safety Boundaries

Retire on a failed reference fixture, nondeterministic enumeration, zero
packages, fewer than five completed packages in any full post-warm-up year,
or failed governed economics. Q09 alone can establish correlation; there is
no waiver or portfolio promise.

Authorized after card G0 and registry gates: branch-only EA build, reference
tests, strict Q01 compile, one canonical logical-basket
`RISK_FIXED=1000` D1 backtest set, and one paced Q02 enqueue if CPU admission
permits. Excluded: manual tester launch, optimization, live/demo/shadow/stress
presets, T_Live, AutoTrading, deploy/live manifest, portfolio-gate changes,
admission, correlation waiver, terminal control, or component-leg Q02 rows.
