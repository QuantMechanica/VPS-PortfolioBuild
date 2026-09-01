---
source_id: AI-CODEX-WTI-MAB-SCALE-20260901
source_type: ai_originated_governed_synthesis
title: WTI monthly Ansari-Bradley symmetric-rank tail continuation
author: OpenAI Codex
supporting_authors: A. R. Ansari; R. A. Bradley; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; SciPy community
status: approved_source_complete
approval_basis: decisions/2026-09-01_wti_monthly_ansari_bradley_scale_trend_source_approval.md
created: 2026-09-01
created_by: Codex
last_reviewed: 2026-09-01
cards_extracted:
  - QM5_41261_wti-mab-scale-tr
---

# WTI Monthly Ansari-Bradley Symmetric-Rank Tail Continuation

## Canonical origin

This packet is the single R1 lineage for one bounded AI-originated strategy.
The current explicit OWNER mission requests one new structural, low-frequency
commodity/energy sleeve outside the certified XAU/SP500/NDX/XNG book and
expressly permits a direct `XTIUSD.DWX` trend or seasonality construction.
`processes/qb_reputable_source_criteria.md` permits AI-originated sources when
the exact hypothesis and durable prompt/output trail are preserved.

Codex fixed the rule below before any market test and after a fail-closed
canonical duplicate scan. It is not presented as an Ansari-Bradley or
Moskowitz-Ooi-Pedersen trading rule. The cited records support only the
statistical score, its finite no-tie exact route, WTI membership, monthly
own-return continuation, and the explicit boundaries stated below. The
six/six sample, inclusive `522/924` activity boundary, CFD translation, risk,
and lifecycle are transparent pre-result QM choices.

## Supporting evidence and read boundary

### WTI monthly continuation carrier

`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
records a complete 23-page read of Moskowitz, Ooi, and Pedersen (2012),
"Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`. Its retrieval receipt has SHA-256
`ECBCC76CC878F0CC6FBF8C40B23D72084EC6ED03C6375438E3232CC24A33D38F`.
The paper supplies broad monthly own-return continuation evidence and names
WTI among the source commodities. It does not test this rank conjunction or
a continuous CFD.

### Ansari-Bradley method record

Crossref metadata identifies A. R. Ansari and R. A. Bradley (1960),
"Rank-Sum Tests for Dispersions," *The Annals of Mathematical Statistics*
31(4), 1174-1189, DOI `10.1214/aoms/1177705688`, published by the Institute
of Mathematical Statistics. The publisher PDF route returned an Incapsula
block page rather than a PDF, so no unobserved paper-body claim is imported.
The durable access record is
`retrieval_route_ansari_bradley_20260901.json`.

SciPy 1.13.1 official documentation and pinned source at commit
`44e4ebaac992fde33f04638b99629d23973cb9b2` were read completely for the
bounded `ansari` function. The documentation describes a nonparametric test
for equality of scale and states that its p-value route is exact when both
samples contain fewer than 55 observations and have no ties. The pinned
source constructs pooled ranks, assigns the symmetric score
`min(rank, N-rank+1)`, sums the score for the first sample, and records that
smaller sums correspond to larger dispersion for that sample. Receipt:
`retrieval_route_scipy_ansari_20260901.json`.

The EA does not call SciPy or reproduce its p-value machinery. It implements
the fixed `N=12`, `n=m=6`, no-tie score directly and enumerates every one of
the 924 label assignments. The loose trading boundary is not a published
critical value, statistical-significance claim, or scale estimate.

## Pre-result hypothesis

WTI has physical supply, storage, transport, refining, producer-hedging,
geopolitical, and end-demand drivers that are absent from the certified
index/metal carriers and materially different from natural-gas weather and
storage exposure. When the newest six completed monthly WTI returns occupy
at least as much of the pooled distribution's symmetric tails as its center,
continue the sign of their cumulative return for one broker month.

This is a direct-crude structural trend hypothesis. The symmetric-rank gate
is a robust tail-occupancy state, not proof of a volatility change. A location
shift can affect the score because the unadjusted Ansari-Bradley construction
assumes a common location; that is an explicit limitation, not hidden
evidence. Q02 owns realized activity and economics. Later gates own
robustness, and unchanged Q09 alone owns portfolio correlation.

## Exact frozen mechanic

At the first executable D1 tick of a genuine new normalized broker month:

1. Reconstruct thirteen immediately prior consecutive completed broker-month
   end closes `C[0..12]`, oldest to newest. Exclude every current-month price.
2. Compute twelve adjacent log returns
   `r[i]=log(C[i+1]/C[i])`, with `old=r[0..5]` and
   `recent=r[6..11]`.
3. Require every return finite and all twelve returns pairwise distinct.
4. Sort the pooled returns ascending while retaining old/recent labels. For
   pooled rank `j=1..12`, assign
   `score(j)=min(j,13-j)`, giving `1,2,3,4,5,6,6,5,4,3,2,1`.
