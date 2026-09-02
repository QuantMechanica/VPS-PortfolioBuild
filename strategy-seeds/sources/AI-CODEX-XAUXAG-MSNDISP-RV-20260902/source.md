---
source_id: AI-CODEX-XAUXAG-MSNDISP-RV-20260902
title: XAU/XAG completed-month Sn-core displacement reversion
publisher: QuantMechanica governed synthesis from peer-reviewed relationship and robust-scale research plus official exchange and pinned primary-software records
source_type: ai_originated_peer_reviewed_exchange_primary_software_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-02_xauxag_monthly_sn_dispersion_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
  - AI-CODEX-WTI-MSNDISP-TREND-20260901
parent_sha256:
  SCHWEIKERT-QC-2018: 7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
  AI-CODEX-WTI-MSNDISP-TREND-20260901: A64C6D7FDFFA34CAB48006D52FF9F06E36A3017276C5EC06DAB6E80383AE48D2
created: 2026-09-02
created_by: Research+Development
cards_extracted:
  - xauxag-msndisp-rv
---

# XAU/XAG Completed-Month Sn-Core Displacement Reversion

## Approval and complete bounded read

The durable approval for this source is
`decisions/2026-09-02_xauxag_monthly_sn_dispersion_reversion_source_approval.md`.
The current explicit OWNER mission authorizes one new structural,
low-frequency commodity sleeve, expressly permits a market-neutral-style
gold/silver basket, requires reputable-source criteria and fixed-risk
backtests, and requests one paced Q02 enqueue.

The three complete governed parent packets named in the frontmatter were read
in full. Their exact paths, hashes, roles, and underlying retrieval receipts
are bound in `retrieval_route_20260902.json`; no new web page was represented
as read.

Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`, supplies a peer-reviewed, state-dependent
gold/silver relationship and binding adverse evidence against assuming one
stable constant spread. CME Group supplies the official gold/silver ratio
definition, distinct gold monetary/safe-haven and silver industrial demand
drivers, and an opposed-leg spread carrier. Rousseeuw and Croux (1993),
*Journal of the American Statistical Association* 88(424), 1273-1283, DOI
`10.1080/01621459.1993.10476408`, plus commit-pinned CRAN `robustbase` source,
supplies the raw Sn nested-median functional and exact even-sample convention.

None of these records tests the conjunction below, a Darwinex continuous-CFD
pair, the three-core boundary, one-month reversion, equal target notionals,
fixed risk, stops, activity, costs, profitability, neutrality, or portfolio
correlation. Those are transparent pre-result QuantMechanica choices.

## Locked hypothesis and formula

Gold and silver share precious-metal and USD shocks but have materially
different demand mixes. The hypothesis is that an unusually coherent
gold-minus-silver displacement during one completed broker month can partially
reverse during the next month. Raw Sn supplies a robust within-month scale;
it is not used as a statistical test or a forecast supplied by the method
paper.

At the first synchronized executable `XAUUSD.DWX` D1 boundary of a genuine new
broker month:

1. Reconstruct every timestamp-matched XAU/XAG D1 close pair in the
   immediately completed broker month. Require 17 through 23 matched sessions.
2. Keep its final seventeen chronological pairs only. Exclude every current-
   month observation.
3. Form ratio levels and sixteen adjacent changes:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..16
r[i] = q[i+1] - q[i], i=0..15
net  = sum(r)
require abs(net - (q[16]-q[0])) <= 1e-10
```

4. Compute the unscaled raw Sn core:

```text
for i=0..15:
    D_i = sort(abs(r[i]-r[j]) for j=0..15, j!=i)
    require len(D_i) == 15
    inner[i] = D_i[7]          # eighth one-based lower median

I = sort(inner)
sn_core = I[7]                 # eighth one-based outer lower median
require sn_core > 1e-12
```

5. Deliberately omit the `1.1926` normal-consistency multiplier and all
   finite-sample multipliers. Let `threshold=3*sn_core`.
6. If `net>=threshold`, sell XAU and buy XAG. If `net<=-threshold`, buy XAU
   and sell XAG. Otherwise consume the month flat. Magnitudes never size risk.

This exact signal differs from the direct-WTI Sn parent in both carrier and
payoff: the parent opens one WTI leg in continuation direction; this strategy
opens two opposed precious-metal legs and fades the relative displacement.

## Entry, risk, and lifecycle

Persist the normalized broker month as attempted before history, signal,
news, spread, quote, ATR, sizing, margin, or order gates. Never retry a
consumed month. Permit no foreign exposure on either leg and no owned exposure
before a new package.

The only Q02 package uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Split the frozen stop-risk budget equally across two
independent `3.5*ATR(20,D1)` hard stops. Target equal absolute USD notionals
by volume reduction only; reject more than twenty percent mismatch. Reject
XAU/XAG spreads above 1,500/500 points. Submit XAU first, XAG second, and
flatten all owned legs immediately if the package is incomplete or malformed.

