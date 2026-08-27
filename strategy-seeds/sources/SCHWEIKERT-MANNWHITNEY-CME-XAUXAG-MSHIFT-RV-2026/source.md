---
source_id: SCHWEIKERT-MANNWHITNEY-CME-XAUXAG-MSHIFT-RV-2026
title: XAU/XAG twelve-month fixed-block Mann-Whitney location-shift reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed, exchange, and pinned statistical research
source_type: peer_reviewed_exchange_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-27_xauxag_monthly_mann_whitney_location_shift_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026
  - MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026
parent_sha256:
  SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026: D5E8C4CD0112724D66E64C13B20B7B41CCE1B4CDC2061BA21A979374F04531A8
  MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026: 8D42ED6DF1415B6EDF7FF29AE9349BCA576F0F66204A8021E2E0B8D73B0AEDE0
created: 2026-08-27
created_by: Research+Development
cards_extracted:
  - xauxag-mwilcoxon-shift-rv
---

# XAU/XAG Twelve-Month Mann-Whitney Location-Shift Reversion Source Packet

## Approved Sources Of Record

The relationship source is Karsten Schweikert (2018), "Are gold and silver
cointegrated? New evidence from quantile cointegrating regressions,"
*Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`. The completely read governed parent packet
`strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`
preserves the named peer-reviewed evidence and official CME Group
"Gold & Silver Ratio Spread" carrier research. It records a related but
state-dependent gold/silver relation and distinguishes gold's monetary and
safe-haven exposure from silver's larger industrial and business-cycle
exposure. It does not establish a constant hedge ratio or universal
reversion.

The method parent is
`strategy-seeds/sources/MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026/source.md`.
It preserves H. B. Mann and D. R. Whitney (1947), "On a Test of Whether one
of Two Random Variables is Stochastically Larger than the Other," *The Annals
of Mathematical Statistics* 18(1), 50-60, DOI
`10.1214/aoms/1177730491`, plus the complete R Core Team
`stats::wilcox.test` implementation and manual in the public `wch/r-source`
mirror at commit `7344a2d9d96b3c2b997535d3abc8c3a44af16e82`. The pinned
files define the two-sample statistic as the first sample's combined rank sum
less `m(m+1)/2`, equivalently its favorable cross-sample pair count when ties
are absent. The original 1947 body is not represented as completely read and
no blocked text, table, probability, or result is used.

Both parent packets and the method retrieval receipt were read completely
before the durable OWNER source approval at
`decisions/2026-08-27_xauxag_monthly_mann_whitney_location_shift_reversion_source_approval.md`.

## Source Findings Used

Schweikert supports testing a related but state-dependent gold/silver
relationship without assuming one immutable equilibrium. CME supports the
intermarket ratio carrier and distinct demand drivers. Mann, Whitney, and the
pinned R Core files supply a deterministic two-sample ordinal location
statistic.

These records support a falsifiable relative-value experiment, not a claim
that a fixed half-versus-half monthly ratio shift predicts reversal. The
twelve synchronized endpoints, six/six split, strict no-tie rule, integer
boundaries, contrarian direction, continuous-CFD mapping, equal-notional
target, fixed-dollar risk, hard stops, spread caps, atomic order sequence,
consumed attempt, and lifecycle are transparent QM choices.

No source return, alpha, probability, statistical significance, density,
Sharpe ratio, drawdown, transaction cost, hedge ratio, neutrality, CFD
equivalence, decorrelation, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For twelve positive, finite, pairwise-distinct, exactly timestamp-matched
completed month-end gold/silver close pairs, oldest to newest:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i = 0..11
O = s[0..5]
N = s[6..11]

W_new = sum(combined_rank(N[j]), j=0..5)
U_new = W_new - 6*7/2

equivalently, because ties are forbidden:
U_new = count(N[j] > O[i] for every i=0..5 and j=0..5)
U_old = count(O[i] > N[j] for every i=0..5 and j=0..5)

require 0 <= U_new <= 36
require U_new + U_old == 36
require W_new - 21 == U_new

SELL XAU / BUY XAG iff U_new >= 24
BUY XAU / SELL XAG iff U_new <= 12
FLAT otherwise
```

The two inclusive boundaries are symmetric around 18. Signal magnitude never
changes risk. Exact ties are rejected rather than average-ranked. There is no
p-value, variable split, fitted center or scale, change-point search, endpoint
return, Spearman displacement, sign vote, or fallback signal.

## Pre-Result Density Boundary

The thresholds were locked before any XAU/XAG test. Exact enumeration of the
`choose(12,6)=924` no-tie assignments of combined ranks to the newer block
gives 182 assignments at `U_new>=24` and 182 at `U_new<=12`. The symmetric
qualification rate is `364/924 = 0.3939393939393939`, or
`4.727272727272727` decisions per twelve monthly opportunities under random
rank assignment. This is a density design fact, not a statistical-significance
or gold/silver-performance claim.

The pre-result operating prior is four to eight completed packages per full
post-warm-up year. Q02 must retire below four in any full year, at zero trades,
or with nonpositive governed economics.

## Exact Event And Execution Contract

