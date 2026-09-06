---
source_id: AI-CODEX-XTIXNG-DECOUPLE-CONT-20260906
title: XTI/XNG completed-week decoupling continuation
publisher: QuantMechanica governed extraction of peer-reviewed and government sources
source_type: peer_reviewed_plus_government_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-06_xtixng_weekly_decoupling_continuation_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
  - VILLAR-RAMBERG-OILGAS-2026
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
created: 2026-09-06
created_by: Research+Development
cards_extracted:
  - xtixng-decouple-cont
---

# XTI/XNG Completed-Week Decoupling Continuation Source Packet

## Approved Sources Of Record

This bounded extraction uses two completely read governed packets:

- `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, covering Moskowitz,
  Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of Financial
  Economics* 104(2), DOI `10.1016/j.jfineco.2011.11.003`; and
- `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, covering
  Villar and Joutz (2006), U.S. Energy Information Administration, and
  Ramberg and Parsons (2012), "The Weak Tie Between Natural Gas and Oil
  Prices," *The Energy Journal* 33(2), DOI `10.5547/01956574.33.2.2`.

The durable approval preceding card extraction is
`decisions/2026-09-06_xtixng_weekly_decoupling_continuation_source_approval.md`.

## Source Findings Used

Moskowitz, Ooi, and Pedersen document return-sign continuation across liquid
futures, include both WTI and natural gas in the commodity universe, and
explicitly test one-month formation and one-month holding. Villar/Joutz and
Ramberg/Parsons document physical and economic oil/gas links through
substitution, co-production, drilling, finance, transport, and LNG, while
showing that the tie is weak, time varying, and dominated at times by
gas-specific shocks.

No source tests a two-asset weekly Darwinex CFD package conditioned on strict
opposite return signs. The weekly clock, decoupling condition, winner-minus-
loser direction, equal-notional target, fixed risk, and lifecycle below are a
falsifiable QM synthesis. No source alpha, neutrality, trade count, cost,
drawdown, or correlation claim transfers.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of a new Monday-anchored broker week,
align the final synchronized closes of the immediately completed week and its
consecutive parent week. Require three to five synchronized sessions in each
week. Define:

```text
o = ln(XTI_newest_week_final / XTI_parent_week_final)
g = ln(XNG_newest_week_final / XNG_parent_week_final)

o > 0 and g < 0 => BUY XTI, SELL XNG
o < 0 and g > 0 => SELL XTI, BUY XNG
otherwise       => FLAT
```

Thus the package follows the completed-week winner and shorts the loser only
when the energy legs strictly decouple in direction. Zero, same signs,
missing or nonconsecutive endpoints, asynchronous bars, invalid prices, or an
invalid session count consumes the week flat. No current decision-week price
enters the signal, and magnitude never changes side or risk.

The carrier, normalized week boundary, session bounds, zero deadband,
equal-notional target, aggregate `RISK_FIXED=1000` cap, independent frozen
`3.5*ATR(20,D1)` stops, spread caps, consumed-attempt ledger, next-week exit,
and ten-day stale guard are fixed before results. There is no fitted center,
beta, z-score, optimization surface, fallback signal, or same-week retry.

## Non-Duplicate Boundary

The canonical receipt covered 4,846 registry rows and 1,459 repository cards.
It returned the expected fuzzy siblings `QM5_41365` and `QM5_41362`; the
external Strategy Wiki root was unavailable and remains an explicit scope
limitation accepted only by the current direct OWNER mission.

- `QM5_41365_xtixng-decouple-rv` uses the identical one-week decoupling state
  but reverses both moves: it buys the loser and sells the winner. This card
  follows both moves, so every admitted package has the opposite two sides.
- `QM5_41362_xtixng-wdecel-cont` requires two adjacent same-sign oil/gas-ratio
  returns and a smaller newest magnitude. This card uses one individual
  return per leg and requires strict cross-leg sign disagreement.
- `QM5_12733_xti-xng-xmom` ranks 126 D1 returns at a monthly boundary with a
  configurable two-percent return-difference band. This card uses exactly
  one completed broker week, strict individual signs, zero deadband, and a
  fixed next-week exit.
- `QM5_41340_wti-xng-divtrend` orders only WTI from twelve-month direction and
  uses XNG as a read-only veto; it is not a two-leg weekly package.
- `QM5_12567_cum-rsi2-commodity` is single-symbol, long-only, and oscillator
  driven.

Verdict:
`DISTINCT_WEEKLY_OPPOSITE_SIGN_XTI_XNG_WINNER_LONG_LOSER_SHORT_CONTINUATION`.
This is an identity ruling, never an efficacy or decorrelation claim. Q09
receives no waiver.

## Reputable-Source Criteria

- R1 `PASS_WITH_WEEKLY_CROSS_SECTIONAL_TRANSLATION_RISK`: complete peer-
  reviewed momentum evidence plus complete government and peer-reviewed
  oil/gas relationship evidence; no weekly-pair efficacy transfers.
- R2 `PASS`: chronology, sessions, strict signs, continuation side, weekly
  attempt, aggregate risk, stops, and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 history supplies every market input.
- R4 `PASS`: deterministic native arithmetic and execution state only; no ML,
  external runtime feed, grid, martingale, pyramid, or banned indicator.

## Kill And Safety Boundary

Q02 retires this identity on zero packages, below five completed logical
packages in any full post-warm-up year, or nonpositive governed economics.
No failed result may be rescued by changing carrier, horizon, sign state,
direction, risk, stop, or lifecycle.

Authorized scope is one card, deterministic allocation, one branch-only
non-live V5 build, reference tests, strict Q01, and one paced Q02 enqueue below
the CPU ceiling. It excludes manual tester runs, optimization, portfolio-gate
edits, portfolio admission, deployment, live manifests, `T_Live`,
AutoTrading, and live use.
