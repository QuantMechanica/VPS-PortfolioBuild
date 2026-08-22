---
source_id: SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026
title: XAU/XAG completed-month sequence-dominance reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-23_xauxag_monthly_sequence_dominance_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
  - COWLES-JONES-SEQUENCES-1937
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
  COWLES-JONES-SEQUENCES-1937: 4C7D4FCF2E5CB7C25BCB06B9B503E4D1560759197F5C29EA47B4AD23B9B2155C
created: 2026-08-23
created_by: Research+Development
cards_extracted:
  - xauxag-mseqdom-rv
---

# XAU/XAG Completed-Month Sequence-Dominance Reversion Source Packet

## Approved Sources Of Record

This bounded extraction uses one canonical child `source_id` with three
governed source records. Every record was read completely before source
approval:

- `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` preserves
  Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
  from quantile cointegrating regressions," *Journal of Banking & Finance*
  88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, plus supporting
  fractional-cointegration lineage from Yaya, Vo, and Olayinka (2021),
  *Resources Policy* 72, 102045, DOI
  `10.1016/j.resourpol.2021.102045`.
- `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` records CME Group's
  definition of the gold/silver ratio, the intermarket-spread carrier, and
  the metals' differing monetary and industrial drivers.
- Cowles and Jones (1937), "Some A Posteriori Probabilities in Stock Market
  Action," *Econometrica* 5(3), 280-294, DOI `10.2307/1905515`, was read in
  full from the fifteen-page primary PDF in Yale's Cowles archive:
  `https://economics.yale.edu/sites/default/files/2022-08/cowles-posteriori37.pdf`.
  The downloaded bytes had SHA-256
  `4C7D4FCF2E5CB7C25BCB06B9B503E4D1560759197F5C29EA47B4AD23B9B2155C`.

The durable OWNER approval is
`decisions/2026-08-23_xauxag_monthly_sequence_dominance_reversion_source_approval.md`,
committed before this extraction at `91e138677`. No blocked page, inferred
table value, secondary summary, or unrecorded source is used.

## Source Findings Used

Schweikert supports testing a long-run gold/silver relation while warning that
its behavior may be state dependent rather than governed by one constant
cointegrating vector. The supporting fractional-cointegration lineage also
supports treating gold and silver as related but non-identical price series.
CME defines the gold/silver ratio as gold price divided by silver price,
presents it as an intermarket spread, and explains why the legs can diverge as
gold's monetary and safe-haven sensitivity and silver's industrial sensitivity
change.

Cowles and Jones define a sequence as a rise following a rise or a decline
following a decline, and a reversal as a decline following a rise or a rise
following a decline. They count those states over multiple sampling intervals
to examine serial structure. Their paper also makes three limitations
load-bearing for this extraction:

1. the evidence is from stock-price series, not precious metals or a paired
   spread;
2. one month was selected only after comparing many intervals, so the authors
   explicitly warn about hindsight; and
3. even the paper's favored monthly specification did not offer assurance of
   consistent or large profits.

The sources do not establish that sequence dominance inside one completed
gold/silver-ratio month predicts reversal. Cowles and Jones interpret sequence
excess as persistence, whereas the QM candidate treats persistence on a
mean-reverting intermetal carrier as a possible exhaustion state. They do not
specify a 17-to-23-session calendar month, an inclusive sequence majority, a
first-to-last ratio direction, a next-month contrarian hold, equal-notional
sizing, Darwinex continuous CFDs, fixed cash risk, ATR stops, spread caps,
persistent attempt state, or portfolio behavior. Those are transparent QM
hypotheses. No source alpha, profit estimate, probability, density, hedge
ratio, neutrality, cost, CFD equivalence, or portfolio-correlation result is
imported.

## Bounded QM Mechanization

On the first tradable synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 bar of a
new broker-calendar month, reconstruct every synchronized close pair in the
immediately completed calendar month. Require 17 through 23 pairs and order
their gold-minus-silver log ratios oldest to newest:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..n-1
r[j] = s[j] - s[j-1],                    j=1..n-1

every r[j] must be finite and nonzero

sequences = count(sign(r[j]) == sign(r[j-1]), j=2..n-1)
reversals = count(sign(r[j]) != sign(r[j-1]), j=2..n-1)

require sequences + reversals == n-2
require sequences >= reversals

net = s[n-1] - s[0]

qualifying and net > 0
    => SELL XAUUSD.DWX, BUY XAGUSD.DWX

qualifying and net < 0
    => BUY XAUUSD.DWX, SELL XAGUSD.DWX

otherwise
    => FLAT
