---
source_id: AI-CODEX-XTIXNG-WRELVOTE-FLIP-CONT-20260906
title: XTI/XNG overlapping three-week relative-vote flip continuation
publisher: QuantMechanica governed extraction of peer-reviewed and government sources
source_type: peer_reviewed_plus_government_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-06_xtixng_weekly_relative_vote_flip_continuation_source_approval.md
parent_source_ids:
  - FMR-MOMTS-2010
  - VILLAR-RAMBERG-OILGAS-2026
parent_sha256:
  FMR-MOMTS-2010: 1F4F4977B0D9646A8BF56543D1881CCBC1513D4644DE72C350614580F3FF7417
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
created: 2026-09-06
created_by: Research+Development
cards_extracted:
  - xtixng-wrelvote-flip-cont
---

# XTI/XNG Overlapping Three-Week Relative-Vote Flip Continuation

## Approved Sources Of Record

This bounded extraction uses two governed packets read completely before the
durable source approval:

- `strategy-seeds/sources/FMR-MOMTS-2010/source.md`, covering Fuertes,
  Miffre, and Rallis (2010), “Tactical Allocation in Commodity Futures
  Markets: Combining Momentum and Term Structure Signals,” *Journal of
  Banking & Finance* 34(10), DOI `10.1016/j.jbankfin.2010.04.009`; and
- `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, covering
  Villar and Joutz (2006), U.S. Energy Information Administration, and
  Ramberg and Parsons (2012), “The Weak Tie Between Natural Gas and Oil
  Prices,” *The Energy Journal* 33(2), DOI
  `10.5547/01956574.33.2.2`.

## Source Findings And Claim Boundary

Fuertes, Miffre, and Rallis test continuation in return-ranked commodity
winner/loser portfolios. Villar/Joutz and Ramberg/Parsons document physical
and economic oil/gas links while showing that the relationship is weak,
time-varying, and disrupted by gas-specific shocks. These sources support a
falsifiable relative-return continuation question. They do not test this
weekly CFD pair, overlapping majority windows, a majority-flip event, equal
notional, or the stated lifecycle. No alpha, hedge ratio, frequency, cost,
neutrality, or correlation result transfers.

## Bounded QM Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of a new Monday-anchored broker
week, align the final synchronized XTI/XNG closes of the five immediately
preceding consecutive completed weeks. Each week must contain three to five
synchronized sessions. From oldest endpoint `C[0]` to newest `C[4]`, define
four adjacent relative log returns:

```text
d[i] = ln(XTI[i+1] / XTI[i]) - ln(XNG[i+1] / XNG[i]), i=0..3
old_vote = sign(d0) + sign(d1) + sign(d2)
new_vote = sign(d1) + sign(d2) + sign(d3)
```

Every `abs(d[i])` must exceed `1e-10`. A signal exists only when the two
strict three-observation majorities reverse sign:

```text
old_vote < 0 and new_vote > 0 => BUY XTI, SELL XNG
old_vote > 0 and new_vote < 0 => SELL XTI, BUY XNG
otherwise => FLAT
```

The package therefore follows the newly established relative winner only on
the first rolling three-week vote transition. Zero/equality, no flip,
missing/nonconsecutive endpoints, asynchronous bars, invalid week membership,
or late attachment consumes the week flat. No current decision-week price
enters the signal, and return magnitude never scales risk.

The clock, five synchronized completed weeks, three-to-five-session bounds,
four strict relative-return signs, overlapping vote definitions, strict flip,
new-majority continuation, continuous-CFD carrier, equal-notional target,
aggregate `RISK_FIXED=1000` cap, independent `3.5*ATR(20,D1)` hard stops,
spread caps, durable consumed-attempt ledger, next-week exit, and ten-day
stale guard are fixed pre-result translations. There is no fitted center,
beta, z-score, optimization surface, external feed, or fallback.

## Non-Duplicate Boundary

The canonical receipt covered 4,852 registry rows and 1,465 repository cards,
found no exact identity, and returned five expected fuzzy family matches. The
external Strategy Wiki root was unavailable and remains an explicit coverage
limit.

- `QM5_41367_xtixng-commonshock-cont` uses one same-sign individual-return
  week and follows its relative winner.
- `QM5_41368` through `QM5_41371` use two consecutive common-sign weeks and
  distinguish relative-leader persistence/switch plus fade/continuation.
- This candidate does not require the two contracts to move in the same
  outright direction. It owns four adjacent relative returns and a reversal
  between two overlapping three-week strict sign majorities.
- Outright WTI/XNG trend, robust-statistic, calendar, event, price-ratio, OLS,
  and RSI sleeves consume different state objects and clocks.

Verdict:
`DISTINCT_OVERLAPPING_THREE_WEEK_RELATIVE_MAJORITY_FLIP_CONTINUATION`.
This is an identity ruling, never an efficacy or decorrelation claim.

## Reputable-Source Criteria

- R1 `PASS_WITH_RELATIVE_VOTE_FLIP_TRANSLATION_RISK`: complete peer-reviewed
  commodity relative-return evidence plus complete government and peer-
  reviewed oil/gas relationship evidence; adverse instability is retained.
- R2 `PASS`: endpoints, week membership, four strict relative signs, both
  overlapping votes, strict flip, direction, attempt, aggregate risk, hard
  stops, and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 histories supply every market input.
- R4 `PASS`: native timestamps, logarithms, comparisons, ATR, positions, and
  durable state only; no ML or banned signal.

## Kill And Safety Boundary

Q02 retires this identity on zero packages, fewer than five completed logical
packages in any full post-warm-up year, or nonpositive governed economics. No
failed result may be rescued by changing carrier, weekly endpoints, vote
window, overlap, flip rule, direction, risk, stop, or lifecycle.

Authorized scope is one card, deterministic allocation, one branch-only
non-live V5 build, reference tests, strict Q01, and one paced target-only Q02
enqueue below the CPU ceiling. It excludes manual tester runs, optimization,
portfolio-gate edits, portfolio admission, deployment, live manifests,
`T_Live`, AutoTrading, and live use.

