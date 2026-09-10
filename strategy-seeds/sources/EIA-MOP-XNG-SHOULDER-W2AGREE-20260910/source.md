---
source_id: EIA-MOP-XNG-SHOULDER-W2AGREE-20260910
title: XNG shoulder-season two-week agreement continuation
publisher: QuantMechanica governed synthesis of EIA and Moskowitz-Ooi-Pedersen
source_type: official_government_and_peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_xng_shoulder_two_week_agreement_source_approval.md
parent_source_ids: [EIA-XNG-SHOULDER-2026, MOP-TSMOM-2012]
parent_sha256:
  EIA-XNG-SHOULDER-2026: FF535FCCA77F1A79172D3B5A529378A434C5BF430D2B74E45F335666C7612813
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-09-10
created_by: Research+Development
cards_extracted: [xng-shoulder-w2agree]
---

# XNG Shoulder-Season Two-Week Agreement Continuation

## Complete-Read Record

The two bounded parents above were read end to end before the durable approval
at `decisions/2026-09-10_xng_shoulder_two_week_agreement_source_approval.md`.
The EIA packet records recurring spring and autumn natural-gas shoulder periods
between winter heating and summer electric-generation demand. The MOP packet
records a complete read of Moskowitz, Ooi, and Pedersen (2012), *Journal of
Financial Economics*, DOI `10.1016/j.jfineco.2011.11.003`, including own-return
persistence in commodity futures and natural-gas membership.

## Claim And Translation Boundary

EIA supplies only the April-May and September-October demand regime. MOP
supplies broad commodity own-return continuation evidence. Neither source tests
two same-sign completed weeks, the one-week horizon, the cross-source
conjunction, or a continuous natural-gas CFD. The exact strategy is a
transparent pre-result QM translation. No performance or diversification claim
transfers.

## Bounded Mechanization

At the first tradable `XNGUSD.DWX` D1 bar of each normalized broker week:

1. Require the Monday anchor month to be April, May, September, or October.
2. Reconstruct exactly the two immediately completed adjacent normalized
   broker weeks, each with three through five valid D1 sessions.
3. Compute each week's `ln(final_close / first_open)`.
4. When both returns are strictly positive, buy; when both are strictly
   negative, sell. Disagreement, exact zero, or invalid history stays flat.
5. Persist one attempt before fallible gates and never retry that week.
6. Close at the next normalized week; ten elapsed days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The canonical pre-allocation scan returned `CLEAN`. `QM5_41401` fades the same
two-week state in the shoulder months. `QM5_41396` and `QM5_41402` follow the
state only in disjoint summer and winter months. `QM5_12567` is a long-only
cumulative-RSI pullback with a slow trend filter. This identity requires the
four shoulder months, two adjacent same-sign weekly packages, continuation
direction, fixed-risk stop, and one-week lifecycle together.

## Runtime And Falsification

Runtime uses configured-symbol D1 OHLC, broker calendar, quotes, spread, ATR,
symbol metadata, positions, deals, and terminal-global attempt state only. It
does not read EIA data, weather, storage, futures curves, volume, files, APIs,
portfolio state, optimizer output, or trained artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong seasonal eligibility, malformed weekly
packages, disagreement entry, fade rather than continuation direction, retry,
missing stop, wrong rollover, nonpositive governed economics, or
nondeterminism.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: official EIA
  seasonality context and completely read peer-reviewed commodity persistence
  lineage; the exact conjunction is untested.
- R2 `PASS`: calendar, aggregation, strict agreement, continuation direction,
  attempt, risk, stop, spread, and rollover are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XNGUSD.DWX` D1
  history supplies every runtime market input.
- R4 `PASS`: native deterministic arithmetic only; no ML, banned indicator,
  grid, or martingale.

This packet authorizes one branch-only non-live card/build and one paced Q02
handoff. It authorizes no manual backtest, live/demo/shadow/stress setfile,
portfolio admission, deploy manifest, `T_Live` action, AutoTrading change, or
portfolio-gate edit.
