# QM5_41030 XAU/XAG Weekly Relative-Flow Divergence G0 Authorization

Date: 2026-08-16

Decision: `APPROVED` for one branch-only V5 build, strict Q01 validation, one
locked logical-basket `RISK_FIXED` backtest setfile, and one paced non-live Q02
enqueue. This is not live, portfolio, or manual-tester authority.

## Identity

- EA: `QM5_41030_xauxag-flowdiv`
- strategy ID: `WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026_S01`
- approved source: `WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41030_xauxag-flowdiv_card.md`
- logical basket: `QM5_41030_XAU_XAG_FLOWDIV_D1`
- host/traded slot 0: `XAUUSD.DWX`, D1, planned magic `410300000`
- companion/traded slot 1: `XAGUSD.DWX`, D1, planned magic `410300001`
- risk: one package `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

The atomic registry allocator assigned `QM5_41030` at commit `1e77986e5`.
No ID was inferred or appended by hand.

## Source And Hypothesis Review

The OWNER-authorized source decision is
`decisions/2026-08-16_xauxag_relative_flow_divergence_source_approval.md` at
commit `ee6468d58`. The bounded composite packet joins:

- Williams' OWNER-supplied Tier-A Pro-Go extraction, which defines separate
  prior-close-to-open and open-to-close price-flow objects; and
- Schweikert's peer-reviewed gold/silver relationship evidence plus CME's
  governed gold/silver intermarket-spread material.

The approved hypothesis is narrower and untested by those sources. For an
exact synchronized completed gold/silver Monday-through-Friday week, form
gold-minus-silver close-to-open flow and gold-minus-silver open-to-close flow.
Trade the next Monday only when the two relative components have opposite
strict signs, take the open-to-close component's direction with opposite XAU
and XAG legs, and flatten both Friday. Exact weekly aggregation, cross-metal
subtraction, disagreement selection, session-following direction, equal-
notional sizing, broker-calendar synchronization, attachment grace, fixed
risk, hard stops, spread caps, attempt state, and repair behavior are QM
translations. No source performance, significance, density, neutrality,
decorrelation, or portfolio result transfers.

## G0 Gates

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: one OWNER-supplied Tier-A book
  extraction defines the two flows; one peer-reviewed DOI lineage and one CME
  exchange packet support the state-dependent relative-value carrier. The
  untested conjunction and source distance are disclosed.
- R2 `PASS`: synchronized exact-week sequence, completed close/open endpoints,
  cross-metal subtraction, strict disagreement, direction, persistent attempt,
  entry grace, aggregate risk, equal-notional constraint, stops, spreads,
  paired Friday close, and stale repair are deterministic and frozen.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 bars plus native MT5 execution state provide every runtime
  input. Q02 must use one logical basket over synchronized history.
- R4 `PASS`: no trained output, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, or pyramid.

## Locked Execution Contract

1. Run only from `XAUUSD.DWX`, D1, EA ID 41030, slot 0, with XAG in slot 1.
2. Require the current XAU and XAG D1 timestamps to match exactly, their date
   to equal the broker date, and the broker clock to be Monday.
3. Require the six immediately completed timestamps to match across both
   symbols and, newest first, identify prior Friday, Thursday, Wednesday,
   Tuesday, Monday, and the preceding Friday at exact offsets 3, 4, 5, 6, 7,
   and 10 calendar days. Never shift or substitute a holiday.
4. Admit only the first observed tick within 180 minutes of executable Monday
   D1 open. Persist the broker-Monday attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates. Never retry or backfill.
5. For prior-week shifts 5 through 1, compute each metal's completed
   `log(Open[shift]/Close[shift+1])` and
   `log(Close[shift]/Open[shift])` sums. Subtract the silver sum from the gold
   sum for `overnight_relative` and `session_relative`. Current-bar price is
   excluded.
6. When `session_relative > 0` and `overnight_relative < 0`, BUY XAU and SELL
   XAG. When `session_relative < 0` and `overnight_relative > 0`, SELL XAU and
   BUY XAG. Agreement, exact zero, or invalid arithmetic stays flat.
7. Size one opposite-leg equal-USD-notional package. Round volumes down, reject
   notional mismatch above 20%, and keep combined frozen-stop loss at or below
   `RISK_FIXED=1000`. Each leg uses `3.0 * ATR(20,D1)` and a 1,500-point spread
   ceiling. No target exists.
8. If either leg fails to open, immediately close the survivor and consume the
   week. Never scale in, retry, pyramid, grid, martingale, or treat one leg as
   a standalone strategy.
9. Close both legs together on or after broker Friday 21:00. Keep framework
   Friday close enabled as a fail-safe; close a surviving package on the first
   later-week boundary or after eight calendar days.
10. Keep both news axes OFF. Use native MT5 data and state only.

## Non-Duplicate And Portfolio Boundary

The canonical checker scanned 4,517 registry rows and 613 root cards and found
no exact or fuzzy identity. Manual review separated the fixed-direction
weekend basket, ratio/residual/tail reversion systems, monthly close-to-close
relative momentum, failed-break and fresh-run fades, the single-leg WTI flow-
agreement system, and the existing commodity oscillator. The locked identity
is the conjunction of exact synchronized week, close/open decomposition,
gold-minus-silver subtraction, strict disagreement, session-following sides,
equal-notional package, and Monday-to-Friday lifecycle.

This establishes mechanic and carrier novelty only. It does not establish
profitability, neutrality, low correlation, certification, or admission to the
book. Q02 owns density and governed economics. Q09 alone owns realized
correlation with XAU/SP500/NDX/XNG.

## Authorization Boundary

Authorized now:

- synchronize the two approved card copies;
- allocate slot-0 and slot-1 magic rows through the deterministic registry;
- implement one V5 EA and one logical-basket manifest;
- create one logical D1 backtest setfile with `RISK_FIXED=1000` and
  `RISK_PERCENT=0`;
- run reference tests, strict compile/build checks, card lint, manifest
  validation, and static Q01 validation; and
- enqueue exactly one paced Q02 logical-basket work item if the factory CPU
  ceiling is not binding.

Not authorized:

- manual tester launch or dispatcher control;
- live, demo, shadow, stress, or optimization presets;
- AutoTrading, `T_Live`, deploy manifests, or T_Live manifests;
- portfolio-gate changes, portfolio admission, neutrality claims, or
  correlation waivers; or
- after-result parameter, direction, clock, carrier, or lifecycle changes.

Expected cadence is approximately fifteen to thirty completed packages per
full post-warm-up year. Q02 must retire below five/year or on zero trades,
nonpositive governed economics, wrong dates/endpoints/subtraction/sides,
current-bar leakage, late or repeated entry, excess notional mismatch, orphan
survival, wrong lifecycle, nondeterminism, or invalid risk mode. If the
backtest CPU ceiling is binding, record the stop and do not enqueue or launch a
manual test.
