---
source_id: SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026
title: XAU/XAG completed-month daily-relative-return Hodges-Lehmann reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed, exchange, and governed method research
source_type: peer_reviewed_exchange_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-24_xauxag_monthly_daily_hodges_lehmann_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
  - MOP-WTI-HLRET-2026
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
  MOP-WTI-HLRET-2026: E0E6CF16F7A4656B7613702C39C19657653424819EFB61EE1CEBD9CC46403D8C
created: 2026-08-24
created_by: Research+Development
cards_extracted:
  - xauxag-mdaily-hl-rv
---

# XAU/XAG Completed-Month Daily-Relative-Return Hodges-Lehmann Reversion Source Packet

## Approved Source Of Record

The primary trading-relation source is Karsten Schweikert (2018), "Are gold
and silver cointegrated? New evidence from quantile cointegrating
regressions," *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`.

The governed packet
`strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` records the
publisher abstract and section-summary review, together with supporting
fractional-cointegration research. It preserves the finding that the
gold/silver relation can be state dependent and warns against assuming one
constant universal equilibrium.

The carrier source is CME Group, "Gold & Silver Ratio Spread," preserved in
`strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`. CME defines the ratio
as the gold price divided by the silver price, presents it as an intermarket
spread, and distinguishes gold's monetary/safe-haven behavior from silver's
larger industrial-cycle exposure.

The arithmetic precedent is the already approved governed packet
`strategy-seeds/sources/MOP-WTI-HLRET-2026/source.md`. It fixes inclusive
self/cross-pair averages, exact pair count, ascending sort, and central
odd/even median handling for a Hodges-Lehmann-style return-location
estimator. Its WTI carrier, monthly-return horizon, trend direction, and
performance boundary do not transfer.

All three parent records were read completely before source approval. Their
exact hashes and the durable OWNER authorization are fixed in
`decisions/2026-08-24_xauxag_monthly_daily_hodges_lehmann_reversion_source_approval.md`,
committed before this extraction at `46e7be1d3`. New public routes were
classified `DEFERRED:SOURCE_POLICY` and were not used; the exact router
receipts are preserved in
`artifacts/qm5_xauxag_mdaily_hl_rv_source_route_20260824.json`.

## Source Findings Used

Schweikert supports testing a related but state-dependent long-run relation
between gold and silver rather than assuming a constant hedge coefficient or
one immutable equilibrium. CME supports representing that relation through a
tradable gold/silver intermarket spread and gives an economic reason for
relative displacements: the two metals share precious-metals and USD drivers
but differ in monetary, safe-haven, industrial, and business-cycle exposure.

Those findings support a falsifiable relative-value reversion carrier. They
do not establish that the robust pairwise location of daily gold-minus-silver
returns inside one completed month predicts the following month. The H-L
packet fixes arithmetic only and does not establish this carrier, horizon, or
contrarian direction.

The synchronized CFD calendar, 17-to-23-session package, daily relative
returns, dynamic inclusive pair set, pseudomedian, contrarian direction,
fixed cash risk, ATR stops, spread caps, atomic pair lifecycle, and restart
ledger are QM translations. No source alpha, return, probability, density,
Sharpe ratio, drawdown, cost, hedge ratio, neutrality, CFD equivalence, or
correlation statistic transfers.

## Bounded QM Mechanization

On the first executable synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 bar of a
new broker month, reconstruct every synchronized close pair in the
immediately preceding calendar month plus one adjacent older pair. Require 17
through 23 completed-month sessions.

Starting from the older boundary pair, form one chronological relative log
return ending on every completed-month session:

```text
s[j] = ln(XAU_close[j]) - ln(XAG_close[j])
r[j] = s[j] - s[j-1]

k = 0
for i = 0..n-1:
  for j = i..n-1:
    w[k] = (r[i] + r[j]) / 2
    k += 1

m = n * (n + 1) / 2
require k == m
sorted = ascending(w[0], ..., w[m-1])

if m is odd:
  hl = sorted[floor(m/2)]
else:
  hl = (sorted[m/2 - 1] + sorted[m/2]) / 2

hl > 0 => SELL XAU, BUY XAG
hl < 0 => BUY XAU, SELL XAG
otherwise => FLAT
```

For 17 through 23 synchronized sessions, the exact pair count ranges from 153
through 276. Every observed return contributes one self-pair, and every
unordered cross-pair contributes exactly once. Require positive finite
closes, finite log ratios, returns, pairwise averages, sorted values, and
pseudomedian.

Verify that the sum of the chronological relative returns equals the direct
older-boundary-to-final log-ratio displacement within `1e-10`. The raw
relative endpoint is diagnostic only. It may agree or disagree with the
pseudomedian and does not gate the trade. A zero pseudomedian or invalid state
consumes the month flat. Neither pseudomedian nor endpoint magnitude changes
risk.

## Exact Event Contract

1. Require exact `XAUUSD.DWX` host, exact `XAGUSD.DWX` companion, D1, and
   entry no later than 180 elapsed minutes after the raw first host D1 bar open
   of a new broker month.
