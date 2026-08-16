# QM5_41031 XAU/XAG Asymmetric Gold-Lead Catch-Up G0 Authorization

Date: 2026-08-16

Decision: `APPROVED` for one branch-only V5 build, strict Q01 validation, one
locked logical-basket `RISK_FIXED` backtest setfile, and one paced non-live Q02
enqueue if CPU capacity permits. This is not live, portfolio, or
manual-tester authority.

## Identity

- EA: `QM5_41031_xauxag-goldlead`
- strategy ID: `KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026_S01`
- approved source: `KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41031_xauxag-goldlead_card.md`
- logical basket: `QM5_41031_XAU_XAG_GOLDLEAD_D1`
- host/traded slot 0: `XAUUSD.DWX`, D1, planned magic `410310000`
- companion/traded slot 1: `XAGUSD.DWX`, D1, planned magic `410310001`
- risk: one package `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

The atomic registry allocator assigned `QM5_41031` at commit `af21130fe`.
No ID was inferred or appended by hand.

## Source And Hypothesis Review

The OWNER-authorized source decision is
`decisions/2026-08-16_xauxag_gold_lead_lag_source_approval.md` at commit
`f4aa2f4c7`. The bounded canonical packet preserves complete-read daily
gold-to-silver predictive-ordering evidence from Krawiec and Gorska (2015),
adverse state-dependence evidence from Schweikert (2018), and CME's governed
gold/silver intermarket-carrier material.

The approved hypothesis is narrower and untested by those sources. On one
synchronized completed D1 return, detect a gold move of at least 75 basis
points whose silver response remains less than one-half in gold's direction
and no larger in absolute value. Trade silver toward gold and hedge with the
opposite XAU leg, then flatten both at the first next D1 boundary. Coefficient
direction, thresholds, equal-notional sizing, attachment grace, fixed risk,
hard stops, spread caps, attempt state, and repair behavior are QM
translations. No source performance, density, neutrality, decorrelation, or
portfolio result transfers.

## G0 Gates

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: complete-read academic daily
  causality plus peer-reviewed/exchange carrier evidence; the absent
  coefficient sign and untested trade rule are disclosed.
- R2 `PASS`: synchronized completed endpoints, asymmetric direction,
  thresholds, timing, retry, package sizing, stops, spreads, paired exit, and
  stale repair are deterministic and frozen.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 history plus native MT5 state provide every runtime input.
- R4 `PASS`: no trained output, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, pyramid, or random path.

## Locked Execution Contract

1. Run only from `XAUUSD.DWX`, D1, EA ID 41031, slot 0, with XAG in slot 1.
2. Require the current XAU and XAG D1 timestamps to match, current host date
   to equal broker date, and attachment within 180 minutes of host D1 open.
3. Persist the broker-date attempt before every fallible entry gate. Never
   retry or backfill that date.
4. Require two immediately completed, exactly synchronized positive close
   pairs and compute only
   `g=ln(XAU_close[1]/XAU_close[2])` and
   `s=ln(XAG_close[1]/XAG_close[2])`.
5. If `g>=0.0075`, `s<0.5*g`, and `abs(s)<=abs(g)`, SELL XAU/BUY XAG. If
   `g<=-0.0075`, `s>0.5*g`, and `abs(s)<=abs(g)`, BUY XAU/SELL XAG. Every
   other state consumes the date flat. Silver never leads gold.
6. Size one opposite-leg equal-notional package, round down, reject more than
   20% mismatch, and keep combined stop loss at or below one
   `RISK_FIXED=1000` budget. Use frozen `3.0*ATR(20,D1)` stops and 1,500-point
   spread ceilings, with no target.
7. Roll back a surviving leg after any partial open. Never retry, scale in,
   pyramid, grid, martingale, or treat a leg as standalone.
8. Close both legs at the first subsequent XAU D1 boundary. Keep framework
   Friday 21 close and a three-calendar-day stale repair guard.
9. Repair malformed, orphaned, duplicated, same-side, wrong-side, or
   over-mismatch exposure before entry-only filters.
10. Keep both news axes OFF and use native MT5 data/state only.

## Non-Duplicate And Portfolio Boundary

The canonical checker scanned 4,518 registry rows and 614 root cards and
found no exact or fuzzy identity. Manual review separated relative-level and
fitted-residual systems, the five-return run fade, multiweek memory systems,
monthly momentum/higher-moment/calendar systems, the weekly close/open flow
divergence basket, and the existing commodity oscillator. The locked identity
is gold-only completed-return leadership, fixed shock floor, bounded silver
under-response, equal-notional opposite legs, and first-next-D1 flattening.

This establishes mechanic and carrier novelty only. It does not establish
profitability, neutrality, low correlation, certification, or admission to
the book. Q02 owns density and governed economics. Q09 alone owns realized
correlation with XAU/SP500/NDX/XNG.

## Authorization Boundary

Authorized now:

- finalize and synchronize the two approved card copies;
- create the EA directory before magic allocation;
- allocate slot-0 and slot-1 magic rows through the deterministic registry;
- implement one V5 EA and one logical-basket manifest;
- create one logical D1 backtest setfile with `RISK_FIXED=1000` and
  `RISK_PERCENT=0`;
- run deterministic reference tests, card lint, manifest validation, strict
  compile/build checks, and static Q01 validation; and
- enqueue exactly one paced Q02 logical-basket work item if the factory CPU
  ceiling is not binding.

Not authorized:

- manual tester launch or dispatcher control;
- live, demo, shadow, stress, or optimization presets;
- AutoTrading, `T_Live`, deploy manifests, or T_Live manifests;
- portfolio-gate changes, portfolio admission, neutrality claims, or
  correlation waivers; or
- after-result parameter, direction, carrier, threshold, or lifecycle changes.

Expected cadence is approximately ten to thirty completed packages per full
post-warm-up year. Q02 must retire below five/year or on zero trades,
nonpositive governed economics, wrong endpoints/direction/sides, current-bar
leakage, late/repeated entry, excess notional mismatch, orphan survival,
wrong lifecycle, nondeterminism, or invalid risk mode. If the backtest CPU
ceiling is binding, record the stop and do not enqueue or launch a manual
test.
