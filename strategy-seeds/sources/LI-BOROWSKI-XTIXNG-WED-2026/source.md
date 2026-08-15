---
source_id: LI-BOROWSKI-XTIXNG-WED-2026
title: XTI/XNG Wednesday crude-versus-natural-gas relative-value differential
source_type: governed_composite_research_packet
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-16_xtixng_wednesday_relative_value_source_approval.md
approval_commit: 53ddb9b4b
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-16
created: 2026-08-16
created_by: Research+Development
strategy_ids: [LI-BOROWSKI-XTIXNG-WED-2026_S01]
parent_sources:
  - LI-WTI-DOW-2022
  - BOROWSKI-COMM-DOW-2016
  - MEEK-HOELSCHER-WTI-DOW-2023
---

# XTI/XNG Wednesday Relative-Value Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet combines two governed peer-reviewed directional lineages
and preserves one newer adverse replication:

1. Li, Zhu, Wen, and Mohd Nor (2022), *Energy Economics* 106, article 105817,
   DOI `10.1016/j.eneco.2022.105817`. The complete bounded abstract/highlights
   review at `strategy-seeds/sources/LI-WTI-DOW-2022.md` supplies the positive
   WTI Wednesday direction, the scheduled inventory-information interpretation,
   and the authors' warning that weekday efficiency evolves through time.
2. Borowski (2016), *Journal of Management and Financial Sciences* 26, 27-44.
   The complete-paper review at
   `strategy-seeds/sources/BOROWSKI-COMM-DOW-2016/source.md` supplies the
   negative natural-gas Wednesday direction, sample mean `-0.2664%`, and
   reported mean-equality rejection `p=0.0136` over 1990-2016.
3. Meek and Hoelscher (2023), *Cogent Economics & Finance* 11(1), article
   2213876, DOI `10.1080/23322039.2023.2213876`. The complete 21-page review at
   `strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md` is adverse
   evidence. Its WTI Wednesday coefficient is positive but significant only
   in the symmetric model; its natural-gas Wednesday coefficients are positive
   and insignificant across all five models.

The two directional parents use different samples and do not test a paired
portfolio. The newer natural-gas sign conflict, multiple calendar testing,
time variation, and post-sample decay are load-bearing Q02 risks. No source
performance statistic, covariance, neutrality, cost, or portfolio result is
imported.

## Bounded Mechanization

`LI-BOROWSKI-XTIXNG-WED-2026_S01` is one predeclared logical package:

- exact host `XTIUSD.DWX`, D1, magic slot 0, BUY;
- exact paired leg `XNGUSD.DWX`, D1, magic slot 1, SELL;
- a genuine broker Wednesday whose immediately prior completed host D1 bar is
  Tuesday, with synchronized current D1 timestamps on both symbols;
- one Monday-anchored broker-week attempt persisted before fallible gates;
- approximately equal absolute USD notionals within ten-percent relative
  tolerance;
- one `RISK_FIXED=1000` package budget across frozen
  `3.5 * ATR(20,D1)` per-leg hard stops;
- immediate rollback or repair of partial, orphaned, duplicated, same-sided,
  wrong-symbol, wrong-magic, or materially imbalanced exposure;
- normal close at broker Wednesday 21:00, with first-non-Wednesday D1 and
  three-calendar-day stale repair exits; and
- fixed spread caps, no target, no scale-in, and no external runtime feed.

The papers label returns by the ending weekday. Entering on the first
Wednesday D1 tick and closing at broker hour 21 omits any Tuesday-close to
first-Wednesday-tick gap and does not reproduce either paper's futures roll or
settlement boundary. That mapping, costs, legging, financing, holidays,
natural-gas tails, equal-notional rather than beta neutrality, and source
conflict are binding kill risks.

## Non-Duplicate Boundary

The canonical pre-card check scanned 4,505 registry rows and 601 root cards.
It found no exact identity and three expected fuzzy family siblings. Manual
review returned
`CLEAN_WEDNESDAY_XTI_XNG_JOINT_PACKAGE_WITH_KNOWN_COMPONENT_OVERLAP`:

- `QM5_20022_wti-wed-long` and `QM5_20018_xng-wed-short` are known standalone
  components without a logical basket, combined risk budget, equal-notional
  invariant, atomic rollback/repair, or paired return stream;
- `QM5_41014_xtixng-thu-rv` shares the leg direction but owns Thursday, a
  disjoint source coefficient and session;
- `QM5_41015_xtixng-tue-rv` uses Tuesday and the opposite leg direction;
- the Monday and Friday XTI/XNG packages own different session clocks; and
- `QM5_20237_xtixng-ecm-rv` uses a rolling error-correction residual rather
  than a fixed calendar decision.

Neither standalone Wednesday component is valid under this extraction. The
research object is the joint cross-energy differential. Pairing and equal
notional do not prove beta, volatility, factor, or realized market neutrality.

## Reputable-Source Criteria

- R1 `PASS_WITH_CONFLICTING_MODERN_EVIDENCE`: named peer-reviewed sources,
  DOI identities, a complete bounded tier-A review, one complete tier-B paper
  review, and one complete open adverse modern review.
- R2 `PASS`: weekday, continuity, directions, synchronized bars, attempt,
  joint sizing, stops, spread caps, package repair, and exits are fixed.
- R3 `PASS`: both D1 symbols and the logical-basket route are registered and
  need no external runtime data.
- R4 `PASS`: native MT5 calendar, bars, ATR, quotes, symbol metadata,
  positions, deals, and framework state only; no trained output, banned signal
  indicator, grid, martingale, scale-in, or pyramid.

## Safety And Kill Boundary

Expected cadence is approximately 45-52 completed packages per full year.
Q02 must retire below five/year, on zero trades, wrong weekday or leg
direction, missing prior-Tuesday continuity, repeated attempts, partial or
imbalanced exposure, invalid risk mode, or nonpositive governed economics.
Q09 alone may establish realized portfolio correlation.

This packet authorizes one branch-only Strategy Card, deterministic
allocation, non-live V5 build, strict compile, one fixed-risk backtest setfile,
and one paced Q02 enqueue. It authorizes no manual backtest, live/demo/shadow
setfile, AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio admission,
portfolio-gate change, or correlation waiver.
