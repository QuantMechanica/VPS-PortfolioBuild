---
source_id: SCHWEIKERT-NIST-KS2-CME-XAUXAG-MDIST-RV-2026
title: XAU/XAG twelve-month fixed-block signed-ECDF distribution-shift reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed relationship and official method research
source_type: peer_reviewed_exchange_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-27_xauxag_monthly_ks_distribution_shift_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
  - MOP-NIST-KS2-WTI-MDIST-SHIFT-2026
parent_sha256:
  SCHWEIKERT-QC-2018: 7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
  MOP-NIST-KS2-WTI-MDIST-SHIFT-2026: CDCEC4537A50040C1074C94FA5B29EF1038B9E72EB0798FF24D940021C2054BA
method_source_id: NIST-DATAPLOT-KS2SAMP
created: 2026-08-27
created_by: Research+Development
cards_extracted:
  - xauxag-mks-rv
---

# XAU/XAG Fixed-Block Signed-ECDF Distribution-Shift Reversion Source Packet

## Approval And Bounded Read

The durable approval is
`decisions/2026-08-27_xauxag_monthly_ks_distribution_shift_reversion_source_approval.md`,
committed as `673be5a44` before this extraction. The approval authorizes one
bounded source packet and card for the current OWNER commodity/energy
portfolio mission. The three parent packets named above were read completely.

No new public URL, blocked content, inferred page, or external runtime source
enters this extraction.

## Sources Of Record

### Gold/silver relationship

Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
from quantile cointegrating regressions," *Journal of Banking & Finance* 88,
44-51, DOI `10.1016/j.jbankfin.2017.11.010`, is preserved in the complete-read
packet `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`.

The paper finds state-dependent and asymmetric spot and futures relations.
It also supplies binding adverse evidence: constant-vector specifications are
not uniformly supported, important daily upper-quantile cases reject
cointegration, the relevant state is not known ex ante, and the estimates do
not directly produce a forecast. This packet therefore treats relative-value
reversion as a falsifiable hypothesis, not a transferred result.

### Intermarket carrier

The official CME packet
`strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` defines the gold/silver
ratio as the gold price divided by the silver price per troy ounce, identifies
gold's stronger monetary/safe-haven role and silver's stronger industrial-
cycle role, and describes the ratio as a tradable intermarket spread.

The EA does not use CME prices, futures chains, contract rolls, inventory,
open interest, or any external API. The continuous XAU/XAG CFDs are a QM
carrier translation whose basis, financing, calendar, and synchronization
risks remain unproven until the deterministic pipeline measures them.

### Two-sample ECDF method

The operative statistical record is the official NIST Dataplot Reference
Manual page "Kolmogorov-Smirnov Two-Sample Goodness of Fit Test":
`https://www.itl.nist.gov/div898/software/dataplot/refman1/auxillar/ks2samp.htm`.
The complete 271-line page and authenticated content hash are recorded under
`strategy-seeds/sources/MOP-NIST-KS2-WTI-MDIST-SHIFT-2026/`.

NIST defines two empirical distribution functions evaluated at observations
from both samples and a statistic based on their maximum absolute separation.
NIST also warns that the statistic and critical values must use consistent
scaling. This extraction imports no critical value, p-value, distributional
fit, or significance interpretation. It uses exact integer count gaps as a
transparent effect-size gate.

## Source Claim Boundary

The sources jointly motivate a bounded question: after a large ordinal
displacement between the latest six synchronized monthly gold/silver ratios
and the prior six, does the relative displacement revert during the next
month?

No source tests this exact rule. The synchronized endpoints, log-ratio
orientation, fixed six/six split, no-tie rule, signed count gap, inclusive
three-count boundary, contrarian sides, continuous-CFD mapping, equal-
notional package, fixed-dollar risk, stops, spreads, attempt persistence,
atomicity, and lifecycle are disclosed QM choices.

No source return, alpha, win rate, probability, trade density, profit factor,
drawdown, transaction cost, hedge ratio, neutrality, CFD equivalence,
decorrelation, or portfolio statistic transfers.

## Exact Statistical Contract

