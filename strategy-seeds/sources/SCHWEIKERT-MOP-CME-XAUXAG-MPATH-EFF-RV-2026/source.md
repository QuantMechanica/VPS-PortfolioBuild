---
source_id: SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026
title: XAU/XAG completed-month path-efficiency reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-23_xauxag_monthly_path_efficiency_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
  - MOP-WTI-PATHEFF-2026
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
  MOP-WTI-PATHEFF-2026: 7D4F2B86DA31EEA2ECAEE7573E3CF1629883B05A575FFEB694944A99D907DBE8
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-23
created_by: Research+Development
cards_extracted:
  - xauxag-mpath-eff-rv
---

# XAU/XAG Completed-Month Path-Efficiency Reversion Source Packet

## Approved Sources Of Record

This bounded extraction uses one canonical child `source_id` with three
governed source lineages. Every record was read completely before source
approval:

- `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` preserves
  Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
  from quantile cointegrating regressions," *Journal of Banking & Finance*
  88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, and supporting fractional-
  cointegration research.
- `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` records CME Group's
  definition of the gold/silver ratio, the intermarket-spread carrier, and the
  metals' differing monetary and industrial drivers.
- `strategy-seeds/sources/MOP-WTI-PATHEFF-2026/source.md` preserves the exact
  net-to-absolute-path statistic and numerical contract as a bounded
  mechanization of Moskowitz, Ooi, and Pedersen (2012), "Time Series
  Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`. Its completely read parent packet is
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

The durable OWNER approval is
`decisions/2026-08-23_xauxag_monthly_path_efficiency_reversion_source_approval.md`,
committed before this extraction at `13cb898ac`. No blocked page, inferred
table value, secondary summary, or unrecorded source is used.

## Source Findings Used

Schweikert supports testing a long-run gold/silver relation while warning that
its behavior can be state dependent rather than governed by one constant
cointegrating vector. CME defines the gold/silver ratio as gold price divided
by silver price, presents it as an intermarket spread, and explains why the
legs can diverge because gold has stronger monetary and safe-haven sensitivity
while silver has stronger industrial sensitivity.

Moskowitz, Ooi, and Pedersen support mechanical completed-price paths and a
monthly formation/holding clock. The governed path-efficiency child defines a
closed-form statistic that compares net displacement with the sum of all
absolute constituent moves. That packet follows the statistic on outright WTI
over twelve monthly returns; it does not test gold/silver, daily relative
returns inside one month, or contrarian direction.

The sources do not establish that an efficient one-month gold/silver-ratio
move predicts reversion. They do not prescribe a 17-to-23-session calendar
month, a 0.20 threshold, equal-notional sizing, Darwinex continuous CFDs,
fixed cash risk, ATR stops, spread caps, persistent attempt state, or
portfolio behavior. Those are transparent QM hypotheses. No source alpha,
profit estimate, probability, density, hedge ratio, neutrality, cost, CFD
equivalence, or portfolio-correlation result is imported.

## Bounded QM Mechanization

On the first tradable synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 bar of a
new broker-calendar month, reconstruct every synchronized close pair in the
immediately completed calendar month. Require 17 through 23 pairs and order
the gold-minus-silver log ratios oldest to newest:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..n-1
r[j] = s[j] - s[j-1],                    j=1..n-1

N = sum(r[j])
P = sum(abs(r[j]))
E = abs(N) / P

require finite arithmetic, P > 0, and E in [0,1] within 1e-10

E >= 0.20 and N > 0
    => SELL XAUUSD.DWX, BUY XAGUSD.DWX

E >= 0.20 and N < 0
    => BUY XAUUSD.DWX, SELL XAGUSD.DWX

otherwise
    => FLAT
```

Every adjacent relative return contributes exactly once to both `N` and `P`.
Exact-zero constituent returns are valid and contribute zero. A zero total
path, exact-zero net displacement, nonfinite value, or efficiency outside its
numerical bounds consumes the month flat. Efficiency above the threshold and
displacement magnitude never change direction, sizing, stops, or lifecycle.

## Exact Event Contract

1. Derive current broker `yyyymm` from synchronized host/companion D1 bar time
   and require entry within 180 elapsed minutes of the raw host bar's open.
2. Require the immediately preceding synchronized pair to belong to the prior
   month, proving the first tradable bar of the new month. Derive the exact
   immediately completed month across year boundaries.
