---
source_id: AI-CODEX-XTIXNG-WOVERSHOOT-RV-20260906
title: XTI/XNG completed-week reversal-overshoot reversion
publisher: QuantMechanica governed extraction of government and peer-reviewed sources
source_type: government_plus_peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-06_xtixng_weekly_reversal_overshoot_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
  - SCHWEIKERT-CME-XAUXAG-WOVERSHOOT-RV-2026
parent_sha256:
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
  SCHWEIKERT-CME-XAUXAG-WOVERSHOOT-RV-2026: 22760910E18D65172D1BED822E90E4629E820078FAC06CBC88CA1D7DBAEF82C5
created: 2026-09-06
created_by: Research+Development
cards_extracted:
  - xtixng-wovershoot-rv
---

# XTI/XNG Completed-Week Reversal-Overshoot Reversion Source Packet

## Approved Source Of Record

This bounded extraction joins two complete governed repository packets read
before the durable source approval:

1. `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, covering
   Villar and Joutz (2006), *The Relationship Between Crude Oil and Natural
   Gas Prices*, U.S. Energy Information Administration, and Ramberg and
   Parsons (2012), "The Weak Tie Between Natural Gas and Oil Prices," *The
   Energy Journal* 33(2), 13-35, DOI `10.5547/01956574.33.2.2`.
2. `strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WOVERSHOOT-RV-2026/source.md`,
   used only for the already governed exact two-return reversal-overshoot
   arithmetic and lifecycle. Its precious-metals economic claims do not
   transfer to this energy carrier.

The durable OWNER approval is
`decisions/2026-09-06_xtixng_weekly_reversal_overshoot_source_approval.md`.

## Source Findings Used

Villar/Joutz and Ramberg/Parsons document physical and economic oil/gas links
through substitution, co-production, drilling, finance, transport, and LNG.
They also make instability, gas-specific variation, and a weak rather than
fixed tie binding adverse evidence. EIA's governed modern context reports
that oil and gas returns can be weakly correlated because gas remains more
regional and exposed to distinct fundamentals.

These findings justify a falsifiable oil/gas relative-price state. They do not
establish that a dominant opposite-sign weekly move overshoots, that the
inverse package will converge, or that a Darwinex CFD package is neutral,
profitable, or uncorrelated to the certified book.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
align the three immediately preceding completed week-end closes for XTI and
XNG. For week-end index 1 newest through 3 oldest, define:

```text
s_i   = ln(XTI_close_i) - ln(XNG_close_i)
r_new = s_1 - s_2
r_old = s_2 - s_3
```

Require both returns finite and non-zero, `sign(r_new) != sign(r_old)`, and
`abs(r_new)>abs(r_old)`. A dominant positive newest reversal opens SELL XTI /
BUY XNG. A dominant negative newest reversal opens BUY XTI / SELL XNG. Close
at the first later Monday anchor or after ten calendar days.

The weekly horizon, exact endpoint reconstruction, two-return count, strict
sign opposition and newest-dominance conditions, inverse newest-return sides,
CFD carrier, equal-target-notional construction, aggregate fixed-risk cap,
ATR stops, spread caps, consumed-attempt ledger, next-week exit, and stale
guard are transparent QM choices. No source performance, coefficient,
threshold, density, CFD equivalence, neutrality, or correlation claim is
imported.

## Exact Event Contract

For positive finite synchronized completed week-end closes:

```text
s1 = ln(XTI_newest) - ln(XNG_newest)
s2 = ln(XTI_middle) - ln(XNG_middle)
s3 = ln(XTI_oldest) - ln(XNG_oldest)

r_new = s1 - s2
r_old = s2 - s3

r_old < 0 and r_new > 0 and abs(r_new) > abs(r_old)
    => SELL XTI, BUY XNG
r_old > 0 and r_new < 0 and abs(r_new) > abs(r_old)
    => BUY XTI, SELL XNG
otherwise
    => FLAT
```

Strict inequalities are load-bearing. Equality is flat. The two intervals
share only their boundary endpoint and do not overlap in return time. The
current decision week is excluded. There is no fitted center, regression,
threshold, standardization, channel, calendar direction, external series, or
prior-result gate.

## Non-Duplicate Boundary

The canonical pre-allocation receipt scanned 4,838 registry rows and 1,451
repository cards. It found no exact identity and four expected fuzzy family
matches; the unavailable optional Wiki root is explicit in the receipt.

- `QM5_41075_xauxag-wovershoot-rv` shares the event arithmetic but owns a
  precious-metals carrier supported by different economics. This candidate
  owns the oil/gas path, weak and time-varying energy linkage, energy contract
  metadata, and energy spread costs.
- `QM5_41357_xtixng-mwinsor2-rv` shares the carrier but consumes thirteen
  completed month ends and twelve ratio returns, replaces two observations per
  tail, and fades a Winsorized annual state. This candidate consumes exactly
  three week ends, requires a strict dominant sign reversal, and holds one
  week.
- `QM5_41340_wti-xng-divtrend` owns a single WTI leg and uses XNG only as a
  read-only annual divergence veto. This candidate owns two opposed legs and
  fades the newest weekly relative move.
- XTI/XNG ECM, slope, rank, change-point, weekday, and calendar baskets use
  different state objects, estimators, directions, or clocks.

Verdict:
`FUZZY_FAMILY_MATCHES_RESOLVED_DISTINCT_XTIXNG_TWO_ADJACENT_COMPLETED_WEEK_RELATIVE_RETURNS_STRICT_OPPOSITE_SIGN_NEWEST_DOMINANT_CONTRARIAN_BASKET`.
This is an identity verdict, not an efficacy or correlation claim.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_CARRIER_TRANSLATION_RISK`: complete U.S. government and
  peer-reviewed oil/gas relationship evidence, including adverse instability,
  plus governed exact arithmetic; no alpha claim transfers.
- R2 `PASS`: endpoints, chronology, state, strict comparisons, side, weekly
  attempt, aggregate risk, stops, and lifecycle are exact.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTIUSD.DWX and XNGUSD.DWX D1 histories supply every market input.
- R4 `PASS`: timestamps, logarithms, comparisons, ATR, quotes, positions,
  deals, and durable state only; no trained or external runtime input.

## Kill And Safety Boundary

Q02 retires the edge below five completed logical packages in any full
post-warm-up year or on nonpositive governed economics. Downstream gates alone
own robustness and realized book correlation. No failure may be rescued by
changing the horizon, state, direction, carrier, risk, stops, or retry rule.

Authorized scope is one card, deterministic allocation, one branch-only
non-live V5 build, reference tests, strict Q01, and one paced Q02 enqueue below
the CPU ceiling. No optimization, manual tester launch, portfolio-gate edit,
portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, or live use
is authorized.
