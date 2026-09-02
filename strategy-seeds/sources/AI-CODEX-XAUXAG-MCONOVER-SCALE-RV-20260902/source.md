---
source_id: AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902
source_type: ai_originated_governed_synthesis
title: XAU/XAG monthly Conover squared-rank scale-state reversion
author: OpenAI Codex
supporting_authors: William J. Conover; Karsten Schweikert; CME Group; NIST/SEMATECH
status: approved_source_complete
approval_basis: decisions/2026-09-02_xauxag_monthly_conover_scale_reversion_source_approval.md
created: 2026-09-02
created_by: Codex
last_reviewed: 2026-09-02
cards_extracted:
  - QM5_41281_xauxag-mconover-scale-rv
---

# XAU/XAG Monthly Conover Squared-Rank Scale-State Reversion

## Canonical Origin

This packet is the single R1 lineage for one bounded AI-originated strategy.
The current explicit OWNER mission requests a genuinely different structural,
low-frequency commodity/energy sleeve outside the directional
XAU/SP500/NDX/XNG book and expressly permits a market-neutral-style
`XAUUSD.DWX`/`XAGUSD.DWX` ratio-reversion basket. The source approval was
committed before extraction as `6a88b02d89`.

`processes/qb_reputable_source_criteria.md` permits an AI-originated source
when one `source_id` preserves the lineage. Codex fixed the rule below before
any market test and after a fail-closed canonical duplicate scan. It is not
presented as a Conover, Schweikert, CME, or NIST trading rule. The cited
records support only the scale-score arithmetic, a state-dependent
gold/silver carrier, and opposed-leg construction. The six/six monthly
sample, 461/924 activity boundary, contrarian translation, CFD symbols,
aggregate risk, and lifecycle are disclosed pre-result QM choices.

## Supporting Evidence And Read Boundary

### Gold/Silver Carrier

`strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
`7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`,
records a complete read of Karsten Schweikert (2018), "Are gold and silver
cointegrated? New evidence from quantile cointegrating regressions,"
*Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`.

The paper supports a state-dependent and asymmetric gold/silver relationship,
not a profitable constant spread. Its adverse evidence is load-bearing:
constant-vector linear cointegration fails in important specifications; some
daily upper quantiles reject quantile cointegration; the relevant state is not
known ex ante; estimates do not directly forecast; and prior work did not
produce a profitable ex-ante intercommodity-spread rule.

`strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
`2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
records CME Group's official gold/silver ratio-spread research. CME defines
the ratio and an intermarket opposed-leg carrier, and distinguishes gold's
monetary/safe-haven demand from silver's industrial-cycle exposure. It does
not establish a profitable Darwinex CFD strategy or market neutrality.

### Conover Squared-Rank Method

The NIST/SEMATECH two-sample linear-rank page was read completely for its
bounded definition, score notes, and tie treatment. It defines the score-sum
statistic on pooled ranks and defines the Conover score as the squared rank of
each observation's absolute deviation from its own group mean. It identifies
the construction as a scale test.

The NIST/SEMATECH squared-ranks page was read completely for its two-sample
construction. It forms within-group mean-centered absolute deviations, pools
their ranks, sums squared ranks by sample, and gives the asymptotic scale-test
statistic. It warns that its critical values are approximate at small sample
sizes and cites W. J. Conover (1999), *Practical Nonparametric Statistics*,
third edition, pp. 300-310. The book body is not claimed as a complete read.

The reproducible response evidence is
`retrieval_route_conover_scores_20260902.json`: both official NIST pages
returned HTTP 200, with sizes and SHA-256 hashes sealed there. The EA does not
call NIST software, use the asymptotic statistic, import a p-value, or claim a
published critical level. It directly implements the fixed N=12 squared-rank
score and enumerates all 924 fixed-score label assignments. That tail is a QM
activity gate, not a source significance test.

## Pre-Result Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. When the newest six
completed monthly changes in `ln(XAU)-ln(XAG)` have larger within-block
mean-centered absolute deviations than the prior six under a strict Conover
squared-rank upper-half state, fade the raw recent block-mean shift for one
broker month.