5. Sum `A_recent` over the six ranks carrying actual recent labels.
6. Enumerate all 12-bit masks with exactly six set bits. For each assignment,
   compute the same symmetric score sum `A_perm`; increment `tail_count` when
   `A_perm <= A_recent`.
7. Require exactly 924 assignments, `A_recent <= 21`, and
   `tail_count <= 522`.
8. Let `recent_return=sum(r[6..11])`. Buy WTI when it is greater than
   `1e-12`, sell WTI when it is less than `-1e-12`, and stay flat otherwise.
9. Consume the month before every fallible entry gate. Use one aggregate
   `RISK_FIXED=1000` position, a frozen `3.5*ATR(20,D1)` hard stop, no target,
   a 1,500-point spread ceiling, next-month exit, and forty-day stale repair.

The exact symmetric-score distribution over all 924 assignments is:

```text
score: 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30
count:  1  4  9 20 34 56 75 96 107 120 107 96 75 56 34 20  9  4  1
```

Thus the inclusive boundary admits exactly `522/924` strict-rank label paths,
or `6.779` states per twelve market-free monthly attempts before a zero
cumulative return and downstream market/execution gates. This calculation is
an activity prior only. It does not guarantee the Q02 floor.

## Non-duplicate decision

The corrected-root canonical receipt
`artifacts/qm5_wti_mab_scale_tr_preallocation_dedup_20260901.json`, SHA-256
`2A4F4D50F5B36A20BDCC3950C1A334615F2DEF38F42136C05EA422D4DF967E74`,
found no exact or fuzzy identity across 4,760 registry rows, 1,397 card files,
and 45 Strategy Wiki nodes.

Manual review resolves the closest semantic neighbors:

- `QM5_41250_wti-mperm-scale-tr` recalculates magnitude-sensitive within-
  block medians and MADs for every relabeling, requires a positive MAD
  difference, and uses an upper-tail cap of 416. This rule discards return
  spacing after sorting, uses the fixed symmetric end-rank score, and applies
  the exact lower tail through 522.
- `QM5_41252_wti-css-volshift-tr` retains the order of 252 daily returns,
  mean-centers and squares them, searches an interior variance-change point,
  and performs no label enumeration. This rule uses twelve monthly returns,
  a fixed six/six membership, no squared return, and no time-split search.
- `QM5_41257_wti-mmedscore524-tr` counts recent labels in the upper six pooled
  ranks and detects location. This rule assigns symmetric scores from both
  tails and can qualify with exactly three recent labels above the median.
- `QM5_41176_wti-mwilcoxon-shift-tr` aggregates monotone ranks for a location
  shift. This rule deliberately gives the same score to mirrored ranks and
  therefore discards signed location ordering at its qualification gate.

On pooled values `[-5.5,-4.5,...,5.5]`, recent ranks `{1,2,3,4,5,6}` give
`A_recent=21`, lower tail 522, and qualify here while the permutation-MAD
delta is zero. Recent ranks `{1,2,3,4,6,7}` give `A_recent=22` and are flat
here while permutation MAD qualifies at tail 340. Recent ranks
`{1,2,3,7,8,9}` qualify here with three observations above the pooled median,
where the median-score rule is neutral. These fixed fixtures prove decision
disagreement, not economic merit.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_ANSARI_BRADLEY_SYMMETRIC_END_RANK_EXACT_924_LOWER_TAIL522_CUMULATIVE_RETURN_CONTINUATION`.

## Reputable-source criteria

- **R1 — PASS_WITH_PRIMARY_SOFTWARE_AND_PAPER_ACCESS_BOUNDARY.** One durable
  AI source ID, a complete-read peer-reviewed WTI record, authoritative
  Crossref bibliographic metadata, pinned official SciPy documentation and
  source, and an explicit publisher-body access limit.
- **R2 — PASS.** Month clock, endpoints, returns, strict ties, symmetric score,
  all 924 assignments, inclusive boundary, side, attempt, risk, stop, spread,
  and lifecycle are fully mechanical.
- **R3 — PASS.** Registered `XTIUSD.DWX` D1 and MT5-native state provide every
  runtime input. Continuous-CFD roll, basis, financing, gaps, and broker-month
  labels remain explicit risks.
- **R4 — PASS.** Deterministic timestamps, completed prices, logarithms,
  sorting, fixed integer enumeration, arithmetic, ATR risk, quotes, positions,
  deals, and persistent state only; no ML, prohibited signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Kill and safety boundaries

Retire on a failed reference fixture, a tie accepted as valid, an assignment
count other than 924, a wrong score/tail identity, zero trades, fewer than five
completed positions in any full post-warm-up year, or failed governed
economics. No threshold may be repaired after observing Q02.

Authorized after card G0 and registry gates: one branch-only EA build,
reference tests, strict Q01 compile, one D1 `RISK_FIXED=1000` backtest set, and
one paced non-live Q02 enqueue if CPU admission permits. Excluded: manual
tester launch, optimization, live/demo/shadow/stress presets, `T_Live`,
AutoTrading, deploy/live manifests, portfolio-gate mutation, portfolio
admission, correlation waiver, terminal control, or component variants.
