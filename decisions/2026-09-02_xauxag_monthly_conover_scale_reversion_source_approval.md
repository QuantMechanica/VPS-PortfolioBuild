# XAU/XAG Monthly Conover Scale Reversion - Source Approval

- Date: 2026-09-02
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural XAU/XAG relative-value hypothesis, one
  Strategy Card, one branch build, strict Q01, and one paced non-live logical-
  basket Q02 enqueue
- Proposed slug: `xauxag-mconover-scale-rv`
- Proposed strategy ID:
  `AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902_S01`
- Source ID: `AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902`

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
`strategy-seeds/sources/AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902/source.md`.
The following governed records and bounded official method sections were read
before this approval:

1. Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, through the complete-read repository
   packet `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
   `7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`;
2. CME Group's official gold/silver ratio spread record at
   `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`;
3. the complete bounded NIST/SEMATECH two-sample linear-rank sections that
   define pooled rank-score sums and identify Conover scores as squared ranks
   of absolute deviations from each group's mean; and
4. the complete bounded NIST/SEMATECH squared-ranks page, which defines the
   two-sample construction, mean-centered absolute deviations, squared-rank
   sums, scale interpretation, approximation warning, and Conover (1999)
   bibliography.

Reproducible URLs, response statuses, sizes, hashes, read scopes, the frozen
score distribution, and formula-disagreement fixtures are sealed in
`strategy-seeds/sources/AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902/retrieval_route_conover_scores_20260902.json`.

Schweikert's adverse evidence remains binding: the gold/silver relationship is
state-dependent and asymmetric; constant-vector cointegration fails in
important specifications; the state is not known ex ante; and the paper does
not produce a direct forecast. CME supports an opposed-leg relative-value
carrier with distinct gold and silver demand drivers, not a profitable CFD
rule. NIST supplies the scale-score arithmetic, not this trading conjunction
or threshold. No critical value, p-value, performance result, neutrality, or
decorrelation claim transfers.

## Approved Mechanic

The trading conjunction is pre-result QM synthesis:

```text
13 synchronized completed XAU/XAG month-end pairs
-> 12 adjacent changes in ln(XAU)-ln(XAG)
-> fixed old/recent blocks of 6
-> compute each block's arithmetic mean
-> take absolute deviation from its own block mean
-> reject any pooled deviation tie under relative epsilon 1e-12
-> rank the 12 pooled deviations ascending, ranks 1..12
-> Conover score is squared rank
-> C_recent = sum of the six recent squared ranks
-> enumerate all C(12,6)=924 fixed-score label assignments
-> upper tail counts assignments with C_perm >= C_recent
-> qualify only when C_recent >= 326 and inclusive tail_count <= 461
-> fade a positive raw block-mean shift by selling XAU/buying XAG
-> fade a negative raw block-mean shift by buying XAU/selling XAG
-> equal-target-notional opposed basket
```

For strict ranks the score vector is
`[1,4,9,16,25,36,49,64,81,100,121,144]`, total `650`, and null label
expectation `325`. Across all 924 six-rank assignments, 461 have score above
325, two have score exactly 325, and 461 have score below 325. The smallest
upper-half score is 326 with inclusive upper tail 461. Therefore the frozen
gate admits exactly 461/924 label states, or 5.987 states per twelve
market-free monthly attempts before deviation ties, zero mean shifts, data,
and execution gates. This is an activity prior only, not a p-value,
independence assumption, trade-count result, or efficacy claim.

Use one consumed broker-month attempt, one equal-target-notional opposed-leg
package, aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, per-leg
`3.5*ATR(20,D1)` hard stops, XAU/XAG spread ceilings of 1,500/500 points,
next-month exit, and forty-day stale repair. Score magnitude must never scale
risk.

## Gate Decision

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_OFFICIAL_METHOD_EVIDENCE` | One durable AI source; complete governed peer-reviewed gold/silver evidence with adverse findings; official exchange carrier record; complete bounded official NIST formula pages; hashes and explicit synthesis boundary. |
| R2 | `PASS` | Exact month clock, synchronization, endpoints, changes, block means, deviations, strict ties, pooled ranks, squared scores, full enumeration, boundary, side, attempt, aggregate risk, atomicity, and lifecycle are locked. |
| R3 | `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK` | Registered native XAU/XAG D1 history and MT5 state only. |
| R4 | `PASS` | Deterministic bounded arithmetic; no trained output, banned signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Duplicate Decision

The fail-closed corrected-root receipt
`artifacts/qm5_xauxag_mconover_scale_rv_preallocation_dedup_20260902.json`,
SHA-256
`8B4A95C9CE6F1FABDFDE437DC76CDB2CA917C5458EA12639B6415E9D0B49836E`,
found no exact identity across 4,780 registry rows, 1,416 card files, and all
45 Strategy Wiki nodes. It conservatively surfaced the shared-carrier Klotz,
Brown-Forsythe, Cucconi, Savage, and Kuiper cards.

Manual formula review resolves those matches. Conover first removes each
block's arithmetic mean, ranks pooled absolute deviations, squares those
ordinal ranks, and gates on a fixed-score upper tail. Klotz ranks signed
block-centered residuals and uses symmetric squared-normal scores;
Brown-Forsythe median-centers numeric deviations and has no label-tail gate;
Cucconi uses raw-change squared-rank and contrary-rank components; Savage
uses monotone harmonic raw-rank scores; and Kuiper uses empirical-CDF extrema.

Locked strict-deviation fixtures establish decision disagreement:

- Conover-only changes
  `[1.730871,-4.253550,2.942130,3.730888,-0.057275,0.662848,
  0.808899,4.555005,-2.252364,1.445557,2.931657,4.195571]`:
  old/recent means `0.7926520/1.9473875`, recent deviation ranks
  `{6,9,11,2,5,8}`, score `331`, upper tail `440`, hence SELL XAU/BUY XAG;
  Klotz tail `640` and Brown-Forsythe are flat.
- Klotz-only changes
  `[4.787636,4.977662,-0.155177,4.303156,-5.294428,-0.484160,
  -3.876079,0.557290,3.755243,-1.349457,-3.862835,-4.147329]`:
  Conover score `248`, tail `753`, flat; Klotz score
  `3.9642160041063397`, tail `494`, BUY XAU; Brown-Forsythe is flat.
- Brown-Forsythe-only changes
  `[-1.068800,5.811016,-1.405426,-1.104323,-4.699905,-5.230559,
  -3.707560,-0.776133,1.903656,-4.227494,5.989247,-3.392596]`:
  Conover score `313`, tail `514`, and Klotz tail `725` are flat while
  Brown-Forsythe buys XAU.
- Side-disagreement changes
  `[1.835782,2.887219,5.865684,0.583978,0.439193,-1.753346,
  3.958708,2.429016,-0.440576,5.134423,-5.637578,3.048016]`:
  Conover score `397`, tail `187`, BUY XAU; Brown-Forsythe sells XAU.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_SEPARATE_MEAN_CENTERED_ABSOLUTE_DEVIATION_STRICT_RANK_CONOVER_SQUARED_RANK_SUM_EXACT_924_UPPER_HALF_TAIL461_RAW_MEAN_SHIFT_CONTRARIAN_BASKET`.

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
