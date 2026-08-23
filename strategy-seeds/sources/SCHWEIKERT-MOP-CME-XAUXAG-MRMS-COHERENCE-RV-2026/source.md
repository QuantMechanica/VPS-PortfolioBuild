---
source_id: SCHWEIKERT-MOP-CME-XAUXAG-MRMS-COHERENCE-RV-2026
title: XAU/XAG completed-month mean-to-RMS coherence reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-23_xauxag_monthly_mean_rms_coherence_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
  - MOP-WTI-MRMS-COHERENCE-MOM-2026
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
  MOP-WTI-MRMS-COHERENCE-MOM-2026: 1900B0255CE83C0962E05DCB6C9FC25EC0AFDA67CF0423BB9607B19495414279
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-23
created_by: Research+Development
cards_extracted:
  - xauxag-mrms-coherence-rv
---

# XAU/XAG Completed-Month Mean-to-RMS Coherence Reversion Source Packet

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
- `strategy-seeds/sources/MOP-WTI-MRMS-COHERENCE-MOM-2026/source.md` preserves
  the exact signed-mean-to-RMS path statistic, endpoint identity, and numerical
  contract as a bounded mechanization of Moskowitz, Ooi, and Pedersen (2012),
  "Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
  DOI `10.1016/j.jfineco.2011.11.003`. Its completely read parent packet is
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

The durable OWNER approval is
`decisions/2026-08-23_xauxag_monthly_mean_rms_coherence_reversion_source_approval.md`,
committed before this extraction at `d271c56f1`. No blocked page, inferred
source-table value, secondary summary, or unrecorded performance claim is
used.

## Source Findings Used

Schweikert supports testing a long-run gold/silver relation while warning that
its behavior can be state dependent rather than governed by one constant
cointegrating vector. CME defines the gold/silver ratio as gold price divided
by silver price, presents it as an intermarket spread, and explains why the
legs can diverge because gold has stronger monetary and safe-haven sensitivity
while silver has stronger industrial sensitivity.

Moskowitz, Ooi, and Pedersen support mechanical completed-price paths and a
monthly formation/holding clock. The governed mean-to-RMS child defines a
closed-form statistic that compares the absolute signed mean of all returns
with their root mean square. That packet follows the statistic on outright
WTI; it does not test gold/silver, synchronized daily relative returns, or
contrarian direction.

The sources do not establish that a coherent one-month gold/silver-ratio move
predicts reversion. They do not prescribe a 17-to-23-session broker month, a
`0.16` threshold, equal-notional sizing, Darwinex continuous CFDs, fixed cash
risk, ATR stops, spread caps, persistent attempt state, or portfolio behavior.
Those are transparent QM hypotheses. No source alpha, profit estimate,
probability, density, hedge ratio, neutrality, cost, CFD equivalence, or
portfolio-correlation statistic is imported.

## Bounded QM Mechanization

On the first tradable synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 bar of a
new broker-calendar month, reconstruct every synchronized close pair in the
immediately completed calendar month plus the adjacent older synchronized
pair. Require 17 through 23 completed-month pairs. Define the gold-minus-
silver log ratio at every paired endpoint and form one chronological relative
return ending on every session of the completed month.

For older boundary ratio `s[-1]`, month ratios `s[0]..s[n-1]`, and returns
`r[j]=s[j]-s[j-1]` for `j=0..n-1`:

```text
N = sum(r[j])
Q = sum(r[j]^2)
C = abs(N) / sqrt(n * Q)

equivalently:
C = abs(mean(r)) / sqrt(mean(r[j]^2))

require finite arithmetic, Q > 0, and C in [0,1] within 1e-10

C >= 0.16 and N > 0
    => SELL XAUUSD.DWX, BUY XAGUSD.DWX

C >= 0.16 and N < 0
    => BUY XAUUSD.DWX, SELL XAGUSD.DWX

otherwise
    => FLAT
```

The sum of chronological relative returns must equal the direct relative
log-ratio displacement from the older boundary pair to the completed month's
final pair within `1e-10`. Each return ending in the completed month
contributes exactly once. Exact-zero constituent returns are valid and add
zero to `N` and `Q`. A zero squared path, exact-zero net, below-threshold
coherence, nonfinite value, or out-of-range quotient consumes the month flat.
Coherence and displacement magnitude never change risk.

The quotient is the absolute projection of the relative-return vector onto
the equal-sign direction, normalized by both vector lengths. It is bounded,
scale invariant, and order invariant. It is not a sample mean t-statistic:
there is no demeaning, sample-variance correction, degrees-of-freedom
adjustment, annualization, or fitted distribution.

## Exact Event Contract

1. Require exact `XAUUSD.DWX` host, exact `XAGUSD.DWX` companion, D1, and entry
   no later than 180 elapsed minutes after the raw first host D1 bar open of a
   new broker month.