1. Require exact host `XAUUSD.DWX`, companion `XAGUSD.DWX`, D1, and an entry
   attempt no later than 180 elapsed minutes after the raw current host D1 bar
   open in a genuine new broker month.
2. Persist current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order gates. Never retry the month after a
   flat signal, invalid state, reject, stop, partial fill, or restart.
3. From bounded native D1 buffers, select the latest exactly timestamp-matched
   close pair in each of the immediately prior twelve consecutive broker
   months. Require positive finite closes, finite log ratios, strict
   chronology, the immediately prior newest month, no current-month close,
   and no more than ten calendar days of endpoint staleness.
4. Reject any pairwise-equal log ratios. Split once after observation six,
   count every strict cross-block comparison, prove both pair-count and
   rank-sum identities, and fade only `U_new>=24` or `U_new<=12`.
5. Open at most one equal-target-absolute-USD-notional package under aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Split the
   stop-risk budget equally and size each leg against its frozen
   `3.5*ATR(20,D1)` hard stop. Attach no target, cap spreads at 1,500 XAU
   points and 500 XAG points, and require realized notional mismatch no
   greater than 20%.
6. Submit XAU first and XAG second. Retain only one correctly directed,
   registered, stop-protected position in each slot. Flatten all owned legs
   after any partial or final package validation failure.
7. Close both legs on the first tick in a later broker month or after forty
   calendar days. Immediately repair an orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, wrong-direction, stopless, stale, or notional-
   invalid package.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 histories, timestamps, calendar, quotes, symbol metadata,
ATR, positions, deals, terminal global variables, and V5 framework services.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,676 registry identities, 1,327
cards, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. The
receipt is
`artifacts/qm5_xauxag_mwilcoxon_shift_rv_preallocation_dedup_20260827.json`.

- `QM5_41176_wti-mwilcoxon-shift-tr` applies the same two-sample statistic to
  one outright WTI series, follows its sign, and owns one position. This
  packet constructs a synchronized paired-metal log ratio, fades the shift,
  and owns an atomic equal-notional package.
- `QM5_41174_xauxag-mspearman-rv` uses thirteen ratios and every endpoint's
  squared time-rank displacement. This rule uses twelve ratios, is invariant
  to within-block permutations, and counts only comparisons crossing one
  fixed six/six boundary.
- `QM5_41168_xauxag-mcoxstuart-rv` uses fourteen ratios and seven fixed
  half-sample signs; this rule counts every one of the 36 cross-block ordinal
  comparisons.
- Pettitt searches all candidate splits for a maximum cumulative rank sum;
  this rule has one prespecified split and never searches or maximizes.
- XAU/XAG z-score, OLS, CADF, quantile, MAD, variance-ratio, endpoint,
  quarterly-vote, Theil-Sen, LAD, repeated-median, robust-consensus, path,
  flow, and calendar families calculate different state objects and gates.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback with neither paired-metal exposure nor monthly ordinal
  logic.

For a thirteen-ratio rank path, the candidate uses the latest twelve values.
Path `[11,13,2,4,6,1,3,10,5,7,8,9,12]` gives candidate short-ratio at
`U_new=29`, Spearman flat at `T=52`, and a Pettitt edge maximum at `K=2`.
Path `[1,8,3,5,7,11,9,4,2,12,13,6,10]` gives candidate flat at `U_new=20`
while Spearman qualifies at `T=176`. Path
`[11,10,9,8,3,2,1,13,4,5,6,12,7]` gives candidate short-ratio at the inclusive
`U_new=24` boundary while the Spearman path stays flat.

Verdict:
`CLEAN_XAUXAG_MONTHLY_FIXED_SIX_BY_SIX_MANN_WHITNEY_U24_LOCATION_SHIFT_REVERSION_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: peer-reviewed
  gold/silver relation evidence, official exchange carrier research, named
  original Mann-Whitney record, and complete pinned R Core method files; the
  exact trading conjunction remains untested.
- R2 `PASS`: clock, synchronization, ratio orientation, fixed block
  membership, strict ties, rank/pair-count identities, boundaries,
  contrarian sides, attempt, aggregate risk, atomicity, and lifecycle are
  fixed.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories and MT5 state supply all runtime inputs.
- R4 `PASS`: deterministic logarithms, comparisons, integer arithmetic,
  calendar, ATR risk, and execution state only; no trained output, banned
  signal method, external feed, grid, martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire or fail on any synchronization, endpoint, split, tie, pair-count,
rank-sum, threshold, side, attempt, fixed-risk, notional, atomicity, lifecycle,
or determinism defect; fewer than four completed packages in any full post-
warm-up year; zero trades; nonpositive governed economics; or downstream
portfolio-correlation rejection. No failed result may be rescued by changing
the sample, split, tie rule, boundary, direction, risk, hold, or by adding a
filter.

Equal target notionals are market-neutral-style construction, not proof of
market, factor, dollar, beta, volatility, or portfolio neutrality. Q09 alone
owns realized overlap. This packet authorizes no manual backtest; live, demo,
shadow, stress, or optimization setfile; AutoTrading; `T_Live`; deploy or
live manifest; portfolio-gate change; portfolio admission; correlation
waiver; terminal process control; or tester dispatch.