For twelve synchronized, positive, finite, pairwise-distinct completed-
month gold-minus-silver log ratios `L[0]..L[11]`, oldest to newest, define:

```text
O = L[0..5]   # older six
N = L[6..11]  # newer six

old_seen = 0
new_seen = 0
Dplus = 0
Dminus = 0

scan all twelve ratios from smallest to largest while preserving O/N labels:
    increment old_seen for O, otherwise increment new_seen
    delta = old_seen - new_seen
    Dplus  = max(Dplus,  delta)
    Dminus = max(Dminus, -delta)

require exactly twelve scanned observations
require old_seen == 6 and new_seen == 6
require 0 <= Dplus <= 6 and 0 <= Dminus <= 6

SELL XAU / BUY XAG iff Dplus  >= 3 and Dplus  > Dminus
BUY XAU / SELL XAG iff Dminus >= 3 and Dminus > Dplus
FLAT otherwise
```

`Dplus/6` is the largest `F_old-F_new` ECDF gap. A dominant positive gap
means lower thresholds contain more older ratios and the newer distribution
is displaced higher, so the basket fades that state by selling the XAU/XAG
ratio. `Dminus/6` maps symmetrically to a long-ratio fade. Equal maxima,
weaker gaps, or invalid data consume the month flat.

No rank sum, cross-block pair total, variable split, maximum over change-point
locations, fitted center, fitted scale, residual, regression, p-value,
critical table, endpoint return, fallback, signal-strength sizing, seasonal
direction, moving average, or oscillator exists.

## Pre-Result Density Boundary

With strict values, only the six newer labels among twelve combined ranks
matter. Exact enumeration of all `C(12,6)=924` assignments gives:

- 218 dominant high-distribution fades at `Dplus>=3`;
- 218 dominant low-distribution fades at `Dminus>=3`;
- 486 weak flats;
- two tied-extreme flats; and
- directional qualification `436/924=109/231`, approximately
  `0.4718614719`.

At twelve monthly decisions this is approximately 5.662 qualifying states in
a random-rank reference year. The count is a pre-market density check near
but above the unchanged five-trades/year floor. It is not a market
probability, independence assumption, statistical rejection level, or
performance estimate.

## Locked Trading Translation

At the first synchronized executable `XAUUSD.DWX` D1 tick after a genuine
broker-month transition:

1. Normalize and persist the current broker `yyyymm` before history, signal,
   news, spread, quote, ATR, sizing, margin, or order gates. Never retry the
   month.
2. Exclude the current month. Reconstruct exactly twelve immediately prior
   consecutive broker months. For each month select the latest D1 timestamp
   shared exactly by XAU and XAG. Reject missing/duplicate months, unmatched
   endpoints, nonchronological timestamps, nonpositive/nonfinite closes, or a
   newest pair more than ten calendar days stale.
3. Calculate `L[i]=ln(XAU_close[i])-ln(XAG_close[i])`, reject every exact tie,
   retain fixed block labels, and calculate the two signed ECDF count maxima.
4. Consume flat unless exactly one maximum dominates at the inclusive count
   boundary three. A high newer distribution sells XAU and buys XAG; a low
   newer distribution buys XAU and sells XAG.
5. Open at most one opposite-side equal-target-notional package under one
   aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Split frozen-stop risk equally, use
   `3.5*ATR(20,D1)` hard stops, reject XAU/XAG spreads above 1,500/500 points,
   and reject rounded target-notional mismatch above 20 percent.
6. Submit XAU first and XAG second. Keep exposure only when one correct,
   stopped position exists under each registered magic. Any partial, failed,
   orphaned, duplicated, same-side, stopless, or imbalanced state closes all
   owned legs immediately.
7. Close the complete package on the first tick in a later broker month or
   after forty elapsed calendar days. No intramonth signal flip, convergence
   target, trail, break-even, partial close, Friday close, or news exit is
   authorized.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 history and timestamps, logarithms, comparisons, integer
counts, broker calendar, quotes, metadata, ATR, positions, deals, and
terminal-persistent attempt state.

## Non-Duplicate Functional Boundary

