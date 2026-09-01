# XAU/XAG Monthly Cucconi Location-Scale Reversion - Source Approval

- Date: 2026-09-02
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural XAU/XAG relative-value hypothesis, one
  Strategy Card, one branch build, strict Q01, and one paced non-live logical-
  basket Q02 enqueue
- Proposed slug: `xauxag-mcucconi-rv`
- Proposed strategy ID:
  `AI-CODEX-XAUXAG-MCUCCONI-RV-20260902_S01`
- Source ID: `AI-CODEX-XAUXAG-MCUCCONI-RV-20260902`

## Authority And Ordering

The current explicit OWNER mission authorizes one new reputable-source,
structural, low-frequency commodity/energy sleeve, expressly identifies a
market-neutral-style gold/silver basket as eligible, requires real committed
non-duplicate work, and requests a fixed-risk Q02 enqueue. This durable record
approves the bounded source before card extraction. It does not pre-approve
activity, economics, robustness, decorrelation, portfolio admission,
deployment, or live use.

## Approved Evidence And Complete Read

The bounded source packet will live at
`strategy-seeds/sources/AI-CODEX-XAUXAG-MCUCCONI-RV-20260902/source.md`.
The complete governed carrier records were read before this approval:

1. Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, through the complete-read repository
   packet `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
   `7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`;
2. CME Group's official gold/silver ratio spread record at
   `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`;
3. Marozzi (2012), "A modified Cucconi Test for Location and Scale Change
   Alternatives," through the complete 14-page publisher PDF, SHA-256
   `236BA86C34B99F126CA6EECB16CEA9082EEACA4D0F1D90406853BB059A2C0BEB`;
   and
4. authoritative Crossref metadata for Marozzi (2009), "Some notes on the
   location-scale Cucconi test," DOI `10.1080/10485250902952435`.

The reproducible URLs, statuses, sizes, hashes, read scope, exact constants,
and claim boundary are sealed in
`strategy-seeds/sources/AI-CODEX-XAUXAG-MCUCCONI-RV-20260902/retrieval_route_marozzi_cucconi_20260902.json`.

Schweikert's adverse evidence remains binding: the gold/silver relation is
state-dependent and asymmetric; constant-vector cointegration fails in
important specifications; the state is not known ex ante; and the paper does
not yield a direct forecast. CME supports an opposed-leg relative-value
carrier with distinct gold and silver demand drivers, not a profitable CFD
rule. Marozzi supplies the classical Cucconi squared-rank and squared-
contrary-rank statistic, its moments/correlation, and exact fixed-label
permutation construction. Its biomedical power results do not transfer.

## Approved Mechanic

The trading conjunction is pre-result QM synthesis:

```text
13 synchronized completed XAU/XAG month-end pairs
-> 12 adjacent changes in ln(XAU)-ln(XAG)
-> fixed old/recent blocks of 6
-> reject any pooled tie under relative epsilon 1e-12
-> strictly rank the 12 pooled changes
-> for the six recent ranks compute classical Cucconi U and V from
   squared ranks and squared contrary-ranks
