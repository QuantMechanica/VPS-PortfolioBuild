---
source_id: MOP-WTI-WSTREAK2-CONT-20260910
title: WTI fresh completed-week two-sign-streak continuation extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_wti_fresh_two_week_sign_streak_continuation_source_approval.md
parent_source_ids: [MOP-TSMOM-2012]
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-09-10
created_by: Research+Development
cards_extracted: [wti-wstreak2-cont]
---

# WTI Fresh Two-Week Sign-Streak Continuation Source Packet

## Complete-Read Record

The bounded parent above was read completely before the durable approval at
`decisions/2026-09-10_wti_fresh_two_week_sign_streak_continuation_source_approval.md`.
Moskowitz, Ooi, and Pedersen supply peer-reviewed evidence for own-return
continuation across liquid futures and identify WTI in the tested commodity
universe. No new online page, blocked content, inferred table value, or
unrecorded source is used.

The evidence justifies falsifying a direct-WTI continuation hypothesis. It
does not establish that two same-sign completed-week returns persist for
another week, or that a Darwinex CFD implementation is profitable or
decorrelated. The weekly state, entry, risk, and lifecycle below are
transparent pre-result QM translations.

## Bounded Mechanization

At the first tradable XTIUSD.DWX D1 bar of each Monday-anchored broker week,
reconstruct the final closes of exactly the four immediately preceding
consecutive completed weeks. Let `C0` be newest and `C3` oldest, with
`r0=ln(C0/C1)`, `r1=ln(C1/C2)`, and `r2=ln(C2/C3)`.

```text
r0 > 0 and r1 > 0 and r2 < 0 => BUY WTI
r0 < 0 and r1 < 0 and r2 > 0 => SELL WTI
otherwise                     => FLAT
```

The older opposite return makes the newest two-week streak fresh. After a
third same-sign week the shifted predecessor is no longer opposite, so the
strategy is flat. Prices must be positive and finite, returns strict and
nonzero, and each consecutive week must contain three to five unique ordered
sessions. Current-week observations are excluded.

One exact Monday-anchor attempt is persisted before fallible gates. One WTI
position uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling. It
closes at the first later week or after ten days as stale repair. There is no
fitted threshold, rank, channel, external series, trained output,
signal-strength sizing, grid, martingale, or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation scan returned `CLEAN`. `QM5_41074` requires a
fresh three-week streak and `QM5_41415` fades that longer state. Seasonal WTI
two-week agreement cards restrict eligibility by month and do not require an
older opposite predecessor. `QM5_41418` applies a similar sign topology to a
two-leg gold/silver relative basket rather than direct WTI. The exact carrier,
four endpoints, three signs, fresh two-week state, continuation side, fixed
risk, and next-week exit are jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_SHORT_HORIZON_STATE_TRANSLATION_RISK`; named peer-reviewed
  momentum research with explicit WTI membership and complete-read evidence.
- R2: `PASS`; clock, data, state, side, risk, and lifecycle are fully fixed.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`; registered native
  XTIUSD.DWX D1 data supplies every runtime market input.
- R4: `PASS`; deterministic timestamp, price, logarithm, ATR, quote, position,
  deal, and persistent-state arithmetic only.

## Falsification And Safety Boundary

Q02 retires on zero trades, fewer than five trades in any full post-warm-up
year, nonpositive governed economics, wrong labels or sign state, same-week
retry, missing stop, wrong exit, or nondeterminism. Changing carrier, endpoint
count, streak length, predecessor rule, direction, risk, or lifecycle creates
a new identity and requires full requalification.

This packet authorizes research, one branch-only V5 build, strict Q01, and one
paced non-live Q02 handoff only. It does not authorize a manual tester, live
artifacts, AutoTrading, `T_Live`, deploy manifests, portfolio-gate changes,
portfolio admission, correlation waivers, or decorrelation claims.
