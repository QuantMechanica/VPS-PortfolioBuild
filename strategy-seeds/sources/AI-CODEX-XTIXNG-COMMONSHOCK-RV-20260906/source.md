---
source_id: AI-CODEX-XTIXNG-COMMONSHOCK-RV-20260906
title: XTI/XNG completed-week common-shock dispersion reversion
publisher: QuantMechanica governed extraction of government and peer-reviewed sources
source_type: government_plus_peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-06_xtixng_weekly_common_shock_dispersion_reversion_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
  - SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026
parent_sha256:
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
  SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026: 5C34043D75105301B5AC920F7AFCE17B7030530CEE30A7AF2B47EBA06E3CA2CB
created: 2026-09-06
created_by: Research+Development
cards_extracted:
  - xtixng-commonshock-rv
---

# XTI/XNG Completed-Week Common-Shock Dispersion Reversion Source Packet

## Approved Source Of Record

This bounded extraction joins two complete governed repository packets read
before durable source approval:

1. `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, covering
   Villar and Joutz (2006), *The Relationship Between Crude Oil and Natural
   Gas Prices*, U.S. Energy Information Administration, and Ramberg and
   Parsons (2012), "The Weak Tie Between Natural Gas and Oil Prices," *The
   Energy Journal* 33(2), 13-35, DOI `10.5547/01956574.33.2.2`.
2. `strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026/source.md`,
   used only for the already governed exact completed-week common-direction
   dispersion arithmetic and lifecycle. Its precious-metals economic claims
   do not transfer to this energy carrier.

The durable OWNER approval is
`decisions/2026-09-06_xtixng_weekly_common_shock_dispersion_reversion_source_approval.md`.

## Source Findings Used

Villar/Joutz and Ramberg/Parsons document physical and economic oil/gas links
through substitution, co-production, drilling, finance, transport, and LNG.
They also make instability, gas-specific variation, and a weak rather than
fixed tie binding adverse evidence. These findings justify a falsifiable
oil/gas relative-price state. They do not establish that same-direction weekly
returns identify a common shock, that relative dispersion will revert, or
that a Darwinex CFD package is neutral, profitable, or uncorrelated.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
align the final synchronized closes of the immediately completed week and its
consecutive parent week. Each week must contain three to five synchronized
sessions. Define:

```text
o = ln(XTI_newest_week_final / XTI_parent_week_final)
g = ln(XNG_newest_week_final / XNG_parent_week_final)

o > 0 and g > 0 and o > g => SELL XTI, BUY XNG
o > 0 and g > 0 and o < g => BUY XTI, SELL XNG
o < 0 and g < 0 and o > g => SELL XTI, BUY XNG
o < 0 and g < 0 and o < g => BUY XTI, SELL XNG
otherwise                  => FLAT
```

Thus both legs must share one strict weekly direction and the package fades
the strict relative outperformer. Equality within `1e-10`, zero, mixed signs,
missing or nonconsecutive endpoints, asynchronous bars, or an invalid week
consumes the decision week flat. No decision-week price enters the signal.

The clock, endpoints, session bounds, equality band, CFD carrier, equal-
notional target, aggregate fixed-risk cap, ATR stops, spread caps, consumed-
attempt ledger, one-week exit, and stale guard are pre-result QM choices. No
source alpha, frequency, drawdown, threshold, hedge ratio, CFD equivalence,
neutrality, or correlation statistic is imported.

## Non-Duplicate Boundary

The canonical receipt scanned 4,841 registry rows and 1,454 repository cards,
found no exact identity, and surfaced only the expected XAU/XAG arithmetic
parent. The unavailable optional Wiki root is explicit in the receipt.

- `QM5_41086_xauxag-commonshock-rv` shares the event arithmetic but owns a
  precious-metals carrier. This candidate owns the weak, time-varying oil/gas
  carrier, energy contract metadata, and energy spread costs.
- `QM5_41357_xtixng-mwinsor2-rv` uses twelve monthly ratio returns and fixed-
  tail Winsorization.
- `QM5_41358_xtixng-wovershoot-rv` and `QM5_41360_xtixng-wretr-rv` require two
  adjacent opposite-sign oil/gas ratio returns.
- `QM5_41359_xtixng-waccel-rv` requires two adjacent same-sign ratio returns
  with a strictly larger newest magnitude. This candidate uses one weekly
  return per individual leg and accepts either relative magnitude.
- `QM5_41340_wti-xng-divtrend` trades WTI only and uses XNG as a veto.

Verdict:
`FUZZY_CARRIER_PORT_RESOLVED_DISTINCT_XTIXNG_SAME_DIRECTION_WEEKLY_COMMON_SHOCK_RELATIVE_OUTPERFORMER_FADE_BASKET`.
This is an identity verdict, not an efficacy or correlation claim.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMMON_SHOCK_TRANSLATION_RISK`: complete U.S. government and
  peer-reviewed oil/gas evidence, including adverse instability, plus governed
  exact arithmetic; no alpha claim transfers.
- R2 `PASS`: endpoints, chronology, session bounds, strict comparisons, side,
  weekly attempt, aggregate risk, stops, and lifecycle are exact.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTIUSD.DWX and XNGUSD.DWX D1 histories supply every market input.
- R4 `PASS`: timestamps, logarithms, comparisons, ATR, quotes, positions,
  deals, and durable state only; no trained or external runtime input.

## Kill And Safety Boundary

Q02 retires the edge below five completed logical packages in any full post-
warm-up year, at zero trades, or on nonpositive governed economics. Downstream
gates alone own robustness and realized book correlation. No failure may be
rescued by changing carrier, state, direction, risk, stops, or lifecycle.

Authorized scope is one card, deterministic allocation, one branch-only non-
live V5 build, reference tests, strict Q01, and one paced Q02 enqueue below the
CPU ceiling. No optimization, manual tester launch, portfolio-gate edit,
portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, or live use
is authorized.