2. Require the newest synchronized completed pair to belong to the immediately
   preceding calendar month. Within a fixed 45-bar buffer, require 17 through
   23 unique completed-month timestamps in strict reverse-time order and one
   immediately older synchronized pair from the adjacent calendar month. A
   current-month close or mismatched timestamp is excluded.
3. Reverse the selected pairs into chronological order beginning with the
   older boundary. Form one gold-minus-silver relative return into every
   completed-month session, with no gap, overlap, duplicate, or omitted
   endpoint.
4. Accumulate `N` and `Q` from the same bounded loop, verify the endpoint
   identity, then compute the fixed mean-to-RMS coherence without rounding.
5. Fade the sign of `N` only when `C>=0.16`. Every invalid or nonqualifying
   state consumes the month flat.
6. Persist current decision `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, or order submission. No outcome may retry that month.
7. Open one opposite-leg package with equal target absolute USD notionals and
   no more than 20% realized notional mismatch. Split one aggregate
   `RISK_FIXED=1000` budget across two frozen `3.5 * ATR(20,D1)` hard stops,
   use no target, and enforce 1,500-point XAU and 500-point XAG spread ceilings.
8. Close both legs on the first tick in a later broker month, with a forty-
   calendar-day stale repair. Flatten malformed, duplicated, same-side,
   wrong-symbol, wrong-magic, stopless, notional-invalid, or orphan exposure
   immediately.

## Non-Duplicate Boundary

The fail-closed canonical checker found no exact or fuzzy collision across
4,624 registry identities, 1,293 cards, and 45 Strategy-Wiki nodes. Evidence
is
`artifacts/qm5_xauxag_mrms_coherence_rv_preallocation_dedup_20260823.json`.

Manual semantic review fixes a new mechanic:

- rolling gold/silver ratio, OLS, conditional-quantile, and MAD cards estimate
  a center, beta, scale, or threshold crossing. This extraction estimates none.
- `QM5_20249_xauxag-vr-spread` estimates serial dependence over 32 monthly
  returns and switches continuation/reversal direction. This extraction uses
  one month of daily relative returns, no covariance, and only reversion.
- `QM5_41112_xauxag-mdaybreadth-rv` counts signs while discarding magnitudes.
  This extraction uses every squared return magnitude and is order invariant.
- `QM5_41113`, `QM5_41116`, and `QM5_41118` use fixed calendar blocks, while
  `QM5_41121` uses extreme-state sequence order. This extraction has no block,
  vote, range location, anchor residence, or sequence state.
- `QM5_41123_xauxag-mpath-eff-rv` normalizes net relative displacement by the
  L1 absolute path at `0.20`. This extraction uses the L2/RMS denominator
  `sqrt(n*Q)` at `0.16`, so return concentration is load bearing.
- `QM5_41124_wti-mrms-coherence-mom` follows the same statistic on outright
  WTI. This extraction fades it on a synchronized two-leg relative carrier
  with equal-notional atomic lifecycle.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon XNG oscillator
  pullback rather than completed-month relative-path coherence.

The exact paired carrier, immediately completed month, older boundary pair,
every relative return ending in the month, signed sum, squared path, bounded
mean-to-RMS quotient, inclusive `0.16` threshold, contrarian sides, consumed
attempt, aggregate fixed risk, equal-notional atomic package, and next-month
exit are jointly load-bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_MEAN_RMS_COHERENCE_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_PATH_HORIZON_AND_DIRECTION_TRANSLATION_RISK`. The canonical
  child preserves a peer-reviewed gold/silver DOI, official exchange carrier,
  peer-reviewed monthly path lineage, complete-read evidence, and durable
  hashes. The daily relative-path gate and contrarian direction are untested
  translations.
- R2: `PASS`. Pair synchronization, month membership, observation bounds,
  chronology, return inclusion, endpoint identity, signed and squared sums,
  normalization, threshold, sides, attempt, risk, stops, atomicity, spread
  gates, and lifecycle are fixed.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 calendar, ATR,
  spread, quote, position, deal, and persistent state provide every runtime
  input.
- R4: `PASS`. Deterministic timestamps, logarithms, addition, multiplication,
  square root, division, comparisons, ATR, and execution state only; no
  trained output, banned signal, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Claim And Kill Boundary

A zero-drift Gaussian design reference qualifies approximately 45.6% to 52.6%
of months across 23 to 17 returns at `C>=0.16`, corresponding to about 5.5 to
6.3 decisions/year. This is a pre-result density sanity check, not market
evidence. Q02 must retire below five completed packages in any full post-
warm-up year, at zero trades, or with nonpositive governed economics.

Opposite equal-notional legs are intended to reduce common outright-metal
direction but do not prove dollar, beta, volatility, factor, or portfolio
neutrality. Q09 alone owns the realized portfolio result. No failure may be
rescued by changing the threshold, direction, observation inclusion, carrier,
risk, hold, or by adding a fitted center, scale, volatility forecast, sign
count, block vote, sequence, range location, seasonality, event, external, or
prior-result state.

## Safety Boundary

This packet supports one Strategy Card, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