-> C=(U^2+V^2-2*rho*U*V)/(2*(1-rho^2)), rho=-479/535
-> enumerate all C(12,6)=924 six-rank assignments
-> qualify when the inclusive exact tail_count is at most 480
-> require recent rank sum different from its neutral value 39
-> fade the rank-sum direction with an equal-target-notional opposed basket
```

For `n1=n2=6`, the locked expectation is `325`, the locked standard
deviation is `sqrt(6955)=83.3966426182733`, and the 480-tail boundary is
`C=0.7655677655677652`. Of all 924 strict rank-label assignments, 480 satisfy
the statistic gate and 18 of those have neutral recent rank sum 39. The
remaining 462 directional states equal six per twelve combinatorial attempts.
This is a market-free activity prior, not a p-value, independence assumption,
trade-count result, or efficacy claim.

Use one consumed broker-month attempt, one equal-target-notional opposed-leg
package, aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, per-leg
`3.5*ATR(20,D1)` hard stops, XAU/XAG spread ceilings of 1,500/500 points,
next-month exit, and forty-day stale repair. Statistic and rank-sum magnitude
must never scale risk.

## Gate Decision

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | Durable AI source trail; complete governed peer-reviewed gold/silver evidence with adverse findings; official exchange carrier record; complete peer-reviewed publisher PDF defining the classical Cucconi statistic and exact permutation construction; authoritative 2009 method metadata; hashes and explicit synthesis boundary. |
| R2 | `PASS` | Exact month clock, synchronized endpoints, changes, strict ties, pooled ranks, squared sums, constants, statistic, complete enumeration, inclusive boundary, rank-sum side, attempt, aggregate risk, atomicity, and lifecycle are locked. |
| R3 | `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK` | Registered native XAU/XAG D1 history and MT5 state only. |
| R4 | `PASS` | Deterministic bounded arithmetic; no trained output, banned signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Duplicate Decision

The fail-closed corrected-root receipt
`artifacts/qm5_xauxag_mcucconi_rv_preallocation_dedup_20260902.json`, SHA-256
`7410C6B9B94B9B3E5BF1E5964789C42471DA5016F643149624FF4C29DF2B8DE8`,
found no exact identity across 4,777 registry rows, 1,413 card files, and all
45 Strategy Wiki nodes. It conservatively surfaced the shared-carrier Kuiper,
Klotz, Anderson-Darling, and Brown-Forsythe cards.

Manual formula review resolves those matches. Kuiper uses two opposing ECDF
extrema. Anderson-Darling integrates a tail-weighted ECDF path. Brown-Forsythe
retains numeric median-centered absolute deviations. Klotz separately mean-
centers both blocks and sums nonlinear squared-normal rank scores. This source
instead combines recent squared raw ranks and squared contrary-ranks through
their exact strong negative correlation and qualifies their complete fixed-
label permutation tail. It also differs from the WTI Lepage build, which uses
25-by-25 daily returns and adds independently standardized Wilcoxon and
Ansari-Bradley components for directional continuation.

Locked strict-rank fixtures establish decision disagreement:

- `RROROROOORRO`: Cucconi `C=0.7655677655677652`, tail `480`, recent rank
  sum `34`, so BUY XAU/SELL XAG; Anderson-Darling tail `532`, flat.
- `RROROROROROO`: Cucconi tail `456`, recent rank sum `31`, so BUY
  XAU/SELL XAG; Kuiper distance `1/3`, tail `922`, flat.
- `RRRRROOROOOO`: Cucconi tail `14`, so BUY XAU/SELL XAG; Klotz score
  `3.674462867975379`, tail `566`, flat.
- `RROROROROORO`: Cucconi tail `484`, flat; Klotz score
  `4.253969140237301`, tail `374`, so BUY XAU/SELL XAG.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_FIXED_SIX_BY_SIX_RAW_CHANGE_STRICT_RANK_CUCCONI_SQUARED_RANK_CONTRARY_RANK_CORRELATED_QUADRATIC_EXACT_924_TAIL_480_RANK_SUM_CONTRARIAN_BASKET`.

## Safety Boundary

Q02 must retire the exact card on zero packages, fewer than five completed
packages in any full post-warm-up year, nonpositive governed economics, or a
gate failure. Q09 alone owns realized portfolio correlation. Equal target
notionals and opposite legs are market-neutral-style construction only; they
do not establish beta, volatility, factor, dollar, or portfolio neutrality.

Authorized after G0 and clean registries: branch-only build, reference tests,
strict Q01, one fixed-risk logical-basket preset plus component validation
presets, and one paced Q02 work item if CPU admission permits. Excluded:
manual tester run, optimization, live/demo/shadow/stress presets, component-
leg Q02 rows, portfolio-gate edits, correlation waiver, portfolio admission,
deploy/live manifests, `T_Live`, and AutoTrading.
