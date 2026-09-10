---
source_id: SCHWEIKERT-CME-XAUXAG-WSTREAK2-RV-20260910
title: Gold-silver fresh completed-week two-sign-streak reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange sources
source_type: peer_reviewed_plus_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_xauxag_fresh_two_week_sign_streak_reversion_source_approval.md
parent_source_ids: [SCHWEIKERT-XAUXAG-RATIO-2026, CME-GSR-SPREAD-2025]
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-09-10
created_by: Research+Development
cards_extracted: [xauxag-wstreak2-rv]
---

# XAU/XAG Fresh Two-Week Sign-Streak Reversion Source Packet

## Complete-Read Record

The two bounded parents listed in frontmatter were read completely before the
durable approval at
`decisions/2026-09-10_xauxag_fresh_two_week_sign_streak_reversion_source_approval.md`.
Schweikert supplies peer-reviewed evidence for a potentially state-dependent
gold/silver relation. CME defines the gold/silver price ratio and its
intermarket-spread carrier. No new online page, blocked content, inferred table
value, or unrecorded source is used.

These findings justify falsifying a relative-price reversion hypothesis. They
do not establish that two same-sign completed-week relative returns exhaust a
move, that the next week reverses, that equal notional is neutral, or that a
Darwinex CFD package is profitable or decorrelated. The weekly state, direction,
risk, and lifecycle below are transparent pre-result QM translations.

## Bounded Mechanization

At the first tradable `XAUUSD.DWX` D1 bar of each Monday-anchored broker week,
align the four immediately preceding completed week-end closes for XAU and XAG.
Let `s0` be the newest synchronized completed-week log ratio and `s3` the
oldest, with `r0=s0-s1`, `r1=s1-s2`, and `r2=s2-s3`.

```text
r0 > 0 and r1 > 0 and r2 < 0 => SELL XAU, BUY XAG
r0 < 0 and r1 < 0 and r2 > 0 => BUY XAU, SELL XAG
otherwise                     => FLAT
```

The older opposite return makes the newest two-week streak fresh. After a
third same-sign week the shifted predecessor is no longer opposite, so this
strategy is flat when the existing three-week-streak system evaluates. All
prices must be positive and finite, every return is strict and nonzero, the
four weeks must be consecutive and contain three to five synchronized sessions,
and current-week prices are excluded.

One exact Monday-anchor attempt is persisted before fallible gates. The paired
position targets equal absolute notional, shares one `RISK_FIXED=1000` budget,
uses frozen per-leg `3.5*ATR(20,D1)` hard stops and no target, and closes at the
first later week or after ten calendar days as stale repair. There is no fitted
center, regression, threshold, rank, channel, calendar, external series,
trained output, signal-strength sizing, grid, martingale, or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation scan found no exact identity and only the expected
fuzzy `QM5_41078_xauxag-wstreak3-rv` sibling. That system requires five
endpoints and `-+++` / `+---`; this source fixes four endpoints and `-++` /
`+--`. They act on different weekly decision events. The adjacent-two-return
family `QM5_41066` and `QM5_41075` through `QM5_41077` uses magnitude ordering,
whereas this event ignores magnitude and requires an older opposite return.
Daily-run, fitted-residual, monthly, flow, range, gap, and rank identities do
not use this exact event. The exact carrier, four endpoints, three signs, fresh
two-week state, contrarian package, aggregate risk, and next-week exit are
jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_WEEKLY_STREAK_REVERSION_TRANSLATION_RISK`; reputable carrier
  and relationship lineage, with exact weekly efficacy explicitly untested.
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
