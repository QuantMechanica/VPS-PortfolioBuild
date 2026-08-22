---
source_id: SCHWEIKERT-CME-XAUXAG-MRANGE-MIGRATE-RV-2026
title: XAU/XAG completed-month daily-close ratio-range migration reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_xauxag_monthly_ratio_range_migration_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - xauxag-mrange-migrate-rv
---

# XAU/XAG Completed-Month Ratio-Range Migration Reversion Source Packet

## Approved Sources Of Record

This bounded extraction uses one canonical child `source_id` with two already
governed parent packets, both read completely before durable approval:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, covering
   Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, plus the supplemental
   robust fractional-cointegration lineage recorded there. Its current
   SHA-256 is
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, covering CME Group's
   definition and tradable-relative-value framing of the gold/silver ratio.
   Its current SHA-256 is
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.

The OWNER source authorization is
`decisions/2026-08-22_xauxag_monthly_ratio_range_migration_reversion_source_approval.md`,
commit `d947ea184`. No new online page, blocked content, inferred table value,
or unrecorded source is used.

## Source Findings Used

Schweikert documents a potentially state-dependent long-run relationship
between gold and silver prices and warns against assuming one immutable linear
equilibrium. The supplemental research recorded in the parent packet also
supports testing persistent but potentially fractional mean reversion. CME
defines the gold/silver ratio as gold price divided by silver price and treats
the two metals as an intermarket relative-value carrier with shared and
different economic drivers.

These findings support a falsifiable two-leg gold/silver relative-value
reversion experiment. They do not define completed calendar-month packages,
daily-close ratio ranges, migration of both range endpoints, a next-month
contrarian hold, a unit hedge ratio, Darwinex CFDs, fixed-dollar ATR risk,
spread caps, restart persistence, or the QM portfolio. Every such choice below
is an explicit QM hypothesis; no source result transfers.

## Bounded QM Mechanization

On the first tradable `XAUUSD.DWX` D1 bar of each broker-calendar month,
aggregate the immediately completed month and its consecutive parent month
from timestamp-identical `XAUUSD.DWX` and `XAGUSD.DWX` D1 closes. For every
synchronized completed session compute:

```text
r[d] = log(XAUUSD.DWX_close[d]) - log(XAGUSD.DWX_close[d])
```

For the newest completed month let `U0=max(r)` and `L0=min(r)`. For its parent
let `U1=max(r)` and `L1=min(r)`:

```text
U0 > U1 and L0 > L1  => ratio range migrated up
                         SELL XAUUSD.DWX / BUY XAGUSD.DWX
U0 < U1 and L0 < L1  => ratio range migrated down
                         BUY XAUUSD.DWX / SELL XAGUSD.DWX
otherwise             => FLAT
```

This is a contrarian fade of strict migration of the entire observed monthly
daily-close ratio range. It does not use a rolling mean, standard deviation,
z-score, regression, fitted beta, range width, current-month confirmation,
per-leg return rank, or migration magnitude. Mixed states, overlapping
endpoints that migrate in different directions, and equality at either
endpoint stay flat.

The paired position follows the faded completed-month state until the first
tick of a later broker-calendar month. The month aggregation, daily-close
range proxy, fixed unit log ratio, contrarian side, equal-notional basket,
continuous-CFD carrier, fixed-risk budget, ATR stops, spread caps, consumed-
attempt ledger, next-month exit, and stale repair are QM choices. They are not
attributed to either source.

## Exact Event Contract

All current decision-month data is excluded. The prior two packages must be
the two immediately preceding consecutive calendar months. Each package must
contain 17 through 23 unique, strictly increasing D1 sessions. Both legs must
have identical timestamps for every accepted session. Every close must be
positive and finite, every computed log ratio must be finite, and each
month's maximum must be strictly greater than its minimum.

One exact `yyyymm` attempt is persisted before aggregation, signal, news,
spread, quote, ATR, sizing, or order gates. Attachment later than 180 elapsed
minutes after the raw host D1 bar open consumes the month flat. An existing
owned package, orphan leg, or same-month entry deal blocks a new entry and
enters deterministic repair rather than silently stacking exposure.

