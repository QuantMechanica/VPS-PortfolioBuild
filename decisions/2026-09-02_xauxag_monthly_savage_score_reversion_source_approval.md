# XAU/XAG Monthly Savage-Score Reversion - Source Approval

- Date: 2026-09-02
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural XAU/XAG relative-value hypothesis, one
  Strategy Card, one branch build, strict Q01, and one paced non-live logical-
  basket Q02 enqueue
- Proposed slug: `xauxag-msavage-rv`
- Proposed strategy ID:
  `AI-CODEX-XAUXAG-MSAVAGE-RV-20260902_S01`
- Source ID: `AI-CODEX-XAUXAG-MSAVAGE-RV-20260902`

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
`strategy-seeds/sources/AI-CODEX-XAUXAG-MSAVAGE-RV-20260902/source.md`.
The complete governed carrier records and complete bounded official method
sections were read before this approval:

1. Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, through the complete-read repository
   packet `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
   `7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`;
2. CME Group's official gold/silver ratio spread record at
   `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`;
3. the complete bounded NIST/SEMATECH two-sample linear-rank sections,
   including the pooled statistic, moments, ties, all score definitions, and
   the centered Savage formula;
4. the complete bounded SAS/STAT NPAR1WAY score chapter and exact-test option,
   which independently define the centered score and the exact two-sample
   Savage rank-sum test; and
5. the authoritative JSTOR journal metadata for I. Richard Savage (1956),
   *The Annals of Mathematical Statistics* 27(3), 590-615. The original body
   is not claimed as a complete read.

Reproducible URLs, response statuses, sizes, hashes, read scopes, exact frozen
scores, activity support, fixtures, and claim boundary are sealed in
`strategy-seeds/sources/AI-CODEX-XAUXAG-MSAVAGE-RV-20260902/retrieval_route_savage_scores_20260902.json`.

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
-> assign centered Savage score
   a(r)=sum(j=1..r, 1/(12-j+1))-1 to each recent rank
-> S=sum of the six recent scores
-> enumerate all C(12,6)=924 six-rank assignments
-> exact two-sided tail counts assignments with abs(S_perm)>=abs(S_observed)
-> qualify when inclusive tail_count is at most 462
-> fade positive S by selling XAU/buying XAG; fade negative S oppositely
-> equal-target-notional opposed basket
```

The twelve locked scores are the integer numerators
`[-25410,-22890,-20118,-17038,-13573,-9613,-4993,551,7481,16721,30581,58301]`
over `27720`. The exact 462-tail boundary is `15991/13860`, or
`1.1537518037518038`. All 924 strict label assignments have nonzero score;
462 qualify, split into 231 positive and 231 negative states. That equals six
directional states per twelve combinatorial attempts. This is a market-free
activity prior, not a p-value, serial-independence assumption, trade-count
result, or efficacy claim.

Use one consumed broker-month attempt, one equal-target-notional opposed-leg
package, aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, per-leg
`3.5*ATR(20,D1)` hard stops, XAU/XAG spread ceilings of 1,500/500 points,
next-month exit, and forty-day stale repair. Score magnitude must never scale
risk.

## Gate Decision

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_OFFICIAL_METHOD_EVIDENCE` | Durable AI source trail; complete governed peer-reviewed gold/silver evidence with adverse findings; official exchange carrier record; complete bounded NIST and SAS method/formula/exact-test sections; original peer-reviewed method metadata; hashes and explicit synthesis boundary. |
| R2 | `PASS` | Exact month clock, synchronized endpoints, changes, strict ties, pooled ranks, twelve frozen scores, sum, complete enumeration, absolute inclusive tail, side, attempt, aggregate risk, atomicity, and lifecycle are locked. |
| R3 | `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK` | Registered native XAU/XAG D1 history and MT5 state only. |
| R4 | `PASS` | Deterministic bounded arithmetic; no trained output, banned signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Duplicate Decision

The fail-closed corrected-root receipt
`artifacts/qm5_xauxag_msavage_rv_preallocation_dedup_20260902.json`, SHA-256
`86611AD596DBE2036EF5F27F108E9E478E5D6E24C34BB022FE5350EF43414EBE`,
found no exact identity across 4,778 registry rows, 1,414 card files, and all
45 Strategy Wiki nodes. It conservatively surfaced the shared-carrier
Cucconi, Klotz, Anderson-Darling, Kuiper, and Brown-Forsythe cards.

Manual formula review resolves those matches. Savage uses a one-sided,
monotone, highly nonlinear harmonic score on raw pooled ranks and a two-sided
exact tail of the signed score sum. Cucconi combines squared ranks and
contrary-ranks; Anderson-Darling integrates a weighted ECDF path; Kuiper uses
two ECDF extrema; Brown-Forsythe retains numeric median deviations; centered
Klotz removes each block mean and uses symmetric squared-normal scores.

Locked strict-rank fixtures establish both decision-disagreement directions:

- `RRROOOOOORRR`: Savage score `1.3414502164502164`, tail `400`, recent
  rank sum `39`, so SELL XAU/BUY XAG; Cucconi, Anderson-Darling, Kuiper,
  raw-rank-sum direction, and centered Klotz are flat.
- `RRRROOOROOOR`: Savage score `-0.9597402597402600`, tail `536`, flat;
  Cucconi tail `88`, Anderson-Darling tail `110`, and Kuiper tail `108` all
  BUY XAU.
- `RRRROOOOROOR`: Savage tail `632`, flat; centered Klotz score
  `6.410233092890735`, tail `26`, BUY XAU.

`O` and `R` label pooled ascending old/recent changes. Complement paths lock
Savage side symmetry. Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_FIXED_SIX_BY_SIX_RAW_CHANGE_STRICT_RANK_CENTERED_SAVAGE_HARMONIC_EXPONENTIAL_ORDER_SCORES_EXACT_924_ABSOLUTE_TAIL_462_SCORE_SIGN_CONTRARIAN_BASKET`.

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
