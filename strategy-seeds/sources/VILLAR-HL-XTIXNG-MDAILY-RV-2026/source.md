---
source_id: VILLAR-HL-XTIXNG-MDAILY-RV-2026
title: XTI/XNG completed-month daily-relative-return Hodges-Lehmann reversion extraction
publisher: QuantMechanica governed extraction of government, peer-reviewed, and governed method research
source_type: government_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-29_xtixng_monthly_daily_hodges_lehmann_reversion_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
  - MOP-WTI-HLRET-2026
  - SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026
parent_sha256:
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
  MOP-WTI-HLRET-2026: E0E6CF16F7A4656B7613702C39C19657653424819EFB61EE1CEBD9CC46403D8C
  SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026: D5E8C4CD0112724D66E64C13B20B7B41CCE1B4CDC2061BA21A979374F04531A8
created: 2026-08-29
created_by: Research+Development
cards_extracted:
  - xtixng-mdaily-hl-rv
---

# XTI/XNG Completed-Month Daily-Relative-Return Hodges-Lehmann Reversion Source Packet

## Approval And Complete-Read Boundary

The durable source approval is
`decisions/2026-08-29_xtixng_monthly_daily_hodges_lehmann_reversion_source_approval.md`,
committed as `9d0b5563b` before this extraction. The exact complete-read parent
hashes, byte counts, line counts, and roles are preserved in
`artifacts/qm5_xtixng_mdaily_hl_rv_source_provenance_20260829.json`.

The oil/gas relationship source is
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`. It records
complete reads of Jose A. Villar and Frederick L. Joutz (2006), *The
Relationship Between Crude Oil and Natural Gas Prices*, a 43-page U.S. Energy
Information Administration report, and David J. Ramberg and John E. Parsons
(2012), *The Weak Tie Between Natural Gas and Oil Prices*, *The Energy
Journal* 33(2), 13-35, DOI `10.5547/01956574.33.2.2`.

The arithmetic precedent is
`strategy-seeds/sources/MOP-WTI-HLRET-2026/source.md`. Its peer-reviewed
parent is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012),
*Time Series Momentum*, *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`. The governed child fixes inclusive
self/cross-pair averages, exact pair counts, ascending sort, and odd/even
central-median handling for a Hodges-Lehmann-style return-location estimator.
Its outright-WTI carrier and trend direction do not transfer.

The synchronized daily-return and atomic-basket precedent is
`strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`.
Its precious-metal relation and any carrier finding do not transfer. It is
used only for the already governed completed-month boundary, dynamic
inclusive-pair arithmetic, equal-target-notional risk, atomic repair, and
month-renewal mechanics.

Every parent packet was read completely before source approval. No new public
route, blocked content, source table, performance result, or external runtime
series is used.

## Source Findings Used

Villar/Joutz and Ramberg/Parsons support a physical and economic connection
between crude oil and natural gas through substitution, co-production,
drilling, finance, transport, and LNG. Their adverse evidence is equally
binding: gas retains large idiosyncratic variation, the relationship shifts
across regimes, regional gas fundamentals matter, and no permanently fixed
oil/gas ratio is justified.

Those findings support a falsifiable oil/gas relative-value experiment, not a
constant equilibrium, hedge coefficient, convergence speed, or profitable
contrarian rule. The H-L packet fixes arithmetic only. No source tests the
robust pairwise location of one completed month's daily oil-minus-gas returns
as a predictor of next-month reversion.

The synchronized CFD calendar, 17-to-23-session package, daily relative
returns, dynamic inclusive pair set, exact pseudomedian, contrarian direction,
fixed cash risk, ATR stops, spread caps, atomic pair lifecycle, and restart
ledger are transparent QM translations. No source return, alpha, probability,
density, Sharpe ratio, drawdown, cost, hedge ratio, neutrality, CFD
equivalence, or portfolio-correlation statistic transfers.

## Bounded QM Mechanization

On the first executable synchronized `XTIUSD.DWX`/`XNGUSD.DWX` D1 bar of a new
broker month, reconstruct every synchronized close pair in the immediately
preceding calendar month plus one adjacent older pair. Require 17 through 23
completed-month sessions.

Starting from the older boundary pair, form one chronological relative log
return ending on every completed-month session:

