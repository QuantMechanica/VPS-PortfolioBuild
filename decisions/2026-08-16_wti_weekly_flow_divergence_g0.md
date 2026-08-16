# QM5_41032 WTI Weekly Public/Professional Flow Divergence G0 Authorization

Date: 2026-08-16

Decision: `APPROVED` for G0 research intake, deterministic build,
instrumentation, strict Q01 validation, and one paced non-live Q02 enqueue if
CPU capacity permits.

Authority: OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`.

## Approved Identity

- EA ID: `QM5_41032`, allocated by the canonical locked allocator at commit
  `ef287429d`
- slug: `wti-flow-div`
- strategy ID: `WILLIAMS-MOP-WTI-WFLOWDIV-2026_S01`
- governed card:
  `strategy-seeds/cards/approved/QM5_41032_wti-flow-div_card.md`
- source approval:
  `decisions/2026-08-16_wti_weekly_flow_divergence_source_approval.md`
- carrier: exact `XTIUSD.DWX`, D1, planned slot 0 and magic `410320000`

The card and execution contract are both `APPROVED` for this non-live build.
This decision does not approve live use or portfolio admission.

## Locked Hypothesis

At the first executable tick of a genuine broker Monday, reconstruct one exact
completed Monday-through-Friday WTI week plus the preceding Friday anchor.
Sum the five prior-close-to-open log returns and five open-to-close log returns
separately. Trade only when their signs strictly oppose and follow the session
component:

```text
session_flow > 0 and overnight_flow < 0 => BUY XTIUSD.DWX
session_flow < 0 and overnight_flow > 0 => SELL XTIUSD.DWX
otherwise                                => consume week flat
```

All endpoints are completed before the current Monday. Persist the Monday
attempt before fallible gates, allow no retry, size one frozen-stop position
from one fixed-dollar budget, and close Friday.

## Source And Claim Boundary

The bounded packet
`strategy-seeds/sources/WILLIAMS-MOP-WTI-WFLOWDIV-2026/source.md` joins:

1. Williams (1999), *Long-Term Secrets to Short-Term Trading*, the complete
   OWNER-supplied Tier-A extraction whose page-18 text defines public
   close-to-open and professional open-to-close flows and discusses divergence
   and crossings.
2. Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
   104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, whose complete-read
   record identifies WTI as a commodity-futures carrier and delimits a
   different own-return continuation family.

Neither source tests this exact weekly WTI opposition rule or its direction,
calendar, CFD, risk, or lifecycle. All such choices are disclosed QM
translations. No source return, trade count, significance, drawdown, cost,
CFD equivalence, decorrelation, or portfolio result transfers.

## Reputable-Source Gates

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: complete Tier-A practitioner
  extraction plus complete-read peer-reviewed JFE carrier lineage; the
  untested conjunction is explicit.
- R2 `PASS`: completed endpoints, exact week, label normalization, opposition,
  direction, attempt state, entry grace, risk, stop, spread, and Friday exit
  are deterministic.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC and native execution state supply
  every runtime input.
- R4 `PASS`: fixed calendar, OHLC, logarithm, ATR, quote, position, deal, and
  terminal-state arithmetic only; no trained output, banned signal indicator,
  external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Authorization

The canonical checker scanned 4,519 EA-registry rows and 615 root cards. It
found no exact identity and raised two fuzzy matches. Manual family review
returned
`CLEAN_WTI_WEEKLY_PUBLIC_PROFESSIONAL_FLOW_DIVERGENCE_AFTER_FAMILY_REVIEW`:

- `QM5_41029` trades component agreement; this card trades only the disjoint
  opposition state and follows session flow.
- `QM5_12784` trades a fourteen-day moving-line crossover on any D1 bar; this
  card has no moving line or crossing and uses an exact completed week.
- `QM5_41030` is a gold-minus-silver two-leg relative basket; this card is a
  one-leg direct WTI rule.
- `QM5_21520` is an XNG close-return and tick-volume-rank rule; its fuzzy match
  is lexical, not mechanical.
- `QM5_12567` is a long-only oscillator pullback.

No failure may be rescued by accepting agreement, reversing session direction,
adding a threshold or filter, moving the clock, or extending the hold.

## Build Contract

Development may create exactly:

- `framework/EAs/QM5_41032_wti-flow-div/` from the V5 skeleton;
- one slot-0 registry row for exact `XTIUSD.DWX`;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, D1 backtest setfile;
- deterministic reference tests for calendar identity, component arithmetic,
  opposition mapping, attempt state, risk, and lifecycle; and
- one strict compile and static Q01 evidence set.

The implementation must preserve both news axes OFF, Friday close ON at broker
hour 21, a frozen `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling,
the 180-minute entry grace, and the eight-day stale guard.

## Kill And Safety Boundary

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, wrong week identity or component endpoints, current-bar
leakage, entry on agreement, wrong side, late or repeated Monday entry, wrong
lifecycle, invalid risk mode, nondeterminism, or nonpositive governed
economics. Q09 alone may establish realized book correlation.

This authorization excludes manual backtests; live/demo/shadow/stress/
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate edits; portfolio admission; and
correlation waivers. If the tester CPU ceiling is binding, stop before queue
mutation and record the handoff.

