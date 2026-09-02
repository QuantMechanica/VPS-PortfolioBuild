---
source_id: AI-CODEX-XAUXAG-MSIEGEL-TUKEY-RV-20260902
title: XAU/XAG monthly Siegel-Tukey tail-occupancy reversion
publisher: QuantMechanica governed AI synthesis from peer-reviewed carrier and statistical-method research plus official exchange and NIST records
source_type: ai_originated_peer_reviewed_exchange_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-02_xauxag_monthly_siegel_tukey_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
  - AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901
parent_sha256:
  SCHWEIKERT-QC-2018: 7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
  AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901: 3BDFD314CAC96641DC994553CBB023FC88AFD7F435DDDCD296D30C9BAB6171C2
created: 2026-09-02
created_by: Research+Development
cards_extracted: []
---

# XAU/XAG Monthly Siegel-Tukey Tail-Occupancy Reversion

## Canonical origin and claim boundary

This is the single R1 lineage for one bounded AI-originated strategy under the
current explicit OWNER request for a new structural, low-frequency commodity
sleeve. The idea was fixed before market testing: compare eight older and eight
newer synchronized monthly gold/silver log-ratio changes with the
Siegel-Tukey alternating-extremes rank construction. When the newer block
occupies the inclusive lower half of that transformed-rank support, fade its
cumulative relative move for one broker month through opposed XAU/XAG legs.

Schweikert (2018) supports only a state-dependent gold/silver relationship and
supplies binding adverse evidence against a constant spread. CME supports the
gold/silver ratio, different demand drivers, and an opposed-leg carrier. Siegel
and Tukey (1960) and NIST support the named relative-spread rank construction.
The time-series blocks, half-support activity boundary, contrarian mapping,
continuous-CFD translation, equal-notional package, risk, and lifecycle are an
untested QM synthesis.

No source tests this rule on Darwinex continuous CFDs or supplies its return,
profit factor, p-value, threshold, drawdown, package count, transaction cost,
hedge ratio, neutrality, correlation, or portfolio fit. Q02 owns activity and
economics; unchanged Q09 alone owns realized portfolio overlap.

## Supporting evidence and complete bounded reads

The governed relationship packet is
`strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
`7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`.
It records a complete 32-page author-preprint read of Schweikert (2018),
*Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`. Its state dependence, asymmetric relation,
failed constant-vector specifications, and no-direct-forecast warning remain
adverse evidence rather than being discarded.

The official carrier packet is
`strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
`2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.
CME defines gold price divided by silver price and distinguishes gold's
monetary/safe-haven demand from silver's industrial-cycle exposure. Futures
margin, liquidity, and execution properties do not transfer to the two CFDs.

The method packet is
`strategy-seeds/sources/AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901/source.md`,
SHA-256
`3BDFD314CAC96641DC994553CBB023FC88AFD7F435DDDCD296D30C9BAB6171C2`.
It preserves publisher metadata and the abstract for Siegel and Tukey (1960),
*Journal of the American Statistical Association* 55(291), 429-445, DOI
`10.1080/01621459.1960.10482073`, plus a complete read and stable visible-text
hash of NIST's Dataplot `SIEGEL TUKEY TEST` page. The original article body was
access-controlled and is not represented as read. Retrieval roles and limits
are recorded in `retrieval_route_20260902.json`.

## Locked hypothesis and exact formula

Gold and silver share precious-metal and USD shocks but differ in safe-haven,
monetary, industrial, and business-cycle exposure. A recent block that
occupies both tails of the pooled relative-change distribution may represent
an unusually dispersed relative displacement. The candidate tests whether
that displacement partially reverses in the next broker month.

At the first synchronized executable D1 boundary of a new broker month:

1. Reconstruct seventeen consecutive completed synchronized XAU/XAG
   month-end pairs, oldest to newest, excluding every current-month price.