Close both legs at the first synchronized tick in a later broker month or
after forty elapsed calendar days. Missing or inconsistent symbol, ownership,
side, stop, entry time, or persisted entry-month state causes defensive
closure. There is no intramonth signal exit, target, trail, break-even move,
partial close, retry, scale-in, grid, martingale, or pyramid. Both news axes,
legacy news, Friday close, and stress rejection are off.

## Reputable-source criteria

- R1: `PASS_WITH_AI_SYNTHESIS_PEER_REVIEW_EXCHANGE_AND_PRIMARY_SOFTWARE_EVIDENCE`.
  One durable AI lineage source binds complete governed parent packets,
  immutable hashes, a complete peer-reviewed gold/silver preprint read, an
  official exchange carrier, a complete robust-scale paper read, and pinned
  primary software. The exact trading synthesis is disclosed.
- R2: `PASS`. Clock, matched sessions, final-seventeen selection, ratio and
  return orientation, endpoint identity, all 240 directed distances, inner
  and outer lower medians, omitted multipliers, inclusive boundary, side,
  consumed attempt, aggregate risk, atomicity, and lifecycle are locked.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
  native XAU and XAG D1 histories and MT5 state supply every runtime input;
  session synchronization, rolls, basis, financing, gaps, and legging remain.
- R4: `PASS`. Only timestamps, completed prices, logarithms, sorting,
  comparisons, ATR risk controls, quotes, positions, deals, and persistent
  state are used. No trained output or external runtime feed is authorized.

## Duplicate boundary

The corrected-root deterministic receipt
`artifacts/qm5_xauxag_msndisp_rv_preallocation_dedup_20260902.json` returned
`CLEAN` across 4,803 registry rows, 1,432 card files, and 45 Strategy Wiki
nodes. Manual family review resolves the semantically nearest systems:

- `QM5_41277` uses the same Sn arithmetic on sixteen direct-WTI daily returns,
  opens one WTI position, and continues the move. This rule uses synchronized
  gold/silver relative returns, two magics, opposed equal-notional legs, and
  contrarian payoff.
- `QM5_20263` uses a rolling 63-level ratio median/MAD score and a fresh daily
  threshold crossing. It neither reconstructs one completed month nor uses
  pairwise-distance nested medians or a monthly net-to-core boundary.
- `QM5_41286` uses seventeen monthly endpoints, fixed old/recent eight-change
  blocks, alternating-extremes Siegel-Tukey ranks, and exhaustive label
  enumeration. This rule uses seventeen daily pairs from one month, no blocks,
  no ranks, and all 240 directed pairwise distances.
- Brown-Forsythe, Klotz, Conover, Anderson-Darling, Cucconi, Kuiper, Savage,
  Van der Waerden, MAD, Qn, L1-coherence, and RMS-coherence relatives have
  different state objects and boundaries.
- `QM5_20194` ranks separate 12- and 18-month leg returns and trades only when
  those cross-horizon rankings disagree; it has no within-month dispersion.

The synthetic receipt
`artifacts/qm5_xauxag_msndisp_rv_reference_fixture_20260902.json` locks a
positive and negative Sn-only state and a neighbor-only state. In the first,
`abs(net)/sn_core=3.0778518652`, so this candidate trades while Qn, L1, and RMS
neighbors stay flat. In the second, `abs(net)/sn_core=2.9332708236`, so this
candidate stays flat while all three neighbors trade.

Verdict:
`FUZZY_FAMILY_REVIEW_RESOLVED_DISTINCT_XAUXAG_COMPLETED_MONTH_FINAL17_SYNCHRONIZED_D1_RATIO_CHANGE_RAW_SN_THREE_CORE_CONTRARIAN_BASKET`.

## Frequency, validation, and kill boundary

There is one consumed attempt per broker month and at most twelve packages per
full year. Six to eight packages is an explicitly uncalibrated planning prior,
not a source result. Q02 must retire zero packages or fewer than five completed
packages in any full post-warm-up year.

Independent reference tests must reproduce both directions, the neighbor-only
flat state, timestamp synchronization, immediately completed month membership,
final-seventeen selection, endpoint identity, 240 distances, exact lower-
median indexes, omitted multipliers, inclusive boundary, fixed risk, package
atomicity, and next-month closure.

Retire on formula or fixture mismatch, current-month leakage, malformed
package, missing stop, invalid fixed-risk mode, nonpositive governed economics,
nondeterminism, or any downstream gate failure. No result-based change to the
sample, median convention, threshold, side, carrier, risk, stop, spreads, or
hold may rescue failure. Q09 alone owns realized portfolio correlation.

Authorized scope ends after one card, deterministic allocation, one
branch-only non-live build, strict Q01, and one CPU-admitted logical-basket
Q02 enqueue. No manual tester run, optimization, live/demo/shadow/stress set,
portfolio-gate change, correlation waiver, portfolio admission, deploy/live
manifest, `T_Live`, AutoTrading, terminal control, or live use is authorized.