3. Within a fixed 45-bar buffer, require 17 through 23 unique synchronized D1
   timestamps in that month, strict reverse-time history order, positive
   finite closes, exact month membership, and one adjacent older pair proving
   the month was not truncated.
4. Reverse the ratios into chronological order, form every adjacent relative
   return, sum the signed net and full absolute path, and apply the exact 0.20
   efficiency threshold without rounding.
5. Fade the sign of the completed month's ratio displacement. A below-threshold
   path and every nonqualifying or malformed state consume the month flat.
6. Persist current decision `yyyymm` before history, signal, spread, quote,
   ATR, sizing, news, or order gates. No retry is allowed that month.
7. Open one equal-target-absolute-notional opposite-leg package. Maximum
   realized notional mismatch is 20%. Combined normalized hard-stop risk is
   capped at aggregate `RISK_FIXED=1000`; each leg receives a frozen
   `3.5 * ATR(20,D1)` stop and no target.
8. Close both legs on the first tick of a later broker month, with a forty-day
   stale repair. Malformed, orphaned, duplicated, same-side, stopless, or
   notional-invalid ownership flattens immediately.

## Non-Duplicate Boundary

The fail-closed canonical checker found no exact or fuzzy collision across
4,622 registry identities, 1,291 repository cards, and 45 Strategy-Wiki
nodes. Evidence is
`artifacts/qm5_xauxag_mpath_eff_rv_preallocation_dedup_20260823.json`.

Manual semantic review fixes a new mechanic:

- rolling ratio, OLS, median/MAD, quantile, and tail systems estimate a center,
  scale, rank, or fresh threshold crossing. This extraction estimates none.
- `QM5_20274_wti-path-eff` is an outright WTI twelve-month continuation
  strategy. This extraction is a one-month XAU/XAG relative-price fade with
  two opposite legs.
- `QM5_41112_xauxag-mdaybreadth-rv` counts relative-return signs but discards
  magnitudes. This extraction uses every magnitude through the absolute-path
  denominator.
- `QM5_41113_xauxag-mhalfagree-rv`,
  `QM5_41116_xauxag-mthirdvote-rv`, and
  `QM5_41118_xauxag-mlatehalf-dom-rv` aggregate fixed blocks. This extraction
  has no block boundary or vote.
- `QM5_41119_xauxag-mclose-quartile-rv`,
  `QM5_41120_xauxag-mopen-residence-rv`, and
  `QM5_41121_xauxag-mseqdom-rv` use range location, anchor residence, or
  sequence/reversal transitions. This extraction uses only net relative
  displacement and the total absolute adjacent path.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  XNG oscillator pullback.

The exact paired carrier, immediately completed calendar month,
17-to-23-session synchronization, all adjacent relative log returns,
net-to-absolute-path quotient, fixed inclusive 0.20 threshold, contrarian
sides, consumed monthly attempt, equal-notional aggregate-risk package, and
next-month exit are jointly load-bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_PATH_EFFICIENCY_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_PATH_HORIZON_AND_DIRECTION_TRANSLATION_RISK`. One canonical
  child preserves peer-reviewed gold/silver and path-statistic lineages plus
  an official exchange carrier, complete-read evidence, durable hashes, and
  explicit translation boundaries.
- R2: `PASS`. Synchronization, month labels, chronology, return orientation,
  numerator, denominator, zero handling, threshold, sides, attempt, risk,
  stops, atomicity, spread gates, and lifecycle are fixed.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state provide all
  runtime inputs. Q02 owns history, holiday attrition, costs, financing,
  density, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed prices, logarithms, absolute
  values, sums, division, comparisons, ATR, quotes, positions, deals, and
  persistent terminal state; no trained logic, banned signal, external feed,
  grid, martingale, scale-in, or pyramid exists.

## Claim And Kill Boundary

A deterministic zero-drift Gaussian reference with twenty returns qualifies
approximately 48.3% of months at `E>=0.20`, or 5.8 decisions/year. This is a
design-density reference, not market evidence. Q02 must retire below five
completed packages in any full post-warm-up year, at zero trades, or with
nonpositive governed economics. No failure may be rescued by changing the
threshold, side, hold, carrier, risk, or by adding a fitted center, scale,
location, sign-count, sequence, block-vote, volatility, calendar, event,
external, or prior-result state.

Opposite equal-notional legs are designed to reduce common outright-metal
direction but do not prove neutrality or low portfolio correlation. Q09 alone
owns the realized portfolio finding.

## Safety Boundary

This packet supports one Strategy Card, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