The package targets one-to-one absolute entry notional after broker volume
normalization, with no more than 20 percent relative mismatch. The combined
frozen stop-loss risk is capped by one `RISK_FIXED=1000` budget. Each leg uses
one `3.5*ATR(20,D1)` hard stop and no take-profit. Entry spreads may not exceed
1,500 XAU points or 500 XAG points. Both news axes and Friday close are OFF.
The first tick of a later broker month closes the complete package; forty
calendar days is a stale repair only.

There is no rolling center, z-score, fitted coefficient, indicator entry,
return, open, high, low, range-width, volatility, volume, moving-average,
season, weekday, inventory, event, external-series, or prior-result filter.
There is no retry, target, trail, break-even move, partial close, scale-in,
grid, martingale, or pyramid.

## Non-Duplicate Boundary

The fail-closed pre-allocation checker scanned 4,592 registry identities,
1,271 repository cards, and 45 Strategy-Wiki nodes. It found no exact or fuzzy
match and returned `CLEAN`. Manual semantic review fixes the closest identities:

- `QM5_20157_xau-xag-ratio` computes a rolling 60-day log-ratio z-score and
  exits at a rolling center. This extraction has no estimated center or scale
  and decides only from two completed calendar-month range endpoints.
- `QM5_20161_xauxag-ols-rv` fits a rolling OLS residual and hedge coefficient.
  This extraction fits no parameter and uses one fixed unit log ratio.
- `QM5_20202_xauxag-rev18` ranks eighteen-month per-leg returns. This
  extraction does not compute per-leg returns or cross-sectional ranks.
- `QM5_20254_xauxag-vr-fade` gates a daily ratio z-score with a robust monthly
  variance-ratio statistic. This extraction uses neither statistic.
- `QM5_41079_xauxag-wclose-extreme-rv` ranks one final weekly ratio close
  within that week. This extraction compares the full observed ranges of two
  complete calendar months.
- `QM5_41066`, `QM5_41075`, `QM5_41076`, and `QM5_41077` classify adjacent
  completed-week relative-return sign/magnitude paths and hold one week. This
  extraction uses monthly daily-close ranges and holds the next month.
- `QM5_41102_wti-mrange-migrate-mom` follows direct WTI aggregate monthly
  high/low migration. This extraction is a two-leg XAU/XAG ratio fade, uses
  synchronized daily closes rather than one instrument's highs/lows, and
  reverses rather than follows the migrated state.
- Existing return-rank, calendar, flow-decomposition, robust-score, empirical-
  tail, variance, close-location, weekend-gap, and channel systems do not use
  this exact ratio-range state.

The exact XAU/XAG carrier, two consecutive completed calendar-month packages,
17-to-23-session synchronized daily-close contract, strict same-direction
migration of both log-ratio range endpoints, mixed/equality-flat rule,
contrarian equal-notional package, monthly attempt, and next-month lifecycle
are jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_MONTHLY_RATIO_RANGE_STATE_TRANSLATION_RISK`. One bounded
  source ID supplies lineage to named peer-reviewed authors, a DOI record,
  official exchange research, complete repository packets, and durable hashes;
  no performance claim transfers.
- R2: `PASS`. Exact clock, month adjacency, synchronized session membership,
  log-ratio construction, endpoint aggregation, strict comparisons, side,
  durable attempt, aggregate fixed risk, spreads, exit, and stale repair are
  mechanical.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply every
  runtime input. Q02 owns alignment, history, density, fill, cost, and CFD-
  basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed closes, logarithms,
  comparisons, ATR, spread, quotes, positions, deal history, and terminal
  state only; no trained model, external feed, banned signal, grid,
  martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The sources support testing a structural gold/silver relative-value reversion
carrier, not the efficacy of this monthly daily-close range proxy. Expected
cadence is approximately five to nine completed packages per full post-warm-
up year, but Q02 must measure it and retire below five. Q02 also owns baseline
economics; unchanged downstream gates alone own robustness and realized
correlation.

No failure may be rescued by accepting equality or mixed endpoint migration,
changing calendar-month membership, reading the current month, reversing the
side, shortening the hold, fitting a hedge ratio, or adding a center, scale,
return, range-width, volatility, volume, season, weekday, moving-average,
inventory, event, or external-data filter.

## Safety Boundary

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live logical-basket Q02 handoff only. It does not authorize a
manual backtest, live/demo/shadow/stress/optimization preset, `T_Live`,
AutoTrading, deploy or `T_Live` manifest, portfolio-gate change, portfolio
admission, correlation waiver, or decorrelation claim.
