---
source_id: VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026
title: XTI/XNG twelve-month fixed-block Mann-Whitney ratio location-shift reversion extraction
publisher: QuantMechanica governed extraction of government and peer-reviewed research
source_type: government_peer_reviewed_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-27_xtixng_monthly_mann_whitney_location_shift_reversion_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
  - MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026
parent_sha256:
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
  MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026: 8D42ED6DF1415B6EDF7FF29AE9349BCA576F0F66204A8021E2E0B8D73B0AEDE0
created: 2026-08-27
created_by: Research+Development
cards_extracted:
  - xtixng-mwilcoxon-rv
---

# XTI/XNG Twelve-Month Fixed-Block Mann-Whitney Ratio Reversion Source Packet

## Approved Sources Of Record

The relationship parent is
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`. It preserves a
complete 43-page U.S. EIA report by Jose A. Villar and Frederick L. Joutz,
"The Relationship Between Crude Oil and Natural Gas Prices," and a complete
peer-reviewed article by David J. Ramberg and John E. Parsons, "The Weak Tie
Between Natural Gas and Oil Prices," *The Energy Journal* 33(2), DOI
`10.5547/01956574.33.2.2`. It also preserves adverse modern EIA evidence. The
records support a time-varying oil/gas linkage and error-correction experiment
while rejecting a permanent fixed price ratio.

The method parent is
`strategy-seeds/sources/MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026/source.md`. It
preserves the complete governed time-series-momentum packet for Moskowitz,
Ooi, and Pedersen (2012), a named bibliographic record for H. B. Mann and
D. R. Whitney (1947), and the complete pinned R Core
`stats::wilcox.test` implementation and manual at public mirror commit
`7344a2d9d96b3c2b997535d3abc8c3a44af16e82`. The implementation forms the
two-sample statistic as the first sample's combined rank sum less
`m(m+1)/2`; the manual gives the equivalent favorable-pair count. The 1947
article body is not represented as completely read and no blocked body text,
table, probability, or result is used.

Both bounded parents were read completely before the durable OWNER source
approval at
`decisions/2026-08-27_xtixng_monthly_mann_whitney_location_shift_reversion_source_approval.md`.

## Source Findings Used

Villar-Joutz and Ramberg-Parsons support testing a state-dependent oil/gas
relationship without assuming a universal coefficient or tight permanent
link. Mann, Whitney, and the pinned R files supply a deterministic two-sample
ordinal location statistic.

The records support a falsifiable oil/gas ratio location-shift experiment,
not a claim that a fixed-block Mann-Whitney shift predicts reversion. The
twelve-month sample, six/six split, strict no-tie rule, integer boundaries,
synchronized continuous-CFD mapping, contrarian sides, equal-notional target,
fixed-dollar risk, stops, spread caps, atomic order sequence, consumed
attempt, and lifecycle are transparent QM choices.

No source return, alpha, probability, statistical significance, density,
Sharpe ratio, drawdown, cost, hedge ratio, neutrality, CFD equivalence,
decorrelation, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For twelve positive, finite, exactly timestamp-matched completed month-end
close pairs, oldest to newest:

```text
s[i] = ln(XTI_close[i]) - ln(XNG_close[i]), i = 0..11
require every s[i] pairwise distinct

O = s[0..5]
N = s[6..11]

U_new = count(N[j] > O[i]) for every i=0..5 and j=0..5
U_old = count(O[i] > N[j]) over the same 36 pairs
W_new = sum(strict combined ranks of N)

require 0 <= U_new <= 36
require U_new + U_old == 36
require W_new - 21 == U_new

