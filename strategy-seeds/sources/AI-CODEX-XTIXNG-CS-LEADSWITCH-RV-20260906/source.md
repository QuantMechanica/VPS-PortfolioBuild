---
source_id: AI-CODEX-XTIXNG-CS-LEADSWITCH-RV-20260906
title: XTI/XNG two-week common-shock relative-leader-switch reversion
publisher: QuantMechanica governed extraction of peer-reviewed and government sources
source_type: peer_reviewed_plus_government_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-06_xtixng_common_shock_leader_switch_reversion_source_approval.md
parent_source_ids:
  - FMR-MOMTS-2010
  - VILLAR-RAMBERG-OILGAS-2026
parent_sha256:
  FMR-MOMTS-2010: 1F4F4977B0D9646A8BF56543D1881CCBC1513D4644DE72C350614580F3FF7417
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
created: 2026-09-06
created_by: Research+Development
cards_extracted:
  - xtixng-cs-leadswitch-rv
---

# XTI/XNG Two-Week Common-Shock Leader-Switch Reversion Source Packet

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
`decisions/2026-09-06_xtixng_common_shock_leader_switch_reversion_source_approval.md`.

## Source Findings Used

Fuertes, Miffre, and Rallis test return-ranked commodity winner/loser
portfolios at monthly formation horizons. Villar/Joutz and Ramberg/Parsons
document physical and economic oil/gas links while showing that the
relationship is weak, time-varying, and disrupted by gas-specific shocks.
The sources support a falsifiable relative-value research question, but they
do not test a two-week leader-switch rule, a weekly CFD package, or this
reversion direction. No source alpha, hedge ratio, frequency, cost,
neutrality, or decorrelation result transfers.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of a new Monday-anchored broker
week, align the final synchronized closes of the three immediately preceding
consecutive weeks. Each week must contain three to five synchronized sessions.
Define the older and newer individual weekly log returns:

```text
o0 = ln(XTI_middle_week_final / XTI_oldest_week_final)
g0 = ln(XNG_middle_week_final / XNG_oldest_week_final)
o1 = ln(XTI_newest_week_final / XTI_middle_week_final)
g1 = ln(XNG_newest_week_final / XNG_middle_week_final)
d0 = o0 - g0
d1 = o1 - g1
```

Both legs must share one strict direction within each completed week and the
relative winner must switch strictly between weeks:

```text
(o0,g0 same strict sign) and (o1,g1 same strict sign) and d0*d1 < 0
d1 > 0 => SELL XTI, BUY XNG
d1 < 0 => BUY XTI, SELL XNG
otherwise => FLAT
```

Thus the package fades the newest relative winner only after two consecutive
common-direction energy moves rotate leadership. Zero, equality within
`1e-10`, a mixed-sign week, missing/nonconsecutive endpoints, asynchronous
bars, or invalid week membership consumes the week flat. No current
decision-week price enters the signal, and return magnitude never scales
risk.

The clock, three synchronized completed weeks, strict sign tests, strict
leader switch, newest-winner fade, continuous-CFD carrier, equal-notional
target, aggregate `RISK_FIXED=1000` cap, independent `3.5*ATR(20,D1)` hard
stops, spread caps, durable consumed-attempt ledger, next-week exit, and
ten-day stale guard are fixed pre-result translations. There is no fitted
center, beta, z-score, optimization surface, external feed, or fallback.

## Non-Duplicate Boundary

The canonical receipt covered 4,848 registry rows and 1,461 repository cards,
found no exact identity, and returned three expected fuzzy family matches.
The external Strategy Wiki root was unavailable and remains an explicit
coverage limit rather than being relabeled a complete-universe pass.

- `QM5_41361_xtixng-commonshock-rv` fades the relative winner after one
  common-sign completed week. This candidate additionally requires the
  immediately prior week to be common-sign and its strict relative winner to
  be the opposite contract.
- `QM5_41367_xtixng-commonshock-cont` uses one common-sign week and follows
  its relative winner. This candidate uses three endpoints, two common-sign
  weeks, a strict leader rotation, and fades the newest winner.
- `QM5_41365_xtixng-decouple-rv` requires opposite signs inside one completed
  week. This candidate requires same signs inside both completed weeks.
- `QM5_41358_xtixng-wovershoot-rv` and `QM5_41360_xtixng-wretr-rv` classify
  two opposite-sign ratio returns by relative magnitude. This candidate does
  not compare magnitudes and instead requires same-sign individual energy
  returns in both weeks before admitting the leader switch.
- `QM5_12567_cum-rsi2-commodity` is a single-symbol, long-only, two-day XNG
  oscillator pullback and cannot open an offsetting energy package.

Verdict:
`DISTINCT_TWO_WEEK_COMMON_SHOCK_STRICT_LEADER_SWITCH_NEWEST_WINNER_FADE`.
This is an identity ruling, never an efficacy or decorrelation claim. Q09
receives no waiver.

## Reputable-Source Criteria

- R1 `PASS_WITH_TWO_WEEK_LEADER_SWITCH_TRANSLATION_RISK`: complete
  peer-reviewed commodity relative-return evidence plus complete government
  and peer-reviewed oil/gas relationship evidence; adverse instability is
  retained and no efficacy transfers.
- R2 `PASS`: synchronized endpoints, consecutive-week membership, two strict
  common-sign states, strict leader rotation, newest-winner fade, durable
  attempt, aggregate risk, hard stops, and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 histories supply every market input.
- R4 `PASS`: native timestamps, logarithms, comparisons, ATR, quotes,
  positions, deals, and durable state only; no ML or banned signal.

## Kill And Safety Boundary

Q02 retires this identity on zero packages, fewer than five completed logical
packages in any full post-warm-up year, or nonpositive governed economics. No
failed result may be rescued by changing carrier, horizon, common-sign state,
leader-switch condition, direction, risk, stop, or lifecycle.

Authorized scope is one card, deterministic allocation, one branch-only
non-live V5 build, reference tests, strict Q01, and one paced target-only Q02
enqueue below the CPU ceiling. It excludes manual tester runs, optimization,
portfolio-gate edits, portfolio admission, deployment, live manifests,
`T_Live`, AutoTrading, and live use.
