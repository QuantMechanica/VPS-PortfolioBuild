---
source_id: AI-CODEX-XAUXAG-MJT-RV-20260902
title: XAU/XAG monthly Jonckheere-Terpstra ordered-block reversion
publisher: QuantMechanica governed AI synthesis from peer-reviewed relationship and method evidence plus official exchange/statistical records
source_type: ai_originated_peer_reviewed_exchange_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-02_xauxag_monthly_jonckheere_terpstra_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-QC-2018: 7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
method_records:
  - NIST-JONCKHEERE-TERPSTRA-2024
  - RJOURNAL-NPORDTESTS-2020
  - JONCKHEERE-BIOMETRIKA-1954-METADATA
created: 2026-09-02
created_by: Research+Development
cards_extracted: []
---

# XAU/XAG Monthly Jonckheere-Terpstra Ordered-Block Reversion

## Canonical origin and claim boundary

This is the single R1 lineage for one bounded AI-originated strategy under the
current explicit OWNER request for a new structural, low-frequency commodity
sleeve. The idea was frozen before market testing: divide twelve consecutive
completed monthly gold/silver log-ratio changes into three chronological
groups of four, count all 48 correctly ordered cross-group pairs with the
classic Jonckheere-Terpstra statistic, and fade a sufficiently ordered move
for one broker month through an opposed XAU/XAG package.

Schweikert (2018) supports only a state-dependent gold/silver relationship and
supplies adverse evidence against a stable constant spread. CME supports the
gold/silver ratio, distinct demand drivers, and opposed-leg carrier. NIST and
Altunkaynak and Gamgam (2020) support the classic ordered-group pair-count
statistic. The chronological grouping, exact label-space boundary, contrarian
direction, CFD mapping, equal-notional package, risk, and lifecycle are an
untested QM synthesis.

No source tests this rule on Darwinex continuous CFDs or supplies its return,
profit factor, p-value, threshold, drawdown, activity, cost, hedge ratio,
neutrality, decorrelation, or portfolio fit. Exact enumeration below is an
activity prior, not a significance claim. Q02 owns activity and economics;
unchanged Q09 alone owns realized overlap with the portfolio.

## Supporting evidence and complete bounded read

The complete governed relationship packet is
`strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
`7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`.
It records the complete 32-page author-preprint read of Schweikert (2018),
*Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`. Its state dependence, asymmetric relation,
failed constant-vector specifications, and no-direct-forecast warning remain
binding adverse evidence.

The official opposed-leg carrier packet is
`strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
`2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.
CME defines the price ratio and distinguishes gold's monetary/safe-haven
demand from silver's industrial-cycle exposure. Futures margin, liquidity,
and execution properties do not transfer to the two continuous CFDs.

The complete bounded NIST/SEMATECH Dataplot Jonckheere-Terpstra method page
defines ordered factor groups, the cross-group comparison count, and a
permutation reference distribution. The complete relevant sections of
Altunkaynak and Gamgam (2020), *The R Journal* 12(1), independently define the
classic statistic as the sum of all pairwise Mann-Whitney ordered-win counts.
Jonckheere (1954), *Biometrika* 41(1-2), 133-145, DOI
`10.1093/biomet/41.1-2.133`, supplies original peer-reviewed metadata; its
paywalled body is not represented as read. Routes and scopes are preserved in
`retrieval_route_20260902.json`.

## Locked hypothesis and exact formula

Gold and silver share USD and precious-metal drivers but differ in industrial
and safe-haven demand. A strongly ordered three-stage displacement in their
monthly relative changes may overshoot and partly reverse during the next
month.

At the first synchronized executable D1 boundary of a new broker month:

1. Reconstruct thirteen consecutive completed synchronized XAU/XAG month-end
   close pairs, oldest to newest, excluding every current-month price.
2. Form twelve chronological relative changes:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..12
r[i] = q[i+1] - q[i], i=0..11

G0 = r[0..3]
G1 = r[4..7]
G2 = r[8..11]
```

3. Require all changes finite and pairwise distinct under
   `1e-12*max(1,abs(left),abs(right))`.
4. Count every cross-group ordered win:

```text
J = 0
N = 0
for a in 0..1:
  for b in a+1..2:
    for x in Ga:
      for y in Gb:
        N += 1
        if x < y: J += 1

