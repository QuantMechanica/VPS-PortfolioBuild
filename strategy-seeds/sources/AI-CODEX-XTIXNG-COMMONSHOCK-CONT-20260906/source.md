---
source_id: AI-CODEX-XTIXNG-COMMONSHOCK-CONT-20260906
title: XTI/XNG completed-week common-shock relative continuation
publisher: QuantMechanica governed extraction of peer-reviewed and government sources
source_type: peer_reviewed_plus_government_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-06_xtixng_weekly_common_shock_continuation_source_approval.md
parent_source_ids:
  - FMR-MOMTS-2010
  - VILLAR-RAMBERG-OILGAS-2026
parent_sha256:
  FMR-MOMTS-2010: 1F4F4977B0D9646A8BF56543D1881CCBC1513D4644DE72C350614580F3FF7417
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
created: 2026-09-06
created_by: Research+Development
cards_extracted:
  - xtixng-commonshock-cont
---

# XTI/XNG Completed-Week Common-Shock Relative Continuation Source Packet

## Approved Sources Of Record

This bounded extraction uses two governed packets read completely before
durable source approval:

- `strategy-seeds/sources/FMR-MOMTS-2010/source.md`, covering Fuertes,
  Miffre, and Rallis (2010), "Tactical Allocation in Commodity Futures
  Markets: Combining Momentum and Term Structure Signals," *Journal of
  Banking & Finance* 34(10), DOI `10.1016/j.jbankfin.2010.04.009`; and
- `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, covering
  Villar and Joutz (2006), U.S. Energy Information Administration, and
  Ramberg and Parsons (2012), "The Weak Tie Between Natural Gas and Oil
  Prices," *The Energy Journal* 33(2), DOI
  `10.5547/01956574.33.2.2`.

The durable approval preceding card extraction is
`decisions/2026-09-06_xtixng_weekly_common_shock_continuation_source_approval.md`.

## Source Findings Used

Fuertes, Miffre, and Rallis test cross-sectional momentum in a broad
commodity-futures universe that includes crude oil and natural gas: rank past
returns, buy winners, short losers, and hold the relative portfolio. Their
tested formation and holding horizons are monthly, not weekly, and their
cross-section is much wider than two instruments.

Villar/Joutz and Ramberg/Parsons document physical and economic oil/gas links
through substitution, co-production, drilling, finance, transport, and LNG,
while making the weak, time-varying relationship and gas-specific shocks
binding adverse evidence. These sources do not test a two-asset weekly
Darwinex CFD package conditioned on both legs sharing a sign. No source alpha,
neutrality, density, cost, drawdown, or correlation result transfers.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of a new Monday-anchored broker week,
align the final synchronized closes of the immediately completed week and its
consecutive parent week. Each week must contain three to five synchronized
sessions. Define:

```text
o = ln(XTI_newest_week_final / XTI_parent_week_final)
g = ln(XNG_newest_week_final / XNG_parent_week_final)

o > 0 and g > 0 and o > g => BUY XTI, SELL XNG
o > 0 and g > 0 and o < g => SELL XTI, BUY XNG
o < 0 and g < 0 and o > g => BUY XTI, SELL XNG
o < 0 and g < 0 and o < g => SELL XTI, BUY XNG
otherwise                  => FLAT
```

Both contracts must share one strict weekly direction. The package then buys
the strict relative winner and shorts the loser for the next broker week.
Equality within `1e-10`, zero, opposite signs, missing/nonconsecutive
endpoints, asynchronous bars, or invalid week membership consumes the week
flat. No current decision-week price enters the signal, and return magnitude
never changes risk.

The weekly clock, common-sign admission state, two-asset cross-section,
zero/equality deadband, continuous-CFD carrier, equal-notional target,
aggregate `RISK_FIXED=1000` cap, independent `3.5*ATR(20,D1)` hard stops,
spread caps, consumed-attempt ledger, next-week exit, and ten-day stale guard
are fixed pre-result QM translations. There is no fitted center, beta,
z-score, optimization surface, external feed, or fallback signal.

## Non-Duplicate Boundary

The canonical receipt covered 4,847 registry rows and 1,460 repository cards,
found no exact identity, and returned six expected fuzzy family matches. The
external Strategy Wiki root was unavailable and remains explicit rather than
being relabeled as a complete-universe pass.

- `QM5_41361_xtixng-commonshock-rv` uses the identical one-week common-sign
  state but sells the relative winner and buys the loser. This identity makes
  both package sides opposite by following cross-sectional momentum.
- `QM5_41086_xauxag-commonshock-rv` owns the reversion arithmetic on the
  precious-metals carrier, not the energy carrier or continuation direction.
- `QM5_41366_xtixng-decouple-cont` requires the individual weekly returns to
  have opposite signs. The proposed state is disjoint because it requires the
  same strict sign.
- `QM5_41362_xtixng-wdecel-cont` requires two adjacent same-sign oil/gas ratio
  returns and a smaller newest magnitude. This rule uses one individual return
  per leg and no multiweek ratio path.
- `QM5_12733_xti-xng-xmom` ranks 126 D1 observations at a monthly boundary
  with a configurable return-difference band. This rule uses exactly one
  completed broker week, zero deadband, and a fixed next-week exit.
- `QM5_41340_wti-xng-divtrend` trades WTI only and uses XNG as a veto;
  `QM5_12567_cum-rsi2-commodity` is a single-symbol long-only oscillator.

Verdict:
`DISTINCT_WEEKLY_SAME_SIGN_XTI_XNG_WINNER_LONG_LOSER_SHORT_CONTINUATION`.
This is an identity ruling, never an efficacy or decorrelation claim. Q09
receives no waiver.

## Reputable-Source Criteria

- R1 `PASS_WITH_WEEKLY_TWO_ASSET_TRANSLATION_RISK`: complete peer-reviewed
  commodity cross-sectional momentum evidence plus complete government and
  peer-reviewed oil/gas relationship evidence; adverse instability is kept
  and no efficacy transfers.
- R2 `PASS`: synchronized endpoints, week membership, strict same signs,
  strict relative rank, continuation sides, durable attempt, aggregate risk,
  hard stops, and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 history supplies every market input.
- R4 `PASS`: native timestamps, logarithms, comparisons, ATR, quotes,
  positions, deals, and durable state only; no ML or banned signal.

## Kill And Safety Boundary

Q02 retires this identity on zero packages, fewer than five completed logical
packages in any full post-warm-up year, or nonpositive governed economics. No
failed result may be rescued by changing carrier, horizon, sign state,
direction, risk, stop, or lifecycle.

Authorized scope is one card, deterministic allocation, one branch-only
non-live V5 build, reference tests, strict Q01, and one paced target-only Q02
enqueue below the CPU ceiling. It excludes manual tester runs, optimization,
portfolio-gate edits, portfolio admission, deployment, live manifests,
`T_Live`, AutoTrading, and live use.
