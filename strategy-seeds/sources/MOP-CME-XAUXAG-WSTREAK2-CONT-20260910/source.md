---
source_id: MOP-CME-XAUXAG-WSTREAK2-CONT-20260910
title: Gold-silver fresh completed-week two-sign-streak continuation extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange sources
source_type: peer_reviewed_plus_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_xauxag_fresh_two_week_sign_streak_continuation_source_approval.md
parent_source_ids: [MOP-TSMOM-2012, CME-GSR-SPREAD-2025]
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-09-10
created_by: Research+Development
cards_extracted: [xauxag-wstreak2-cont]
---

# XAU/XAG Fresh Two-Week Sign-Streak Continuation Source Packet

## Complete-Read Record

The two bounded parents listed in frontmatter were read completely before the
durable approval at
`decisions/2026-09-10_xauxag_fresh_two_week_sign_streak_continuation_source_approval.md`.
Moskowitz, Ooi, and Pedersen supply peer-reviewed evidence for time-series
continuation across liquid futures and a commodity portfolio. CME defines the
gold/silver price ratio and its intermarket-spread carrier. No new online page,
blocked content, inferred table value, or unrecorded source is used.

These findings justify falsifying a relative-price continuation hypothesis.
They do not establish that two same-sign completed-week relative returns persist
for another week, that equal notional is neutral, or that a Darwinex CFD package
is profitable or decorrelated. The weekly state, direction, risk, and lifecycle
below are transparent pre-result QM translations.

## Bounded Mechanization

At the first tradable XAU D1 bar of each Monday-anchored broker week, align the
four immediately preceding completed week-end closes for input-bound XAU and
XAG symbols. Let `s0` be the newest synchronized completed-week log ratio and
`s3` the oldest, with `r0=s0-s1`, `r1=s1-s2`, and `r2=s2-s3`.

```text
r0 > 0 and r1 > 0 and r2 < 0 => BUY XAU, SELL XAG
r0 < 0 and r1 < 0 and r2 > 0 => SELL XAU, BUY XAG
otherwise                     => FLAT
```

The older opposite return makes the newest two-week streak fresh. After a
third same-sign week the shifted predecessor is no longer opposite, so this
strategy is flat. All prices must be positive and finite, every return is
strict and nonzero, the four weeks must be consecutive and contain three to
five synchronized sessions, and current-week prices are excluded.

One exact Monday-anchor attempt is persisted before fallible gates. The paired
position targets equal absolute notional, shares one `RISK_FIXED=1000` budget,
uses frozen per-leg `3.5*ATR(20,D1)` hard stops and no target, and closes at the
first later week or after ten calendar days as stale repair. There is no fitted
center, regression, threshold, rank, channel, external series, trained output,
signal-strength sizing, grid, martingale, or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation scan covered the current registry, repository
cards, and Strategy Wiki and returned `CLEAN`. `QM5_41417` observes the same
fresh state but takes exactly the opposite economic side; `QM5_41078` requires
five endpoints and strict `-+++` / `+---` before a fade. `QM5_41414` follows a
majority-sign flip across overlapping windows. Adjacent-two-return families use
magnitude ordering and do not require the older opposite sign. The exact
carrier, four endpoints, three signs, fresh two-week state, continuation side,
aggregate risk, and next-week exit are jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_SHORT_HORIZON_RELATIVE_TRANSLATION_RISK`; reputable momentum
  and carrier lineages, with exact weekly relative efficacy explicitly untested.
- R2: `PASS`; clock, data, state, sides, risk, and lifecycle are fully fixed.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`; registered native XAU/XAG
  D1 data supplies every runtime market input.
- R4: `PASS`; deterministic timestamp, price, logarithm, ATR, quote, position,
  deal, and persistent-state arithmetic only.

## Falsification And Safety Boundary

Q02 retires on zero packages, fewer than five packages in any full post-warm-up
year, nonpositive governed economics, wrong synchronization or sign state,
same-week retry, missing stops, broken pairing, wrong exit, or nondeterminism.
Changing the endpoint count, streak length, predecessor rule, direction, risk,
or lifecycle creates a new identity and requires full requalification.

This packet authorizes research, one branch-only V5 build, strict Q01, and one
paced non-live logical Q02 handoff only. It does not authorize a manual tester,
live artifacts, AutoTrading, `T_Live`, deploy manifests, portfolio-gate changes,
portfolio admission, correlation waivers, or neutrality claims.