Opposed equal-target-notional legs are intended to reduce outright XAU
direction and create a market-neutral-style return stream. They do not prove
dollar, beta, volatility, factor, market, or portfolio neutrality. Q02 owns
realized activity and economics. Later gates own robustness. Unchanged Q09
alone owns portfolio correlation.

## Exact Frozen Mechanic

At the first executable D1 tick of a genuine new normalized broker month:

1. Reconstruct thirteen immediately prior consecutive synchronized
   XAU/XAG completed broker-month close pairs. Exclude every current-month
   price.
2. Compute ratio endpoints
   `q[i]=ln(XAU_close[i])-ln(XAG_close[i])`, oldest to newest, and twelve
   adjacent changes `r[i]=q[i+1]-q[i]`.
3. Fix `old=r[0..5]` and `recent=r[6..11]`. Compute separate arithmetic means
   `mu_old` and `mu_recent`.
4. Form absolute deviations from the owning block mean:
   `d[i]=abs(r[i]-mu_block(i))`.
5. Require every value finite and all twelve deviations pairwise distinct
   under `1e-12*max(1,abs(a),abs(b))`.
6. Sort pooled deviations ascending. Assign ranks 1..12 and squared scores
   `a(rank)=rank^2`, giving
   `1,4,9,16,25,36,49,64,81,100,121,144`.
7. Sum `C_recent` over the six ranks carrying actual recent labels.
8. Enumerate every six-rank subset of twelve. For each assignment compute the
   same fixed squared-score sum `C_perm`; increment `tail_count` when
   `C_perm >= C_recent`.
9. Require exactly 924 assignments, `C_recent >= 326`, and inclusive
   `tail_count <= 461`.
10. Let `mean_shift=mu_recent-mu_old`. SELL XAU/BUY XAG when mean shift is
    greater than `1e-12`; BUY XAU/SELL XAG when it is less than `-1e-12`;
    remain flat otherwise.
11. Consume the month before every fallible entry gate. Use one aggregate
    `RISK_FIXED=1000` package, frozen `3.5*ATR(20,D1)` hard stops, no targets,
    XAU/XAG spread ceilings of 1,500/500 points, equal target notionals,
    next-month exit, and forty-day stale repair.

The strict score vector totals 650 and has expected six-label score 325. The
924 assignments contain 461 scores above 325, two scores equal to 325, and
461 below 325. The smallest qualifying score is 326 and its inclusive upper
tail is 461. Thus the gate admits exactly 5.987 market-free label states per
twelve monthly attempts before ties, zero mean shifts, data, and execution
gates. This does not guarantee five completed packages in any scored year.

## Non-Duplicate Decision

The corrected-root receipt
`artifacts/qm5_xauxag_mconover_scale_rv_preallocation_dedup_20260902.json`,
SHA-256
`8B4A95C9CE6F1FABDFDE437DC76CDB2CA917C5458EA12639B6415E9D0B49836E`,
found no exact identity across 4,780 registry rows, 1,416 cards, and all 45
Strategy Wiki nodes. It conservatively surfaced shared-carrier fuzzy matches.

- `QM5_41269_xauxag-mklotz-scale-rv` ranks signed block-centered residuals
  and applies symmetric squared-normal scores. This rule ranks absolute
  block-mean deviations and applies polynomial squared ranks.
- `QM5_41265_xauxag-mbf-scale-rv` median-centers numeric deviations and
  trades any strict recent mean-absolute-deviation expansion without a label
  tail. This rule arithmetic-mean-centers, discards deviation spacing after
  ranking, rejects ties, and uses a 924-label upper-half boundary.
- `QM5_41278_xauxag-mcucconi-rv` uses squared raw-change ranks plus squared
  contrary-ranks in a correlated quadratic. This rule transforms deviations
  before ranking and has one squared-rank sum only.
- `QM5_41279_xauxag-msavage-rv` uses monotone harmonic raw-change scores and a
  two-sided signed-score tail. This rule uses symmetric scale ranks after
  separate location removal and a one-sided expansion tail.
- `QM5_41263_xauxag-mkuiper-rv` uses two empirical-CDF extrema on raw changes.
  This rule uses one within-group deviation rank-score sum.