The fail-closed preallocation receipt is
`artifacts/qm5_xauxag_mks_rv_preallocation_dedup_20260827.json`. It scanned
4,686 registry rows, 1,337 cards, and the actual 45-node Strategy Wiki. There
was no exact identity. Its conservative `FUZZY_MATCH` outcome reflects the
shared XAU/XAG carrier and is resolved by the following load-bearing
distinctions:

- `QM5_41177_xauxag-mwilcoxon-shift-rv` uses all 36 old/new comparisons and
  thresholds their total. This rule retains only the largest vertical ECDF
  separation. Rank path `[1,2,3,5,11,12,4,6,7,8,9,10]` produces a high-
  distribution fade here at maxima `(3,2)` while Mann-Whitney is flat at
  `U_new=23`. Path `[1,2,4,6,8,10,3,5,7,9,11,12]` stays flat here at
  `(2,0)` while Mann-Whitney fades high at `U_new=26`. Reflections supply the
  symmetric low cases.
- `QM5_41183_wti-mks-shift-tr` uses the same statistic on outright WTI and
  continues the displaced distribution with one position. This rule computes
  synchronized XAU/XAG ratios, reverses the side, shares risk across two
  opposite legs, and enforces atomic package integrity.
- `QM5_20263_xauxag-mad-rv` uses a 63-D1 rolling median/MAD standardized
  fresh cross and a convergence exit. This rule has no center, scale, daily
  cross, or convergence exit.
- `QM5_20161_xauxag-ols-rv` fits an OLS hedge ratio and standardized residual;
  this rule fits no coefficient or residual.
- `QM5_12724_cme-xauxag-brk` follows a daily channel extreme; this rule fades
  a fixed-block monthly distribution shift.
- `QM5_20202_xauxag-rev18` ranks two separate 18-month leg returns; this rule
  evaluates one synchronized ratio series over twelve completed months.
- `QM5_20234_xauxag-rsj` ranks one-month signed jumps; this rule uses no jump
  or cross-sectional moment.
- Pettitt relocates a change point; Mann-Kendall and Spearman aggregate other
  rank functionals; Cox-Stuart uses paired signs; fractional-difference,
  regression, robust-location, variance-ratio, calendar, flow, and endpoint
  systems use different information objects.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_FIXED_SIX_BY_SIX_SIGNED_KS_GAP3_DISTRIBUTION_SHIFT_REVERSION_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete peer-reviewed
  gold/silver evidence with adverse findings, official exchange carrier
  research, and a complete official NIST method record; the conjunction is
  untested.
- R2 `PASS`: decision clock, synchronization, consecutive months, ratio
  orientation, fixed blocks, strict ties, both count maxima, boundary,
  contrarian sides, attempt, aggregate risk, atomicity, and lifecycle are
  deterministic and locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories and MT5-native state provide every runtime
  input.
- R4 `PASS`: fixed native arithmetic and state only; no trained output,
  prohibited signal, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Falsification And Safety Boundary

Retire at zero trades, fewer than five completed packages in any full post-
warm-up year, nonpositive governed economics, downstream gate failure, or any
month, endpoint, synchronization, ratio, block, tie, count, boundary, side,
attempt, risk, package, lifecycle, or determinism defect. No failed result may
be rescued by changing the sample, split, threshold, direction, carrier,
risk, hold, or by adding another gate.

Equal target notionals and opposite legs are market-neutral-style
construction only. They do not establish dollar, beta, volatility, factor,
market, or portfolio neutrality. Unchanged Q09 alone owns realized overlap.

This packet authorizes one locked card, deterministic identity allocation,
one branch-only non-live build, strict Q01, and one paced target-only Q02
enqueue below the factory CPU ceiling. It does not authorize a manual
backtest; live, demo, shadow, stress, or optimization preset; AutoTrading;
`T_Live`; deploy or live manifest; portfolio-gate mutation; portfolio
admission; correlation waiver; terminal control; or component-leg Q02 row.

## Revision History

| version | date | change | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-08-27 | bounded relationship/carrier/method extraction | G0 | APPROVED_SOURCE |
