---
source_id: MEEK-HOELSCHER-XTIXNG-TUE-2026
title: XTI/XNG Tuesday source-coefficient relative-value differential
publisher: Cogent Economics & Finance
source_type: governed_peer_reviewed_translation_packet
status: approved
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-15
strategy_ids: [MEEK-HOELSCHER-XTIXNG-TUE-2026_S01]
parent_sources: [MEEK-HOELSCHER-WTI-DOW-2023]
primary_url: https://doi.org/10.1080/23322039.2023.2213876
open_full_text_url: https://www.econstor.eu/bitstream/10419/304091/1/10.1080_23322039.2023.2213876.pdf
---

# XTI/XNG Tuesday Relative-Value Source Packet

## Source Identity And Complete-Read Evidence

This packet binds one translation to the completely reviewed parent packet
`strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md`.

The sole primary source is Andrew C. Meek and Seth A. Hoelscher (2023),
"Day-of-the-week effect: Petroleum and petroleum products," *Cogent Economics
& Finance* 11(1), article 2213876, DOI
`10.1080/23322039.2023.2213876`. The parent records a complete review of the
21-page open EconStor copy, including contract construction, price synching,
all five conditional-variance specifications, result tables, limitations,
conclusion, disclosures, and references.

The paper uses synchronized front-/second-month WTI and natural-gas futures
from 2002 through 2021 and defines daily close-to-close log returns. WTI Table
2 reports Tuesday coefficients of `+0.000238`, `-0.000348`, `-0.000285`,
`-0.000086`, and `+0.000001`; none is marked significant. Natural-gas Table 6
reports Tuesday coefficients of `+0.001295`, `+0.001857`, `+0.001695`,
`+0.001508`, and `+0.001620`; the last four are marked significant at the 10%
or 5% level. Restricting attention to those four asymmetric-variance models
gives an untested raw long-natural-gas/short-WTI Tuesday coefficient
differential of `+0.002205`, `+0.001980`, `+0.001594`, and `+0.001619`, or
roughly 16-22 basis points.

The authors document heterogeneous energy weekday effects. They do not test
this cross-energy pair, covariance, beta neutrality, equal-notional sizing,
combined fixed-dollar risk, hard stops, Darwinex CFDs, or costs. No source
performance, density, drawdown, or portfolio claim transfers.

## Bounded Mechanization

`MEEK-HOELSCHER-XTIXNG-TUE-2026_S01` locks one simultaneous package:

- exact host `XTIUSD.DWX`, D1, magic slot 0, SELL;
- exact paired leg `XNGUSD.DWX`, D1, magic slot 1, BUY;
- a genuine Tuesday whose immediately prior completed host D1 bar is Monday,
  with synchronized current D1 bars on both symbols;
- one Monday-anchored broker-week attempt persisted before fallible gates;
- approximately equal absolute USD notionals within a fixed tolerance;
- one `RISK_FIXED=1000` package budget split across frozen
  `3.5 * ATR(20,D1)` per-leg hard stops;
- immediate repair of orphaned, duplicated, same-sided, wrong-symbol,
  wrong-magic, or materially imbalanced composition;
- normal close at broker Tuesday 21:00, with first-non-Tuesday and
  three-calendar-day stale repairs; and
- fixed spread caps, no target, no scale-in, no external runtime feed.

The source labels returns by their ending weekday. Entering on the first
Tuesday D1 tick and closing at broker hour 21 omits the Monday-close to
first-Tuesday-tick gap and does not reproduce the paper's liquidity-synched
futures roll. That mapping, costs, legging, natural-gas tails, holidays,
financing, equal-notional rather than beta neutrality, and post-2021 decay are
binding kill risks.

## Non-Duplicate Boundary

The canonical pre-card check returned no exact hit across 4,502 registry rows
and 598 root-card files. It returned two expected fuzzy siblings:

- `QM5_41014_xtixng-thu-rv` uses the opposite package direction on Thursday,
  derived from WTI's near-zero Thursday coefficient and natural gas's
  significant Thursday discount; and
- `QM5_20237_xtixng-ecm-rv` estimates a rolling 252-D1 trend-augmented OLS
  error-correction residual and has no weekday return clock.

`QM5_12610_wti-tue-fade` and `QM5_12818_xng-tue-prem` are known standalone
components. Neither owns the simultaneous logical basket, one combined risk
budget, equal-notional invariant, atomic repair, or paired return stream.
`QM5_20016_xti-xng-mon-rv` enters the same directions for the Monday return
clock and closes at Tuesday's first tick; this candidate enters only after
that position is flat and owns the Tuesday session. Friday and Thursday
XTI/XNG packages use different coefficient objects and session clocks.

Verdict: `CLEAN_TUESDAY_XTI_XNG_SOURCE_DIFFERENTIAL_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1: PASS. One named peer-reviewed open paper, DOI, complete-paper repository
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