```text
s[j] = ln(XTI_close[j]) - ln(XNG_close[j])
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

hl > 0 => SELL XTI, BUY XNG
hl < 0 => BUY XTI, SELL XNG
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
pseudomedian and never gates the trade. A zero pseudomedian or invalid state
consumes the month flat. Neither pseudomedian nor endpoint magnitude changes
risk.

## Exact Event Contract

1. Require exact `XTIUSD.DWX` host, exact `XNGUSD.DWX` companion, D1, and entry
   no later than 180 elapsed minutes after the raw first host D1 bar open of a
   new broker month.
2. Require exact synchronized host/companion timestamps. Within a fixed
   45-bar buffer, the newest completed pair must belong to the immediately
   prior month; require 17-23 unique completed-month pairs in strict
   reverse-time order and one adjacent older boundary pair. Exclude all
   current-month closes.
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
   no targets, 1,500-point XTI and 3,000-point XNG spread ceilings, and at most
   20% realized notional mismatch.
8. Submit the pair atomically: if the second leg fails or any owned state is
   malformed, close all owned exposure immediately and do not retry.
9. Close both legs on the first tick in a later broker month, with a forty-
   calendar-day stale repair. Flatten orphaned, duplicated, same-side,
   wrong-magic, stopless, or notional-invalid owned exposure immediately.

Both news axes, the legacy news mode, and Friday close are OFF. Runtime uses
registered MT5 history, calendar, quotes, symbol metadata, ATR, position/deal
state, and persistent terminal state only.

## Non-Duplicate Functional Boundary

The fail-closed canonical checker scanned 4,691 registry identities, 1,342
cards, and 45 current Strategy Wiki nodes. It found no exact identity and
surfaced only the expected fuzzy method neighbor `QM5_20276_wti-hl-mom`.
Evidence is
`artifacts/qm5_xtixng_mdaily_hl_rv_preallocation_dedup_20260829.json`.

Manual semantic review fixes a new mechanic:

- `QM5_20276` uses twelve disjoint monthly outright-WTI returns, follows the
  pseudomedian, and owns one directional energy position. This extraction
  uses one completed month of daily oil-minus-gas returns, fades the
  pseudomedian, and owns a two-leg relative-value package.
- `QM5_41138_xauxag-mdaily-hl-rv` uses the same arithmetic family and monthly
  lifecycle on a gold/silver path. This extraction owns an economically
  distinct oil/gas path, adverse regime evidence, energy contract metadata,
  and XTI/XNG spread ceilings.
- `QM5_41190_xtixng-mtheilsen-rv` uses thirteen monthly ratio levels and all
  78 forward time-normalized slopes. This extraction uses 17-23 adjacent
  daily relative returns from one completed month and all 153-276 inclusive
  pairwise return averages. Pair bounds, denominators, state, horizon, and
  central object differ.
- Repeated-median and LAD siblings estimate slopes on monthly levels.
  Mann-Whitney, Wilcoxon, Cox-Stuart, Spearman, Pettitt, median-runs, OLS,
  fixed-ratio, return-spread, calendar, and weekday cards consume different
  state objects and clocks.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback.

The exact paired carrier, completed month, older boundary pair, every daily
relative return, inclusive pair enumeration, dynamic pair count, exact
pseudomedian, contrarian package, consumed month, aggregate fixed risk, and
next-month lifecycle are jointly load bearing. Verdict:
`CLEAN_XTIXNG_COMPLETED_MONTH_DAILY_HODGES_LEHMANN_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_DAILY_PSEUDOMEDIAN_TRANSLATION_RISK`. The lineage preserves
  a complete U.S. government report and complete named-author peer-reviewed
  Energy Journal paper with DOI for the oil/gas relationship and its adverse
  regime evidence. The exact daily pseudomedian and contrarian next-month
  direction are untested; the governed H-L packet is arithmetic precedent.
- R2: `PASS`. Clock, synchronization, month, boundary, observations, relative
  returns, identity, inclusive pair bounds, pair count, ascending sort,
  odd/even median, sides, attempt, aggregate risk, stops, atomicity, spread
  gates, and lifecycle are fixed.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` and `XNGUSD.DWX` D1 histories and MT5-native state supply every
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
dollar, beta, volatility, factor, market, or portfolio neutrality. Q09 alone
owns the realized portfolio result. No failure may be rescued by changing the
sample, pair convention, median formula, direction, carrier, risk, hold, or by
adding endpoint agreement, a fitted center or scale, event, seasonal,
volatility, external, or prior-result state.

## Safety Boundary

This packet supports one Strategy Card, one branch-only V5 build, strict
compile/Q01, and one paced non-live logical Q02 handoff only. It does not
authorize a manual backtest, live artifact, `T_Live`, AutoTrading, deploy
manifest, portfolio-gate change, portfolio admission, correlation waiver,
terminal control, or decorrelation claim.