- `QM5_41267_wti-mmood-scale-tr` ranks raw WTI returns and scores squared
  distance from the pooled median rank. This basket removes each block mean
  before ranking and uses a different carrier and contrarian side.

Fixed strict-deviation fixtures prove functional disagreement:

```text
Conover-only changes:
[1.730871,-4.253550,2.942130,3.730888,-0.057275,0.662848,
 0.808899,4.555005,-2.252364,1.445557,2.931657,4.195571]
mu old/recent = 0.7926520 / 1.9473875
recent deviation ranks = [6,9,11,2,5,8]
C_recent = 331; tail = 440
=> Conover SELL XAU; Klotz tail 640 and Brown-Forsythe flat.

Klotz-only changes:
[4.787636,4.977662,-0.155177,4.303156,-5.294428,-0.484160,
 -3.876079,0.557290,3.755243,-1.349457,-3.862835,-4.147329]
C_recent = 248; tail = 753
=> Conover flat; Klotz score 3.9642160041063397/tail 494 BUY XAU;
   Brown-Forsythe flat.

Brown-Forsythe-only changes:
[-1.068800,5.811016,-1.405426,-1.104323,-4.699905,-5.230559,
 -3.707560,-0.776133,1.903656,-4.227494,5.989247,-3.392596]
C_recent = 313; tail = 514
=> Conover and Klotz flat; Brown-Forsythe BUY XAU.

Side-disagreement changes:
[1.835782,2.887219,5.865684,0.583978,0.439193,-1.753346,
 3.958708,2.429016,-0.440576,5.134423,-5.637578,3.048016]
C_recent = 397; tail = 187
=> Conover BUY XAU; Brown-Forsythe SELL XAU.
```

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_SEPARATE_MEAN_CENTERED_ABSOLUTE_DEVIATION_STRICT_RANK_CONOVER_SQUARED_RANK_SUM_EXACT_924_UPPER_HALF_TAIL461_RAW_MEAN_SHIFT_CONTRARIAN_BASKET`.

## Reputable-Source Criteria

- **R1 — PASS_WITH_AI_SYNTHESIS_AND_OFFICIAL_METHOD_EVIDENCE.** One durable
  AI source ID, complete governed peer-reviewed gold/silver evidence with
  adverse findings, official CME carrier evidence, complete bounded official
  NIST method/formula pages, hashes, and explicit translation boundaries.
- **R2 — PASS.** Month clock, synchronized endpoints, changes, fixed blocks,
  means, deviations, tie rejection, ranks, squared scores, all 924 labels,
  inclusive boundary, side, attempt, aggregate risk, atomicity, and lifecycle
  are fully mechanical.
- **R3 — PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK.** Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories and MT5-native state provide all
  runtime inputs. Basis, financing, calendar, synchronization, and legging
  risks remain explicit.
- **R4 — PASS.** Deterministic timestamps, completed prices, logarithms,
  arithmetic, sorting, bounded integer enumeration, ATR risk, quotes,
  positions, deals, and persistent attempt state only; no ML, prohibited
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Falsification And Safety Boundary

Retire on a failed formula fixture, an accepted deviation tie, assignment
count other than 924, wrong score/tail identity, zero packages, fewer than five
completed packages in any full post-warm-up year, nonpositive governed
economics, downstream gate failure, component-leg fanout, missing logical
basket evidence, orphan leg, aggregate-risk double counting, or lifecycle
deviation. Do not rescue a failure by changing the sample, centering, score,
boundary, side, carrier, risk, or hold.

Authorized after card G0 and clean deterministic registries: one branch-only
non-live build, reference tests, strict Q01, one canonical fixed-risk logical-
basket set plus component validation sets, and one paced logical Q02 enqueue
below the CPU ceiling. Excluded: manual tester run, optimization,
live/demo/shadow/stress preset, component-leg Q02 row, portfolio-gate edit,
correlation waiver, portfolio admission, deploy/live manifest, `T_Live`,
AutoTrading, or terminal control.

## Revision History

| version | date | change | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | bounded carrier/method synthesis fixed before market testing | source approval | APPROVED_SOURCE |
