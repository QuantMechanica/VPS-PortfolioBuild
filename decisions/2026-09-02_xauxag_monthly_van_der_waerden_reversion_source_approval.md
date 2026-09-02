# XAU/XAG Monthly Van der Waerden Reversion - Source Approval

- Date: 2026-09-02
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural XAU/XAG relative-value hypothesis, one
  Strategy Card, one branch build, strict Q01, and one paced non-live logical-
  basket Q02 enqueue
- Proposed slug: `xauxag-mvdw-rv`
- Proposed strategy ID: `AI-CODEX-XAUXAG-MVDW-RV-20260902_S01`
- Source ID: `AI-CODEX-XAUXAG-MVDW-RV-20260902`

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
`strategy-seeds/sources/AI-CODEX-XAUXAG-MVDW-RV-20260902/source.md`. The
complete governed carrier records and complete bounded official method
sections were read before this approval:

1. Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, through the complete-read repository
   packet `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
   `7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`;
2. CME Group's official gold/silver ratio spread record at
   `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`;
3. the complete bounded NIST/SEMATECH two-sample linear-rank sections,
   including the pooled statistic, moments, ties, and Van der Waerden score
   `Phi^-1(r/(N+1))`; and
4. the complete bounded SAS/STAT NPAR1WAY score and exact-test sections,
   which independently define Van der Waerden normal scores as a location
   test and the exact two-sample test as a simple linear-rank statistic.

The official pages were frozen earlier on 2026-09-02 in the complete-read
route `strategy-seeds/sources/AI-CODEX-XAUXAG-MSAVAGE-RV-20260902/
retrieval_route_savage_scores_20260902.json`, SHA-256
`ADA5EE09723CFBC5007B28A6BE79FEEAE429BFF42AE79CF0366FF988F2709475`.
The new route record preserves their URLs, response hashes, bounded read
scopes, independently reproduced normal-score constants, complete label-space
enumeration, activity support, fixtures, and claim boundary.

Schweikert's adverse evidence remains binding: the gold/silver relation is
state-dependent and asymmetric; constant-vector cointegration fails in
important specifications; the state is not known ex ante; and the paper does
not yield a direct forecast. CME supports an opposed-leg relative-value
carrier with distinct gold and silver demand drivers, not a profitable CFD
rule. NIST and SAS supply only the rank-score arithmetic and exact-test
identity. No statistical critical value or market performance transfers.

## Approved Mechanic

The trading conjunction is pre-result QM synthesis:

```text
13 synchronized completed XAU/XAG month-end pairs
-> 12 adjacent changes in ln(XAU)-ln(XAG)
-> fixed old/recent blocks of 6
-> reject any pooled tie under relative epsilon 1e-12
-> strictly rank the 12 pooled changes
-> assign Van der Waerden score Phi^-1(r/13), frozen as a signed
   15-decimal integer numerator over 10^15
-> S=sum of the six recent score numerators
-> enumerate all C(12,6)=924 six-rank assignments
-> exact two-sided tail counts assignments with abs(S_perm)>=abs(S_observed)
-> qualify when inclusive tail_count is at most 462 and S is nonzero
-> fade positive S by selling XAU/buying XAG; fade negative S oppositely
-> equal-target-notional opposed basket
```

The twelve locked score numerators over `10^15` are
`[-1426076872272847,-1020076232786202,-736315917376130,
-502402223373355,-293381232121193,-96558615289639,
96558615289639,293381232121193,502402223373355,
736315917376130,1020076232786202,1426076872272847]`.
They sum exactly to zero. Of 924 strict label assignments, twenty have exact
zero score and remain flat; 462 qualify, split into 231 positive and 231
negative states. That equals six directional states per twelve combinatorial
attempts. This is a market-free activity prior, not a p-value, serial-
independence assumption, trade-count result, or efficacy claim.

Use one consumed broker-month attempt, one equal-target-notional opposed-leg
package, aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, per-leg
`3.5*ATR(20,D1)` hard stops, XAU/XAG spread ceilings of 1,500/500 points,
next-month exit, and forty-day stale repair. Score magnitude must never scale
risk.

## Gate Decision

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_OFFICIAL_METHOD_EVIDENCE` | One durable AI source; complete governed peer-reviewed gold/silver evidence with adverse findings; official exchange carrier record; complete bounded NIST and SAS formula/exact-test sections; hashes and explicit synthesis boundary. |
| R2 | `PASS` | Exact month clock, synchronized endpoints, changes, strict ties, pooled ranks, twelve frozen normal scores, score sum, complete enumeration, absolute inclusive tail, side, attempt, aggregate risk, atomicity, and lifecycle are locked. |
| R3 | `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK` | Registered native XAU/XAG D1 history and MT5 state only. |
| R4 | `PASS` | Deterministic bounded arithmetic; no trained output, banned signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Duplicate Decision

The fail-closed corrected-root receipt
`artifacts/qm5_xauxag_mvdw_rv_preallocation_dedup_20260902.json`, SHA-256
`F356B42F07A95D6F5929A75AF3C5067D18A3A9EC7B830D2A0DBF40D999790310`,
found no exact identity across 4,781 registry rows, 1,417 card files, and all
45 Strategy Wiki nodes. It conservatively surfaced the shared-carrier Savage,
Cucconi, Klotz, Conover, and Anderson-Darling cards.

Manual formula review resolves those matches. Van der Waerden is a signed,
monotone normal-quantile score sum on raw pooled changes. Savage uses
asymmetric harmonic exponential-order scores; Wilcoxon uses linear ranks;
Cucconi and Anderson-Darling use distribution-path quadratics; Klotz squares
normal scores after within-block centering; Conover ranks and squares
mean-centered absolute deviations.

Locked strict-rank fixtures establish decision disagreement:

- `RRROOOORORRO`: Van der Waerden numerator `-1132695640151654`, tail
  `422`, so BUY XAU/SELL XAG; Savage tail `616` and Wilcoxon tail `544` are
  flat.
- `RRROROOOOORR`: Van der Waerden tail `476`, flat; Wilcoxon centered rank
  sum `-5`, tail `448`, so Wilcoxon buys XAU.
- `RRROOOOOORRR`: Van der Waerden score is exactly zero and flat; Savage
  score `1.3414502164502164`, tail `400`, so Savage sells XAU.

`O` and `R` label pooled ascending old/recent changes. Complement paths lock
side symmetry. Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_FIXED_SIX_BY_SIX_RAW_CHANGE_STRICT_RANK_VAN_DER_WAERDEN_SIGNED_NORMAL_QUANTILE_SCORES_EXACT_924_ABSOLUTE_TAIL_462_SCORE_SIGN_CONTRARIAN_BASKET`.

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
deploy/live manifests, `T_Live`, AutoTrading, and terminal control.
