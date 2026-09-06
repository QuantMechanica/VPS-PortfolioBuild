---
source_id: AI-CODEX-XTIXNG-CS-LEADPERSIST-RV-20260906
title: XTI/XNG two-week common-shock relative-leader-persistence reversion
publisher: QuantMechanica governed extraction of peer-reviewed and government sources
source_type: peer_reviewed_plus_government_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-06_xtixng_common_shock_leader_persistence_reversion_source_approval.md
parent_source_ids:
  - FMR-MOMTS-2010
  - VILLAR-RAMBERG-OILGAS-2026
created: 2026-09-06
created_by: Research+Development
cards_extracted:
  - xtixng-cs-leadpersist-rv
---

# XTI/XNG Two-Week Common-Shock Leader-Persistence Reversion Source Packet

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
`decisions/2026-09-06_xtixng_common_shock_leader_persistence_reversion_source_approval.md`.

## Source Findings Used

Fuertes, Miffre, and Rallis test relative commodity return ranks at monthly
formation horizons. Villar/Joutz and Ramberg/Parsons document physical and
economic oil/gas links while showing that the relationship is weak,
time-varying, and disrupted by gas-specific shocks. The sources support a
falsifiable relative-return research question, but they do not test a
two-week same-leader state, a weekly CFD package, or the proposed reversal.
No source alpha, hedge ratio, frequency, cost, neutrality, or decorrelation
result transfers.

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
same relative winner must persist strictly across both weeks:

```text
(o0,g0 same strict sign) and (o1,g1 same strict sign) and d0*d1 > 0
d1 > 0 => SELL XTI, BUY XNG
d1 < 0 => BUY XTI, SELL XNG
otherwise => FLAT
```

Thus the package fades the newest relative winner only after two consecutive
common-direction energy moves preserve leadership. Zero, equality within
`1e-10`, a mixed-sign week, a leader switch, missing/nonconsecutive endpoints,
asynchronous bars, or invalid week membership consumes the week flat. No
current decision-week price enters the signal, and return magnitude never
scales risk.

The clock, three synchronized completed weeks, strict sign tests, strict
same-leader persistence, newest-winner fade, continuous-CFD carrier,
equal-notional target, aggregate `RISK_FIXED=1000` cap, independent
`3.5*ATR(20,D1)` hard stops, spread caps, durable consumed-attempt ledger,
next-week exit, and ten-day stale guard are fixed pre-result translations.
There is no fitted center, beta, z-score, optimization surface, external feed,
or fallback.

## Non-Duplicate Boundary

The canonical receipt covered 4,850 registry rows and 1,463 repository cards,
found no exact identity, and returned five expected fuzzy family matches. The
external Strategy Wiki root was unavailable and remains an explicit coverage
limit rather than being relabeled a complete-universe pass.

- `QM5_41369_xtixng-cs-leadpersist-cont` requires the identical formation
  state but follows the newest winner; this rule takes the opposite package.
- `QM5_41368_xtixng-cs-leadswitch-rv` requires a strict leadership switch;
  this rule requires unchanged strict leadership.
- `QM5_41361_xtixng-commonshock-rv` fades a winner after only one common-sign
  completed week.
- `QM5_41365_xtixng-decouple-rv` requires opposite individual-leg signs
  inside the completed week.
- `QM5_41367_xtixng-commonshock-cont` follows a winner after one common-sign
  completed week.
- `QM5_12567_cum-rsi2-commodity` is a single-symbol, long-only, two-day XNG
  oscillator pullback and cannot open an offsetting energy package.

Verdict:
`DISTINCT_TWO_WEEK_COMMON_SHOCK_STRICT_SAME_LEADER_PERSISTENCE_REVERSION`.
This is an identity ruling, never an efficacy or decorrelation claim. Q09
receives no waiver.

## Reputable-Source Criteria

- R1 `PASS_WITH_TWO_WEEK_LEADER_PERSISTENCE_REVERSION_TRANSLATION_RISK`:
  complete peer-reviewed commodity relative-return evidence plus complete
  government and peer-reviewed oil/gas relationship evidence; adverse
  instability is retained and no efficacy transfers.
- R2 `PASS`: synchronized endpoints, consecutive-week membership, two strict
  common-sign states, strict same-leader persistence, newest-winner fade,
  durable attempt, aggregate risk, hard stops, and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 histories supply every market input.
- R4 `PASS`: native timestamps, logarithms, comparisons, ATR, quotes,
  positions, deals, and durable state only; no ML or banned signal.

## Kill And Safety Boundary

Q02 retires this identity on zero packages, fewer than five completed logical
packages in any full post-warm-up year, or nonpositive governed economics. No
failed result may be rescued by changing carrier, horizon, common-sign state,
same-leader condition, direction, risk, stop, or lifecycle.

Authorized scope is one card, deterministic allocation, one branch-only
non-live V5 build, reference tests, strict Q01, and one paced target-only Q02
enqueue below the CPU ceiling. It excludes manual tester runs, optimization,
portfolio-gate edits, portfolio admission, deployment, live manifests,
`T_Live`, AutoTrading, and live use.
