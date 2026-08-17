# QM5_41034 WTI Monthly Information-Flow Agreement G0 Authorization

Date: 2026-08-17

Decision: `APPROVED` for G0 research intake, deterministic build,
instrumentation, strict Q01 validation, and one paced non-live Q02 enqueue if
CPU capacity permits.

Authority: OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`.

## Approved Identity

- EA ID: `QM5_41034`, allocated by the canonical locked allocator at commit
  `043a5f7ee`
- slug: `wti-mflow-agree`
- strategy ID: `WILLIAMS-MOP-WTI-MFLOWAGREE-2026_S01`
- governed card:
  `strategy-seeds/cards/approved/QM5_41034_wti-mflow-agree_card.md`
- source approval:
  `decisions/2026-08-17_wti_monthly_flow_agreement_source_approval.md`
- source approval commit: `ddb43e0da`
- carrier: exact `XTIUSD.DWX`, D1, planned slot 0 and magic `410340000`

The card and execution contract are both `APPROVED` for this non-live build.
This decision does not approve live use or portfolio admission.

## Locked Hypothesis

At the first executable D1 tick of a new normalized broker month, reconstruct
the immediately completed WTI month plus its preceding month-end anchor. Sum
every prior-close-to-open log return and every open-to-close log return
separately. Trade only when the two component signs strictly agree and follow
their reconciled completed-month direction:

```text
overnight_flow = sum(log(Open[d] / Close[prior_session]))
session_flow   = sum(log(Close[d] / Open[d]))
month_return   = log(PriorMonthEndClose / PriorPriorMonthEndClose)
total_flow     = overnight_flow + session_flow

require sign(overnight_flow) = sign(session_flow) != 0
require total_flow reconciles to month_return

total_flow > 0 => BUY XTIUSD.DWX
total_flow < 0 => SELL XTIUSD.DWX
otherwise      => consume month flat
```

All endpoints are completed before the current month. Persist the month
attempt before fallible gates, allow no retry, size one frozen-stop position
from one fixed-dollar budget, and renew only at the next month boundary.

## Source And Claim Boundary

The bounded packet
`strategy-seeds/sources/WILLIAMS-MOP-WTI-MFLOWAGREE-2026/source.md` joins:

1. Williams (1999), *Long-Term Secrets to Short-Term Trading*, the complete
   OWNER-supplied Tier-A extraction whose page-18 text defines public
   close-to-open and professional open-to-close price flows and discusses
   their separate accumulation, divergences, and crossings.
2. Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
   104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, whose complete-read
   record identifies WTI as a commodity-futures carrier and the one-month
   formation/hold family at the pooled commodity level.

Neither source tests this exact monthly information-flow agreement rule or
its CFD, calendar, risk, or lifecycle translation. No source return, trade
count, significance, drawdown, cost, WTI-only efficacy, CFD equivalence,
decorrelation, or portfolio result transfers.

## Reputable-Source Gates

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: complete Tier-A practitioner
  extraction plus complete-read peer-reviewed JFE carrier/one-month lineage;
  the untested conjunction is explicit.
- R2 `PASS`: completed endpoints, normalized month identity, component sums,
  agreement, reconciliation, direction, attempt state, entry grace, risk,
  stop, spread, and next-month exit are deterministic.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC and native execution state supply
  every runtime input.
- R4 `PASS`: fixed calendar, OHLC, logarithm, ATR, quote, position, deal, and
  terminal-state arithmetic only; no trained output, banned signal indicator,
  external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Authorization

The canonical checker scanned 4,521 registry rows and 617 root cards. It found
no exact identity and raised one expected fuzzy match. Manual family review
returned `CLEAN_WTI_MONTHLY_INFORMATION_FLOW_AGREEMENT_AFTER_FAMILY_REVIEW`:

- `QM5_41029` forms and holds one exact Monday-Friday week; this card forms
  and holds one entire normalized broker month.
- `QM5_20187` follows every nonzero one-month return. This card stays flat
  whenever its close-to-open and open-to-close components oppose.
- `QM5_41032` and `QM5_41033` admit weekly opposition, a disjoint state and
  cadence.
- `QM5_41023` compares two close-to-close boundary segments and holds five
  sessions rather than decomposing every prior-month interval.
- `QM5_12784` uses fourteen-day signed-value moving-line crossings, while
  `QM5_12567` is an oscillator pullback.

No failure may be rescued by accepting opposition, adding a threshold or
filter, changing the formation month, moving the clock, or altering the hold.

## Build Contract

Development may create exactly:

- `framework/EAs/QM5_41034_wti-mflow-agree/` from the V5 skeleton;
- one slot-0 registry row for exact `XTIUSD.DWX`;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, D1 backtest setfile;
- deterministic reference tests for month identity, label normalization,
  component arithmetic, agreement, reconciliation, attempt state, risk, and
  lifecycle; and
- one strict compile and static Q01 evidence set.

The implementation must preserve both news axes OFF, Friday close OFF, a
frozen `3.5 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, the
180-minute entry grace, 15-25 prior-month sessions, a `1e-10` reconciliation
tolerance, and the 40-day stale guard.

## Kill And Safety Boundary

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, wrong month identity or endpoints, current-bar leakage,
entry on component opposition, wrong direction, failed reconciliation, late
or repeated entry, wrong lifecycle, invalid risk mode, nondeterminism, or
nonpositive governed economics. Q09 alone may establish realized book
correlation.

This authorization excludes manual backtests; live/demo/shadow/stress/
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate edits; portfolio admission; and
correlation waivers. If the tester CPU ceiling is binding, stop before queue
mutation and record the handoff.