```

For `n=17..23`, there are 16 through 22 nonzero returns and 15 through
21 sign transitions. A same-sign transition is one sequence and an
opposite-sign transition is one reversal. Equality qualifies when the
transition count is even; equality is impossible when it is odd. Sequence
surplus and net displacement magnitude never change direction, sizing, stops,
or lifecycle.

## Exact Event Contract

1. Derive the current broker `yyyymm` from the synchronized host/companion D1
   bar time and require entry within 180 elapsed minutes of the raw host bar's
   open.
2. Require the immediately preceding synchronized bar to belong to the prior
   month, proving the first tradable bar of the new month. Derive the exact
   immediately completed month across year boundaries.
3. Within a fixed 45-bar buffer, require 17 through 23 unique synchronized D1
   timestamps in that month, strict reverse-time history order, positive
   finite closes, exact month membership, and one adjacent older pair proving
   the month was not truncated.
4. Reverse the ratios into chronological order, form every adjacent relative
   return, reject one exact-zero or nonfinite return, and count every adjacent
   sign transition exactly once as a sequence or reversal.
5. Require exhaustive transition accounting and the fixed inclusive majority
   `sequences>=reversals`. If it qualifies, fade the sign of the completed
   month's first-to-last ratio displacement. Exact-zero net and every
   nonqualifying or malformed state consume the month flat.
6. Persist the current decision `yyyymm` before history, signal, spread,
   quote, ATR, sizing, news, or order gates. No retry is allowed that month.
7. Open one equal-absolute-notional opposite-leg package. Combined normalized
   hard-stop risk is capped at aggregate `RISK_FIXED=1000`; each leg receives
   a frozen `3.5 * ATR(20,D1)` stop and no target.
8. Close both legs on the first tick of a later broker month, with a forty-day
   stale repair. Malformed, orphaned, duplicated, same-side, stopless, or
   notional-invalid ownership flattens immediately.

## Non-Duplicate Boundary

The fail-closed canonical checker found no exact or fuzzy collision across
4,620 registry identities, 1,289 repository cards, and 45 Strategy-Wiki
nodes. Evidence is
`artifacts/qm5_xauxag_mseqdom_rv_preallocation_dedup_20260823.json`.

Manual semantic review finds a new mechanic:

- `QM5_20275_gsr-runfade` requires a fresh terminal run of five same-sign
  daily relative returns. This extraction classifies every sign transition in
  one completed month; no terminal run is required.
- `QM5_41078_xauxag-wstreak3-rv` uses three completed weekly ratio directions.
  This extraction uses the full daily transition path inside one month and an
  inclusive sequence/reversal majority.
- `QM5_41112_xauxag-mdaybreadth-rv` counts positive and negative returns but
  discards their ordering. This extraction's result can change when the same
  multiset of signs is permuted.
- `QM5_41113_xauxag-mhalfagree-rv` and
  `QM5_41116_xauxag-mthirdvote-rv` aggregate return magnitudes into fixed
  calendar blocks. This extraction discards magnitude after sign and has no
  block sum.
- `QM5_41120_xauxag-mopen-residence-rv` counts close levels against one fixed
  first-close anchor. This extraction counts adjacent return-sign states and
  uses the first close only for net direction.
- close-rank, range-residence, location-statistic, rolling ratio, residual,
  scale, robust-score, and empirical-tail families do not count exhaustive
  chronological return-sign transitions.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  XNG oscillator pullback.

The exact paired carrier, immediately completed calendar month,
17-to-23-session synchronization, chronological nonzero relative-return signs,
exhaustive sequence/reversal transitions, fixed inclusive sequence majority,
contrarian net-month package, consumed monthly attempt, equal-notional
aggregate-risk package, and next-month exit are jointly load-bearing. Manual
verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_SEQUENCE_DOMINANCE_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_CROSS_ASSET_SEQUENCE_AND_DIRECTION_TRANSLATION_RISK`. The
  packet preserves peer-reviewed gold/silver DOI lineage, an official-exchange
  carrier, and a completely read primary *Econometrica* method paper with
  durable hashes. It discloses both the equity-to-metals and
  persistence-to-exhaustion translations.
- R2: `PASS`. Synchronized month labels, chronology, nonzero returns, sign
  transitions, exhaustive counts, inclusive majority, net direction, sides,
  attempt, risk, stops, atomicity, spread gates, and lifecycle are fixed.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state provide all
  runtime inputs. Q02 owns history, holiday attrition, costs, financing,
  density, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed prices, logarithms, signs,
  integer counts, comparisons, ATR, quotes, positions, deals, and persistent
  terminal state; no trained logic, banned signal, external feed, grid,
  martingale, scale-in, or pyramid exists.

## Claim And Kill Boundary

The sources support testing a state-dependent gold/silver relative-value
carrier with a named sequence/reversal statistic, not this within-month
contrarian rule's profitability. Expected cadence is approximately six to
eight completed packages per full post-warm-up year. Q02 must retire below
five completed packages in any full year, at zero trades, or with nonpositive
governed economics. No failure may be rescued by changing the inclusive
majority, assigning zero returns a sign, changing side or hold, or adding a
fitted center, scale, magnitude, volatility, volume, event, calendar,
external, or prior-result state.

Opposite equal-notional legs are designed to reduce common outright-metal
direction but do not prove neutrality or low portfolio correlation. Q09 alone
owns the realized portfolio finding.

## Safety Boundary

This packet supports one Strategy Card, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
