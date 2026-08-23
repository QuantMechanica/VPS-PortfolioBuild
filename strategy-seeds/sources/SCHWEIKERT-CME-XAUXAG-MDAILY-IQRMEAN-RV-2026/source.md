---
source_id: SCHWEIKERT-CME-XAUXAG-MDAILY-IQRMEAN-RV-2026
title: XAU/XAG completed-month daily-relative-return interquartile-mean reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-23_xauxag_monthly_daily_interquartile_mean_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-23
created_by: Research+Development
cards_extracted:
  - xauxag-mdaily-iqrmean-rv
---

# XAU/XAG Completed-Month Daily-Relative-Return Interquartile-Mean Reversion Source Packet

## Approved source of record

The primary source is Karsten Schweikert (2018), "Are gold and silver
cointegrated? New evidence from quantile cointegrating regressions,"
*Journal of Banking & Finance* 88, 44-51, DOI
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

Both parent records were read completely before source approval. Their exact
hashes and the durable OWNER authorization are fixed in
`decisions/2026-08-23_xauxag_monthly_daily_interquartile_mean_reversion_source_approval.md`,
committed before this extraction at `2afaad159`. No blocked page, inferred
coefficient, unrecorded performance result, or secondary trading summary is
used.

## Source findings used

Schweikert supports testing a related but state-dependent long-run relation
between gold and silver rather than assuming a constant hedge coefficient or
one immutable equilibrium. CME supports representing that relation through a
tradable gold/silver intermarket spread and gives an economic reason for
relative displacements: the two metals share precious-metals and USD drivers
but differ in monetary, safe-haven, industrial, and business-cycle exposure.

Those findings support a falsifiable relative-value reversion carrier. They do
not establish that the central half of daily gold-minus-silver returns inside
one completed month predicts the following month. They also do not establish
equal-notional neutrality, continuous-CFD equivalence, the exact holding
period, or any QM portfolio result.

The synchronized CFD calendar, 17-to-23-session package, integer-quartile
trim, central arithmetic mean, contrarian direction, fixed cash risk, ATR
stops, spread caps, atomic pair lifecycle, and restart ledger are QM
translations. No source alpha, return, probability, density, Sharpe ratio,
drawdown, cost, hedge ratio, neutrality, CFD equivalence, or correlation
statistic transfers.

## Bounded QM mechanization

On the first executable synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 bar of a
new broker month, reconstruct every synchronized close pair in the immediately
preceding calendar month plus one adjacent older pair. Require 17 through 23
completed-month sessions.

Starting from the older boundary pair, form one chronological relative log
return ending on every completed-month session:

```text
s[j] = ln(XAU_close[j]) - ln(XAG_close[j])
r[j] = s[j] - s[j-1]

sorted = ascending(r[0], ..., r[n-1])
k = floor(n / 4)
retained_count = n - 2 * k
central_sum = sum(sorted[i], i=k..n-k-1)
central_mean = central_sum / retained_count

central_mean > 0 => SELL XAU, BUY XAG
central_mean < 0 => BUY XAU, SELL XAG
otherwise        => FLAT
```

For 17 through 23 synchronized sessions, exactly four or five relative
returns are removed from each tail and exactly 9 through 13 central
observations remain. Require positive finite closes, finite log ratios and
relative returns, valid indexes, a retained count of at least nine, and a
finite central sum and mean.

Verify that the sum of the unsorted chronological relative returns equals the
direct older-boundary-to-final log-ratio displacement within `1e-10`. Sorting
and trimming change only the direction estimator; they never change package
membership or endpoint identity.

The raw relative endpoint is diagnostic only. It may agree or disagree with
the central mean and does not gate the trade. A zero central mean or any
invalid state consumes the month flat. Neither central mean nor endpoint
magnitude changes risk.

## Exact event contract

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
4. Sort all relative returns ascending without rounding. Remove exactly
   `floor(n/4)` returns from each tail, retain the closed integer index
   interval between those tails, and average every retained observation once.
