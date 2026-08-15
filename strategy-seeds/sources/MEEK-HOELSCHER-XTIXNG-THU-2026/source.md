---
source_id: MEEK-HOELSCHER-XTIXNG-THU-2026
title: XTI/XNG Thursday source-coefficient relative-value differential
publisher: Cogent Economics & Finance
source_type: governed_peer_reviewed_translation_packet
status: approved
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-15
strategy_ids: [MEEK-HOELSCHER-XTIXNG-THU-2026_S01]
parent_sources: [MEEK-HOELSCHER-WTI-DOW-2023]
---

# XTI/XNG Thursday Relative-Value Source Packet

## Source Identity And Complete-Read Evidence

This packet binds one translation to the completely reviewed parent packet
`strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md`.

The primary source is Andrew C. Meek and Seth A. Hoelscher (2023),
"Day-of-the-week effect: Petroleum and petroleum products," *Cogent Economics
& Finance* 11(1), article 2213876, DOI
`10.1080/23322039.2023.2213876`. The parent records a complete review of the
21-page open EconStor copy, including contract construction, price-synching,
all five conditional-variance specifications, result tables, limitations,
conclusion, disclosures, and references.

The paper uses synchronized front-/second-month WTI and natural-gas futures
from 2002 through 2021 and defines daily close-to-close log returns. WTI Table
2 reports Thursday coefficients of `+0.000679`, `-0.000189`, `-0.000155`,
`-0.000010`, and `+0.000270`. Natural-gas Table 6 reports Thursday
coefficients of `-0.001671`, `-0.001339`, `-0.001333`, `-0.001432`, and
`-0.001323`; each natural-gas coefficient is marked significant at the 10% or
5% level. Restricting attention to the four asymmetric-variance models gives
an untested raw long-WTI/short-natural-gas Thursday differential of roughly
11-17 basis points.

The authors document heterogeneous energy weekday effects. They do not test
this cross-energy pair, covariance, beta neutrality, equal-notional sizing,
combined fixed-dollar risk, hard stops, Darwinex CFDs, or costs. No source
performance or portfolio claim transfers.

## Bounded Mechanization

`MEEK-HOELSCHER-XTIXNG-THU-2026_S01` locks one simultaneous package:

- exact host `XTIUSD.DWX`, D1, magic slot 0, BUY;
- exact paired leg `XNGUSD.DWX`, D1, magic slot 1, SELL;
- a genuine Thursday whose immediately prior completed host D1 bar is
  Wednesday, with synchronized current D1 bars on both symbols;
- one Monday-anchored broker-week attempt persisted before fallible gates;
- approximately equal absolute USD notionals within a fixed tolerance;
- one `RISK_FIXED=1000` package budget split across frozen
  `3.5 * ATR(20,D1)` per-leg hard stops;
- immediate repair of orphaned, duplicated, same-sided, wrong-symbol,
  wrong-magic, or materially imbalanced composition;
- normal close at broker Thursday 21:00, with first-non-Thursday and
  three-calendar-day stale repairs; and
- fixed spread caps, no target, no scale-in, no external runtime feed.

The source labels returns by their ending weekday. Entering on the first
Thursday D1 tick and closing at broker hour 21 omits the Wednesday-close to
first-Thursday-tick gap and does not reproduce the paper's liquidity-synched
futures roll. That mapping, small gross differential, costs, legging, natural-
gas tails, holidays, financing, equal-notional rather than beta neutrality,
and post-2021 decay are binding kill risks.

## Non-Duplicate Boundary

The canonical pre-card check returned no exact hit across 4,501 registry rows
and 597 cards. Its only fuzzy hit, `xtixng-ecm-rv`, shares carrier tokens but
uses a 252-D1 OLS error-correction residual.

The Friday relative-value package (`QM5_20110`) uses the source's significant
WTI Friday premium and weak negative XNG Friday coefficient. This candidate
uses the separately reported significant XNG Thursday discount and near-zero
WTI Thursday return. The Monday pair (`QM5_20016`) has the opposite directions.
Outright XNG Thursday (`QM5_12819`) has no WTI hedge, package budget, equal-
notional invariant, or atomic repair. Price-state XTI/XNG baskets are not
weekday-differential packages.

Verdict: `CLEAN_THURSDAY_XTI_XNG_SOURCE_DIFFERENTIAL_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1: PASS. Named peer-reviewed open paper, DOI, complete-paper repository
  review, and exact table-level evidence.
- R2: PASS. Weekday, directions, synchronization, attempt, joint sizing,
  stops, spread caps, repair, and exits are locked.
- R3: PASS. Both D1 symbols are registered and already exercised by governed
  logical-basket builds.
- R4: PASS. Native MT5 arithmetic and state only; no runtime GARCH, trained
  model, banned signal indicator, external feed, grid, martingale, scale-in,
  or pyramid.

## Safety Boundary

This packet authorizes one branch-only Strategy Card, deterministic registry
allocation, non-live V5 build, strict compile, one fixed-risk setfile, and one
paced Q02 enqueue. It does not authorize a manual tester; live, demo, shadow,
stress, or optimization execution; AutoTrading; `T_Live`; a deploy/T_Live
manifest; portfolio admission; a portfolio-gate change; or a correlation
waiver.