require N == 48 and 0 <= J <= 48
```

5. Enumerate every labeled strict-rank allocation with group sizes 4/4/4:
   choose four of ranks 1..12 for `G0`, four of the remaining eight for `G1`,
   and assign the last four to `G2`. Require exactly
   `C(12,4)*C(8,4)=34,650` allocations.
6. For the observed displacement `D=abs(J-24)`, count every allocation whose
   `abs(J_perm-24)>=D`. Require an inclusive tail count at most `18,034`.
   This is equivalent to `J<=19` or `J>=29`; both equivalences are runtime
   invariants.
7. Fade the ordered move: `J>=29` sells XAU and buys XAG; `J<=19` buys XAU
   and sells XAG. Scores from 20 through 28 consume the month flat. Statistic
   or tail magnitude never changes risk.

The official records define an ordered-group method for independent samples.
Monthly time blocks are not independent randomized groups, so the strategy
does not import a test size, p-value, critical value, or inference. It uses the
same deterministic pair-count functional as a disclosed state classifier.

## Exact pre-data activity boundary

Complete enumeration over all 34,650 labeled strict-rank allocations gives:

- `9,017` ascending allocations at `J>=29`;
- `9,017` descending allocations at `J<=19`;
- `18,034` qualifying allocations in total;
- a symmetric qualifying fraction of `0.5204617604617605`; and
- `6.245541125541125` theoretical directional states per twelve attempts.

This uses no market data. Receipt:
`artifacts/qm5_xauxag_mjt_rv_threshold_density_20260902.json`.
Q02 retires zero packages or fewer than five completed packages in any full
post-warm-up scored year.

## Non-duplicate boundary

The corrected-root deterministic checker scanned 4,784 registry identities,
1,420 card files, and all 45 Strategy Wiki nodes. It found no exact identity
and raised five generic shared-carrier cards for manual review. Receipt:
`artifacts/qm5_xauxag_mjt_rv_preallocation_dedup_20260902.json`, SHA-256
`E103D2C5F4751B0AB5B228C898DFC85AD49C4C801D29939FB1A4D0C753CBB944`.

- `QM5_12724` is a D1 ratio-channel breakout, not a completed-month
  ordered-rank fade.
- `QM5_20161` is rolling OLS residual reversion with a fitted hedge relation.
- `QM5_20202` is fixed-horizon relative reversal, without grouped ordinal
  comparisons or exact label enumeration.
- `QM5_20234` uses realized semivariance-jump state, not a rank order score.
- `QM5_20263` uses a median/MAD level deviation, not cross-block order.
- `QM5_41116` votes three within-one-month return blocks; it does not use
  twelve completed monthly changes or 48 cross-block comparisons.
- `QM5_41274` counts 75 cross-block comparisons among fifteen within-month WTI
  daily closes and always has a side. This candidate uses the XAU/XAG ratio,
  twelve completed monthly changes, an exact 34,650-label tail, a neutral
  band, a contrarian basket, and one aggregate package budget.
- `QM5_41177` compares fixed six-old/six-recent blocks with one Mann-Whitney
  statistic. It neither distinguishes a middle block nor tests all three
  chronological group pairs.

Frozen chronological-rank fixtures prove functional separation:

| twelve change ranks, chronological | this rule | neighbor |
|---|---|---|
| `10,3,1,4,12,7,9,6,11,8,2,5` | `J=29`, SELL XAU | six/six Mann-Whitney `U=20` and Van der Waerden tail `748`, both flat |
| `7,8,5,12,6,9,1,3,2,10,11,4` | `J=21`, flat | six/six Mann-Whitney `U=10`, BUY XAU |
| `2,8,6,4,11,12,3,1,9,7,5,10` | `J=30`, SELL XAU | Van der Waerden numerator negative with tail `430`, BUY XAU |

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_THREE_BY_FOUR_CLASSIC_JONCKHEERE_TERPSTRA_48_ORDERED_WINS_EXACT_34650_TWO_SIDED_TAIL18034_CONTRARIAN_BASKET`.

## Executable mechanization

- Evaluate only from the exact `XAUUSD.DWX` D1 host with registered XAG slot.
- Consume one normalized broker-month attempt before every fallible gate and
  never retry within the month.
- Require thirteen consecutive exact timestamp-matched completed month-end
  pairs; the newest endpoint must immediately precede the current month and
  be no more than ten calendar days stale.
- Permit no foreign position on either symbol and no owned exposure before a
  new package.
- Submit XAU first and XAG second through governed basket order handling.
  Flatten every owned leg immediately if the opposed package is incomplete or
  malformed.
- Exit both legs at the first later synchronized broker month, after forty
  elapsed calendar days, or on package corruption.

## Risk and execution boundary

- Backtest package: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Split the frozen-stop risk budget equally across the two legs.
- Freeze independent `3.5*ATR(20,D1)` broker hard stops.
- Target equal absolute USD notionals by volume reduction only; reject more
  than 20 percent mismatch.
- Reject XAU/XAG spreads above 1,500/500 points.
- Both news axes, legacy news mode, Friday close, and stress rejection are
  OFF in the canonical baseline.
- No target, trail, break-even, partial close, scale-in, pyramid, intramonth
  retry, external feed, randomized runtime path, or trained output.

Equal target notionals and opposed legs are market-neutral-style construction
only. They do not prove dollar, beta, volatility, factor, or portfolio
neutrality. No live/demo/shadow/stress/optimization set, manual tester run,
portfolio-gate change, deploy/live manifest, `T_Live`, AutoTrading, or live
use is authorized.
