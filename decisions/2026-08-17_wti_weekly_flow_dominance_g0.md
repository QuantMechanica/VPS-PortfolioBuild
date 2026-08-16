# QM5_41033 WTI Weekly Opposed-Flow Dominance G0 Authorization

Date: 2026-08-17

Decision: `APPROVED` for G0 research intake, deterministic build,
instrumentation, strict Q01 validation, and one paced non-live Q02 enqueue if
CPU capacity permits.

Authority: OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`.

## Approved Identity

- EA ID: `QM5_41033`, allocated by the canonical locked allocator at commit
  `2f63c7b5f`
- slug: `wti-flow-dom`
- strategy ID: `WILLIAMS-MOP-WTI-WFLOWDOM-2026_S01`
- governed card:
  `strategy-seeds/cards/approved/QM5_41033_wti-flow-dom_card.md`
- source approval:
  `decisions/2026-08-17_wti_weekly_flow_dominance_source_approval.md`
- source approval commit: `1447c6ba8`
- carrier: exact `XTIUSD.DWX`, D1, planned slot 0 and magic `410330000`

The card and execution contract are both `APPROVED` for this non-live build.
This decision does not approve live use or portfolio admission.

## Locked Hypothesis

At the first executable tick of a genuine broker Monday, reconstruct one exact
completed Monday-through-Friday WTI week plus the preceding Friday anchor.
Sum five prior-close-to-open log returns and five open-to-close log returns
separately. Trade only when their signs strictly oppose and follow the
component with larger absolute magnitude, proven through reconciliation to
the exact completed Friday-to-Friday return:

```text
overnight_flow * session_flow < 0
total_flow = overnight_flow + session_flow
total_flow reconciles to log(PriorFridayClose / PrecedingFridayClose)

total_flow > 0 => BUY XTIUSD.DWX
total_flow < 0 => SELL XTIUSD.DWX
otherwise      => consume week flat
```

All endpoints are completed before the current Monday. Persist the Monday
attempt before fallible gates, allow no retry, size one frozen-stop position
from one fixed-dollar budget, and close Friday.

## Source And Claim Boundary

The bounded packet
`strategy-seeds/sources/WILLIAMS-MOP-WTI-WFLOWDOM-2026/source.md` joins:

1. Williams (1999), *Long-Term Secrets to Short-Term Trading*, the complete
   OWNER-supplied Tier-A extraction whose page-18 text defines public
   close-to-open and professional open-to-close flows and discusses
   divergences and crossings.
2. Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
   104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, whose complete-read
   record identifies WTI as a commodity-futures carrier and delimits a
   different own-return continuation family.

Neither source tests this exact weekly WTI opposition/dominance rule or its
calendar, CFD, risk, or lifecycle. All such choices are disclosed QM
translations. No source return, trade count, significance, drawdown, cost,
CFD equivalence, decorrelation, or portfolio result transfers.

## Reputable-Source Gates

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: complete Tier-A practitioner
  extraction plus complete-read peer-reviewed JFE carrier lineage; the
  untested conjunction is explicit.
- R2 `PASS`: completed endpoints, exact week, label normalization,
  opposition, reconciliation, dominant direction, attempt state, entry
  grace, risk, stop, spread, and Friday exit are deterministic.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC and native execution state supply
  every runtime input.
- R4 `PASS`: fixed calendar, OHLC, logarithm, ATR, quote, position, deal, and
  terminal-state arithmetic only; no trained output, banned signal indicator,
  external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Authorization

The canonical checker scanned 4,520 registry rows and 616 card files. It found
no exact identity and raised three fuzzy matches. Manual family review
returned `CLEAN_WTI_WEEKLY_OPPOSED_FLOW_DOMINANCE_AFTER_FAMILY_REVIEW`:

- `QM5_41032` trades the same opposition state but always follows session
  flow. This card follows the reconciled total/dominant component; it agrees
  only under session dominance, reverses under overnight dominance, and is
  flat on a tie.
- `QM5_41029` trades component agreement, a disjoint eligible state.
- `QM5_41022` splits the week into early/late close-to-close segments rather
  than decomposing every session by information time.
- `QM5_13049` adds magnitude and volatility-rank gates; `QM5_12784` trades a
  fourteen-day moving-line crossover; `QM5_10316` is a daily cross-sectional
  basket.
- `QM5_21520` is XNG close-return/tick-volume logic, while `QM5_12567` is an
  oscillator pullback.

No failure may be rescued by accepting agreement, always following one named
component, adding a threshold or filter, moving the clock, or extending the
hold.

## Build Contract

Development may create exactly:

- `framework/EAs/QM5_41033_wti-flow-dom/` from the V5 skeleton;
- one slot-0 registry row for exact `XTIUSD.DWX`;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, D1 backtest setfile;
- deterministic reference tests for calendar identity, component arithmetic,
  opposition, reconciliation, dominant mapping, attempt state, risk, and
  lifecycle; and
- one strict compile and static Q01 evidence set.

The implementation must preserve both news axes OFF, Friday close ON at
broker hour 21, a frozen `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread
ceiling, the 180-minute entry grace, a `1e-10` reconciliation tolerance, and
the eight-day stale guard.

## Kill And Safety Boundary

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, wrong week identity or endpoints, current-bar leakage,
entry on agreement, direction different from the reconciled total, failed
reconciliation, late or repeated Monday entry, wrong lifecycle, invalid risk
mode, nondeterminism, or nonpositive governed economics. Q09 alone may
establish realized book correlation.

This authorization excludes manual backtests; live/demo/shadow/stress/
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate edits; portfolio admission; and
correlation waivers. If the tester CPU ceiling is binding, stop before queue
mutation and record the handoff.

