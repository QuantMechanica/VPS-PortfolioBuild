---
source_id: AI-CODEX-XTIXNG-DECOUPLE-RV-20260906
title: XTI/XNG completed-week decoupling-shock reversion
publisher: QuantMechanica governed extraction of government and peer-reviewed sources
source_type: government_plus_peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-06_xtixng_weekly_decoupling_shock_reversion_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
parent_sha256:
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
created: 2026-09-06
created_by: Research+Development
cards_extracted:
  - xtixng-decouple-rv
---

# XTI/XNG Completed-Week Decoupling-Shock Reversion Source Packet

## Approved Source Of Record

This bounded extraction uses the completely read governed packet
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`. That record
covers Villar and Joutz (2006), *The Relationship Between Crude Oil and Natural
Gas Prices*, U.S. Energy Information Administration, and Ramberg and Parsons
(2012), "The Weak Tie Between Natural Gas and Oil Prices," *The Energy Journal*
33(2), 13-35, DOI `10.5547/01956574.33.2.2`.

The durable OWNER approval preceding card extraction is
`decisions/2026-09-06_xtixng_weekly_decoupling_shock_reversion_source_approval.md`.

## Source Findings Used

Villar/Joutz and Ramberg/Parsons document physical and economic oil/gas links
through substitution, co-production, drilling, finance, transport, and LNG.
They also show that the relationship is weak, shifts across regimes, and leaves
large gas-specific variation unexplained. The current extraction treats that
instability as adverse evidence and tests one transparent relative-price state.

No source establishes that opposite completed-week returns are temporary,
that both legs will reverse, or that an equal-notional CFD basket is neutral,
profitable, or uncorrelated. The signal below is a falsifiable QM translation,
not an econometric replication or inherited alpha claim.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of a new Monday-anchored broker week,
align the final synchronized closes of the immediately completed week and its
consecutive parent week. Require three to five synchronized sessions in each
week. Define:

```text
o = ln(XTI_newest_week_final / XTI_parent_week_final)
g = ln(XNG_newest_week_final / XNG_parent_week_final)

o > 0 and g < 0 => SELL XTI, BUY XNG
o < 0 and g > 0 => BUY XTI, SELL XNG
otherwise       => FLAT
```

Thus the package buys the completed-week loser and sells the winner only when
the two energy legs strictly decouple in direction. Zero, same signs, missing
or nonconsecutive endpoints, asynchronous bars, invalid prices, or an invalid
session count consumes the week flat. No current decision-week price enters
the signal and magnitude never changes side or risk.

The clock, endpoint selection, session bounds, CFD carrier, equal-notional
target, aggregate `RISK_FIXED=1000` cap, independent frozen ATR stops, spread
caps, consumed-attempt ledger, one-week exit, and stale guard are fixed before
results. There is no fitted center, beta, z-score, optimization surface,
fallback signal, or same-week retry.

## Non-Duplicate Boundary

The canonical receipt covered 4,845 registry rows and 1,458 repository cards,
with no exact or above-threshold fuzzy match. Its external Strategy Wiki scope
was unavailable and remains an explicit coverage limitation accepted only by
the current direct OWNER mission.

- `QM5_41361_xtixng-commonshock-rv` requires same-sign individual weekly
  returns and fades the relative outperformer. This extraction requires strict
  opposite signs and fades both completed moves.
- `QM5_12840_xti-xng-rspread` uses a configurable return lookback, rolling
  z-score, beta, and mean exit. This extraction uses one exact completed broker
  week, no fitted center, and a fixed next-week exit.
- `QM5_41358` and `QM5_41360` consume two adjacent weekly returns of the
  XTI/XNG ratio. This extraction consumes one weekly return per individual leg.
- Monthly cross-sectional reversal cards consume different horizons, clocks,
  state objects, and lifecycles.
- `QM5_12567_cum-rsi2-commodity` is single-symbol, long-only, and oscillator
  driven.

Verdict:
`REPOSITORY_SCOPES_CLEAN_DISTINCT_XTIXNG_OPPOSITE_DIRECTION_WEEKLY_DECOUPLING_LOSER_LONG_WINNER_SHORT_BASKET`.
This is an identity ruling, never an efficacy or portfolio-correlation claim.

## Reputable-Source Criteria

- R1 `PASS_WITH_DECOUPLING_TRANSLATION_RISK`: complete government and
  peer-reviewed oil/gas evidence with instability retained; no alpha transfers.
- R2 `PASS`: chronology, session bounds, strict signs, side, weekly attempt,
  aggregate risk, stops, and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 history supplies every price input.
- R4 `PASS`: deterministic native arithmetic and execution state only; no ML,
  external runtime feed, grid, martingale, pyramid, or banned indicator.

## Kill And Safety Boundary

Q02 retires this identity below five completed logical packages in any full
post-warm-up year, on zero packages, or on nonpositive governed economics.
Downstream gates alone own robustness and realized correlation. No failed
result may be rescued by changing carrier, sign state, direction, risk, stop,
or lifecycle.

Authorized scope is one card, deterministic allocation, one branch-only
non-live V5 build, reference tests, strict Q01, and one paced Q02 enqueue below
the CPU ceiling. No manual tester launch, optimization, portfolio-gate edit,
portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, or live use
is authorized.