2. Require exact synchronized host/companion timestamps. Within a fixed 45-bar
   buffer, the newest completed pair must belong to the immediately prior
   month; require 17-23 unique completed-month pairs in strict reverse-time
   order and one adjacent older boundary pair. Exclude all current-month
   closes.
3. Reverse pairs into chronological order and form every relative log return
   ending in the completed month exactly once. Verify endpoint identity within
   `1e-10`.
4. Enumerate every inclusive `(i,j)` pair in nested ascending order with
   `0 <= i <= j < n`. Require exactly `n*(n+1)/2` averages and explicit
   self-pair identity `w(i,i)=r[i]` within numerical tolerance.
5. Sort all averages ascending without rounding. Use the one central element
   for odd pair counts or the mean of the two central elements for even pair
   counts. Fade the strict pseudomedian sign with opposite legs. Equality and
   invalid states remain flat.
6. Persist current decision `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order submission. No outcome retries the
   month.
7. Open at most one equal-target-notional opposite-leg package under aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, frozen `3.5 * ATR(20,D1)` hard stops,
   no targets, 1,500-point XAU and 500-point XAG spread ceilings, and at most
   20% realized notional mismatch.
8. Submit the pair atomically: if the second leg fails or any owned state is
   malformed, close all owned exposure immediately and do not retry.
9. Close both legs on the first tick in a later broker month, with a forty-
   calendar-day stale repair. Flatten orphaned, duplicated, same-side,
   wrong-magic, stopless, or notional-invalid owned exposure immediately.

News and Friday-close axes are OFF. Runtime uses registered MT5 history,
calendar, quotes, symbol metadata, ATR, position/deal state, and persistent
terminal state only.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,637 registry identities, 1,305
cards, and 45 Strategy Wiki nodes using the actual Company Reference root. It
found no exact identity and surfaced only the expected fuzzy neighbor
`QM5_41135_xauxag-mdaily-iqrmean-rv`. Evidence is
`artifacts/qm5_xauxag_mdaily_hl_rv_preallocation_dedup_20260824.json`.

Manual semantic review fixes a new mechanic:

- `QM5_41135` removes `floor(n/4)` raw observations per tail and averages the
  remaining 9-13 returns. This extraction retains every observed return,
  expands them into 153-276 inclusive pairwise averages, and uses the exact
  median of that derived distribution.
- `QM5_20276_wti-hl-mom` uses the same arithmetic family on twelve disjoint
  monthly outright-WTI returns and follows its sign. This extraction uses one
  completed month of daily intermetal returns, fades the sign, and owns an
  atomic equal-notional XAU/XAG package.
- rolling ratio, OLS, quantile, and MAD cards fit a center, coefficient,
  scale, or crossing. This extraction fits none.
- sign breadth, fixed blocks, sequences, path quotients, RMS coherence, and
  persistence use different state objects; none enumerates Walsh averages.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG
  oscillator pullback.

The exact paired carrier, completed month, older boundary pair, every daily
relative return, inclusive pair enumeration, dynamic pair count, exact
pseudomedian, contrarian package, consumed month, aggregate fixed risk, and
next-month lifecycle are jointly load bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_DAILY_HODGES_LEHMANN_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_DAILY_PSEUDOMEDIAN_TRANSLATION_RISK`. The lineage preserves
  a named-author peer-reviewed gold/silver-relation paper with DOI and
  complete-read record plus official exchange research for the spread carrier
  and its distinct drivers. The exact daily pseudomedian and contrarian
  next-month direction are untested; the governed H-L packet is arithmetic
  precedent only.
- R2: `PASS`. Clock, synchronization, month, boundary, observations, relative
  returns, identity, inclusive pair bounds, pair count, ascending sort,
  odd/even median, sides, attempt, aggregate risk, stops, atomicity, spread
  gates, and lifecycle are fixed.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories and MT5-native state supply every
  runtime input.
- R4: `PASS`. Deterministic timestamps, logarithms, arithmetic, sorting,
  comparison, ATR, and execution state only; no fitted model, trained output,
  banned signal, external feed, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

Every valid nonzero pseudomedian may qualify, giving a pre-result density
prior near twelve packages per year. This is not market evidence. Q02 must
retire below five completed packages in any full post-warm-up year, at zero
trades, with nonpositive governed economics, or on any synchronization,
month, return, pair, median, side, attempt, risk, atomicity, lifecycle, or
determinism defect.

The opposite equal-notional legs are economically different from the
certified directional XAU, SP500, NDX, and XNG carriers but do not prove
dollar, beta, volatility, factor, or portfolio neutrality. Q09 alone owns the
realized portfolio result. No failure may be rescued by changing the sample,
pair convention, median formula, direction, carrier, risk, hold, or by adding
endpoint agreement, a fitted center or scale, event, seasonal, volatility,
external, or prior-result state.

## Safety Boundary

This packet supports one Strategy Card, one branch-only V5 build, strict
compile/Q01, and one paced non-live Q02 handoff only. It does not authorize a
manual backtest, live artifact, `T_Live`, AutoTrading, deploy manifest,
portfolio-gate change, portfolio admission, correlation waiver, terminal
control, or decorrelation claim.