SELL XTI / BUY XNG iff U_new >= 24
BUY XTI / SELL XNG iff U_new <= 12
FLAT otherwise
```

High `U_new` means the newer oil-minus-gas ratio block is ordinally higher;
the package fades that shift by shorting oil and buying gas. Low `U_new`
means the newer ratio block is ordinally lower; the package buys oil and
shorts gas. Exact ties, average ranks, p-values, a variable split, a maximum
search, fitted center or scale, endpoint fallback, and signal-strength sizing
are forbidden.

Exact enumeration of the `choose(12,6)=924` no-tie assignments gives 182
assignments in each tail and a combined qualification rate of
`364/924 = 0.3939393939393939`, or 4.727272727 monthly decisions per twelve
opportunities under random rank assignment. This is a density design fact,
not a significance, independence, frequency, or performance claim.

## Exact Event And Execution Contract

1. Require exact host `XTIUSD.DWX`, companion `XNGUSD.DWX`, D1, and an entry
   attempt no later than 180 elapsed minutes after the raw current host D1 bar
   open in a genuine new broker month.
2. Persist current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order gates. Never retry the month after a
   flat signal, invalid state, reject, stop, partial fill, or restart.
3. From bounded native D1 buffers, select the latest exactly timestamp-matched
   close pair in each of the immediately prior twelve consecutive broker
   months. Require positive finite closes, strict chronology, the immediately
   prior newest month, no current-month close, and no more than ten calendar
   days of endpoint staleness.
4. Compute twelve oil-minus-gas log ratios, reject ties, split once after
   observation six, count all 36 newer-versus-older comparisons, and prove
   the complement and combined-rank-sum identities.
5. Open at most one equal-target-absolute-USD-notional package under aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Split stop
   risk equally and size each leg against its frozen `3.5*ATR(20,D1)` hard
   stop. Attach no target, cap spreads at 1,500 XTI points and 3,000 XNG
   points, and require realized notional mismatch no greater than 20%.
6. Submit XTI first and XNG second. Retain only one correctly directed,
   registered, stop-protected position in each slot. Flatten all owned legs
   after any partial or final package-validation failure.
7. Close both legs on the first tick in a later broker month or after forty
   calendar days. Immediately repair an orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, stopless, stale, or notional-invalid package.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 histories, timestamps, calendar, quotes, symbol metadata,
ATR, positions, deals, terminal global variables, and V5 framework services.

## Canonical Fuzzy-Match Adjudication

The fail-closed canonical checker scanned 4,677 registry identities, 1,328
cards, and 45 Strategy Wiki nodes. It found no exact match and returned two
fuzzy neighbors requiring explicit Research/QB review. The complete receipt
is `artifacts/qm5_xtixng_mwilcoxon_rv_preallocation_dedup_20260827.json`.

- `QM5_41177_xauxag-mwilcoxon-shift-rv` uses the same fixed-block statistic
  on a gold/silver ratio. This packet uses the separately sourced weak and
  time-varying oil/gas relation, XTI/XNG execution constraints, and energy
  spread risks. It is a carrier sibling, not the same strategy identity.
- `QM5_41175_xtixng-mpettitt-rv` uses the same paired-energy carrier but ranks
  thirteen ratios, calculates all twelve cumulative rank sums, searches for
  one unique maximum, and accepts only a central split. This packet uses
  twelve ratios, one prespecified split, exactly 36 cross-block comparisons,
  and inclusive fixed U boundaries. It never searches or maximizes.
- `QM5_20237_xtixng-ecm-rv` fits a 252-D1 trend-augmented OLS residual and
  trades a z-score crossing. This packet performs no regression, estimates no
  beta, and consumes twelve completed monthly endpoints.
- Fixed oil/gas ratio, return-spread, channel, momentum, carry, calendar,
  tail, volatility, and factor-rank baskets calculate different states.
- Certified `QM5_12567_cum-rsi2-commodity` is a two-day long-only XNG
  oscillator pullback, not a monthly paired-energy ordinal reversion package.

For a thirteen-ratio rank path, this packet uses the latest twelve values.
Path `[11,13,2,4,6,1,3,10,5,7,8,9,12]` gives short-ratio at `U_new=29`, while
the Pettitt neighbor stays flat because its unique maximum is at edge split
`K=2`. Path `[1,8,3,5,7,11,9,4,2,12,13,6,10]` is flat here at `U_new=20`
while Pettitt qualifies from its unique central maximum. Path
`[11,10,9,8,3,2,1,13,4,5,6,12,7]` reaches this packet's inclusive
short-ratio boundary at `U_new=24` while Pettitt takes the opposite ratio
side from its unique `K=4` maximum.

Research/QB verdict:
`CLEAN_AFTER_DECLARED_FUZZY_REVIEW_XTIXNG_FIXED_SIX_BY_SIX_MANN_WHITNEY_U24_RATIO_REVERSION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_RELATION_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete
  government oil/gas research, complete peer-reviewed oil/gas evidence with
  adverse findings, named original Mann-Whitney record, and complete pinned R
  Core method files; exact trading conjunction untested.
- R2 `PASS`: clock, synchronization, ratio orientation, fixed blocks, strict
  ties, U identities, inclusive boundaries, contrarian sides, attempt,
  aggregate risk, atomicity, and lifecycle are fixed.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` and `XNGUSD.DWX` D1 histories plus native MT5 state supply
  every runtime input.
- R4 `PASS`: deterministic comparisons, integer arithmetic, calendar, ATR
  risk controls, and execution state only; no trained output, banned signal
  method, external runtime feed, grid, martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

The pre-result density prior is four to eight completed packages per full
post-warm-up year. Q02 must retire below four in any full year, at zero
trades, with nonpositive governed economics, or on any endpoint, fixed-block,
tie, U-identity, side, attempt, risk, atomicity, or lifecycle defect. Q09
alone owns realized overlap and portfolio correlation.

No failed result may be rescued by changing the sample, split, tie rule,
boundary, direction, hedge construction, stop, hold, or by adding a filter.
This packet authorizes one G0 card, deterministic allocation, one branch-only
non-live build, strict Q01, and one paced Q02 handoff only. It authorizes no
manual backtest, live/demo/shadow preset, AutoTrading, `T_Live`, deploy or
live manifest, portfolio-gate change, portfolio admission, correlation
waiver, terminal control, or claim that the sleeve is already profitable,
certified, neutral, or uncorrelated.