2. Form the log-ratio levels and sixteen chronological changes:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..16
r[i] = q[i+1] - q[i], i=0..15
old = r[0..7]
recent = r[8..15]
```

3. Require all changes finite and pairwise distinct under relative epsilon
   `1e-12`. Sort the pooled changes ascending while preserving old/recent
   labels.
4. Assign the exact ascending-observation Siegel-Tukey scores:

```text
rank position:  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16
ST score:       1  4  5  8  9 12 13 16 15 14 11 10  7  6  3  2
S_recent = sum(score at each recent-labelled rank position)
```

5. Enumerate all `C(16,8)=12,870` fixed-size recent-label allocations and
   count `tail_count = count(S_perm <= S_recent)`. Require both
   `S_recent <= 68` and `tail_count <= 6,698`; their equivalence is a runtime
   invariant. A larger score consumes the month flat.
6. Let `recent_move=sum(r[8..15])`. If the state qualifies and
   `recent_move>1e-12`, sell XAU and buy XAG. If it qualifies and
   `recent_move<-1e-12`, buy XAU and sell XAG. A neutral move consumes flat.
   Score and move magnitude never size risk.

The source method concerns independent samples. These chronological blocks
overlap in market regime and are not independent randomized samples. The EA
therefore uses the arithmetic only as a deterministic tail-occupancy state,
not as a test, p-value, critical value, or causal claim.

## Exact pre-data activity boundary

Complete enumeration of all 12,870 strict-rank label allocations gives 6,698
allocations at or below score 68, including 526 exactly at the boundary. The
fraction is `0.5204351204351204`, or 6.245 theoretical qualifying states per
twelve month clocks before market values, neutral moves, data gates, spreads,
ATR, sizing, and execution. Receipt:
`artifacts/qm5_xauxag_msiegel_tukey_rv_threshold_density_20260902.json`.

This enumeration uses no market data and is not a realized frequency or
performance estimate. Q02 retires zero packages or fewer than five completed
packages in any full scored post-warm-up year.

## Non-duplicate boundary

The fail-closed corrected-root receipt
`artifacts/qm5_xauxag_msiegel_tukey_rv_preallocation_dedup_20260902.json`
checks 4,785 registry identities, 1,421 cards, and all 45 Strategy Wiki nodes.
It finds no exact identity and raises only expected method/carrier neighbors.

- `QM5_41271` uses the same reputable rank construction on direct WTI and
  continues WTI's recent move. This candidate owns synchronized XAU/XAG ratio
  history, two distinct magics, opposed legs, aggregate package risk, and the
  opposite relative-value action. It is a declared carrier-and-payoff port,
  not a reused WTI return stream.
- `QM5_41282`, `QM5_41278`, `QM5_41263`, and `QM5_41279` use twelve changes,
  six-by-six labels, and respectively normal, Cucconi, Kuiper, or Savage
  states. This candidate uses sixteen changes, eight-by-eight labels, a
  nonmonotone alternating-extremes permutation, and a one-sided scale support.
- The scale baskets `QM5_41265`, `QM5_41269`, and `QM5_41281` respectively
  use Brown-Forsythe deviations, centered Klotz scores, or centered Conover
  squared ranks. None uses raw-change alternating-extremes ranks.
- On chronological centered ranks
  `[7,6,1,8,14,9,5,15,2,12,3,11,4,10,16,13]`, this rule scores 61 with tail
  3,252 and sells XAU; the latest-twelve Van der Waerden and Savage neighbors
  are flat at tails 854 and 798.
- On the fixed recent-rank allocation `(1,2,3,4,5,6,8,9)` in one-based
  notation, this rule scores 70 and is flat, while both latest-twelve Van der
  Waerden and Savage neighbors buy XAU. The reference test freezes the exact
  chronological values and neighbor outputs.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_FIXED_EIGHT_BY_EIGHT_SIEGEL_TUKEY_ALTERNATING_EXTREMES_LOWER_HALF_RECENT_MOVE_CONTRARIAN_BASKET`.

## Executable mechanization

- Evaluate only from exact `XAUUSD.DWX` D1 with registered XAG slot 1.
- Consume one normalized broker-month attempt before every fallible gate and
  never retry within the month.
- Require seventeen consecutive timestamp-matched completed month-end pairs;
  the newest pair must immediately precede the current month and be no more
  than ten calendar days stale.
- Permit no foreign position on either symbol and no owned exposure before a
  new package.
- Submit XAU first and XAG second through governed basket order handling.
  Flatten every owned leg immediately if the opposed package is incomplete or
  malformed.
- Exit both legs at the first later synchronized broker month, after forty
  elapsed calendar days, or on package corruption.

## Risk, execution, and failure boundary

- Backtest package: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Split the frozen stop-risk budget equally across two independent
  `3.5*ATR(20,D1)` hard stops.
- Target equal absolute USD notionals by volume reduction only; reject more
  than 20 percent mismatch.
- Reject XAU/XAG spreads above 1,500/500 points.
- Both news axes, legacy mode, Friday close, and stress rejection are OFF.
- No target, trail, break-even, partial close, scale-in, pyramid, intramonth
  retry, external feed, randomized runtime path, or trained output.

Retire on formula or fixture mismatch, zero completed packages, fewer than
five completed packages in any full scored post-warm-up year, nonpositive
governed economics, malformed atomicity, missing stops, nondeterminism, or any
downstream gate failure. No post-result parameter repair is authorized.

Equal target notionals and opposed legs are market-neutral-style construction
only. They do not establish dollar, beta, volatility, factor, or portfolio
neutrality. No optimization, manual tester run, live/demo/shadow/stress set,
portfolio-gate change, deploy/live manifest, `T_Live`, AutoTrading, or live
use is authorized.