5. Fade the strict central-mean sign with opposite legs. Equality and invalid
   states remain flat. The raw endpoint is an identity diagnostic, never a
   confirmation filter.
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

## Non-duplicate boundary

The fail-closed canonical checker scanned 4,634 registry identities, 1,302
cards, and 45 Strategy Wiki nodes using the actual Company Reference root. It
found no exact or fuzzy candidate collision and returned `CLEAN`. Evidence is
`artifacts/qm5_xauxag_mdaily_iqrmean_rv_preallocation_dedup_20260823.json`.

Manual semantic review fixes a new mechanic:

- rolling ratio, OLS, quantile, and MAD cards fit a center, coefficient,
  scale, or crossing. This extraction fits none.
- `QM5_41112_xauxag-mdaybreadth-rv` counts daily signs; block and sequence
  cards aggregate calendar sections or ordered states. This extraction sorts
  all daily magnitudes and uses the exact retained central band.
- `QM5_41123_xauxag-mpath-eff-rv` divides net displacement by an L1 path,
  `QM5_41125_xauxag-mrms-coherence-rv` divides it by an L2 path, and
  `QM5_41128_xauxag-mdaily-persist-rv` estimates adjacent demeaned-return
  dependence. None selects an order-statistic central band.
- `QM5_41134_wti-mdaily-iqrmean-mom` follows the analogous statistic on one
  outright WTI leg. This extraction applies it to synchronized gold-minus-
  silver relative returns, reverses the sign, and owns an atomic equal-
  notional two-leg package.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG
  oscillator pullback.

The exact paired carrier, completed month, older boundary pair, every daily
relative return, full-sample ascending sort, dynamic integer-quartile tail
removal, central-band arithmetic mean, contrarian package, consumed month,
aggregate fixed risk, and next-month lifecycle are jointly load bearing.
Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_DAILY_INTERQUARTILE_MEAN_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-source criteria

- R1: `PASS_WITH_WITHIN_MONTH_IQR_LOCATION_TRANSLATION_RISK`. The lineage
  preserves a named-author peer-reviewed gold/silver-relation paper with DOI
  and complete-read record plus official exchange research for the spread
  carrier and its distinct drivers. The exact central-band estimator and
  contrarian next-month direction are untested.
- R2: `PASS`. Clock, synchronization, month, boundary, observations, relative
  returns, identity, ascending sort, integer tail count, retained indexes,
  arithmetic mean, sides, attempt, aggregate risk, stops, atomicity, spread
  gates, and lifecycle are fixed.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories and MT5-native state supply every
  runtime input.
- R4: `PASS`. Deterministic timestamps, logarithms, arithmetic, sorting,
  comparison, ATR, and execution state only; no fitted model, trained output,
  banned signal, external feed, grid, martingale, scale-in, or pyramid.

## Claim and kill boundary

Every valid nonzero central mean may qualify, giving a pre-result density
prior near twelve packages per year. This is not market evidence. Q02 must
retire below five completed packages in any full post-warm-up year, at zero
trades, with nonpositive governed economics, or on any synchronization,
month, return, trim, mean, side, attempt, risk, atomicity, lifecycle, or
determinism defect.

The opposite equal-notional legs are economically different from the
certified directional XAU, SP500, NDX, and XNG carriers but do not prove
dollar, beta, volatility, factor, or portfolio neutrality. Q09 alone owns the
realized portfolio result. No failure may be rescued by changing the sample,
trim formula, direction, carrier, risk, hold, or by adding endpoint agreement,
a fitted center or scale, event, seasonal, volatility, external, or prior-
result state.

## Safety boundary

This packet supports one Strategy Card, one branch-only V5 build, strict
compile/Q01, and one paced non-live Q02 handoff only. It does not authorize a
manual backtest, live artifact, `T_Live`, AutoTrading, deploy manifest,
portfolio-gate change, portfolio admission, correlation waiver, terminal
control, or decorrelation claim.
