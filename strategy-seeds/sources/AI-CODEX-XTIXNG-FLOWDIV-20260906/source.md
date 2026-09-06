---
source_id: AI-CODEX-XTIXNG-FLOWDIV-20260906
title: XTI/XNG completed-week relative-flow divergence session-follow basket
publisher: QuantMechanica governed extraction of reputable sources
source_type: government_peer_reviewed_practitioner_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-06_xtixng_weekly_relative_flow_divergence_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
  - WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026
parent_sha256:
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
  WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026: 6B58F287E6E56275933986096DE6993CC4DBD70B358DAE8603FA71B1BB337EFC
created: 2026-09-06
created_by: Research+Development
cards_extracted:
  - xtixng-flowdiv
---

# XTI/XNG Completed-Week Relative-Flow Divergence

## Approved Source Of Record

This bounded extraction joins two complete governed repository packets read
before durable source approval:

1. `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, covering
   Villar and Joutz (2006), *The Relationship Between Crude Oil and Natural
   Gas Prices*, U.S. Energy Information Administration, and Ramberg and
   Parsons (2012), "The Weak Tie Between Natural Gas and Oil Prices," *The
   Energy Journal* 33(2), 13-35, DOI `10.5547/01956574.33.2.2`.
2. `strategy-seeds/sources/WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026/source.md`,
   used only for the already governed close-to-open/open-to-close arithmetic,
   exact completed-week clock, and basket lifecycle. Its precious-metals
   economic claims and empirical outcomes do not transfer.

The durable OWNER approval is
`decisions/2026-09-06_xtixng_weekly_relative_flow_divergence_source_approval.md`.

## Source Findings Used

Villar/Joutz and Ramberg/Parsons document physical and economic oil/gas links
through substitution, co-production, drilling, finance, transport, and LNG.
They also make instability, regional gas fundamentals, and a weak rather than
fixed tie binding adverse evidence. Williams supplies the transparent daily
prior-close-to-open and open-to-close return decomposition.

No source establishes that disagreement between weekly relative overnight and
session flows predicts the session direction, that continuous CFDs reproduce
the source instruments, or that opposed XTI/XNG legs are neutral, profitable,
or uncorrelated to the current book.

## Bounded QM Mechanization

On the first executable `XTIUSD.DWX` D1 bar of an eligible broker Monday,
align the current XTI/XNG bar and six immediately completed bars. Require the
completed shared dates, newest first, to be Friday through Monday plus the
preceding Friday at exact calendar offsets 3, 4, 5, 6, 7, and 10 days. For
each of the five completed sessions define:

```text
xti_overnight[d] = ln(XTI_open[d] / XTI_close[prior_session])
xng_overnight[d] = ln(XNG_open[d] / XNG_close[prior_session])
xti_session[d]   = ln(XTI_close[d] / XTI_open[d])
xng_session[d]   = ln(XNG_close[d] / XNG_open[d])

overnight_relative = sum(xti_overnight[d] - xng_overnight[d])
session_relative   = sum(xti_session[d]   - xng_session[d])

session_relative > 0 and overnight_relative < 0 => BUY XTI / SELL XNG
session_relative < 0 and overnight_relative > 0 => SELL XTI / BUY XNG
otherwise                                          => consume week flat
```

All endpoints complete before the decision Monday. Exact zero, component
agreement, missing holiday sessions, asynchronous timestamps, invalid prices,
or late attachment consumes the week flat. Persist the Monday attempt before
every fallible history, signal, quote, ATR, sizing, news, or order gate.

## Frozen Basket And Risk Contract

- host `XTIUSD.DWX`, D1, slot 0; companion `XNGUSD.DWX`, D1, slot 1;
- decision within 180 elapsed minutes of the synchronized Monday D1 open;
- one opposed package targeting equal absolute USD notionals;
- maximum post-rounding notional mismatch 20 percent;
- combined stop-risk capped at one `RISK_FIXED=1000` budget;
- `RISK_PERCENT=0.0`, `PORTFOLIO_WEIGHT=1.0`;
- frozen per-leg hard stop `3.0*ATR(20,D1)`, no take-profit;
- positive-spread ceilings 1,500 XTI points and 3,000 XNG points;
- news axes OFF; paired close Friday at broker hour 21;
- later-week and eight-calendar-day stale repair;
- no retry, partial close, trailing stop, break-even, scale-in, pyramid, grid,
  martingale, external data, trained output, or fallback signal.

## Expected Cadence And Falsification

Strict component disagreement is expected to produce roughly fifteen to
thirty completed packages per full post-warm-up year. Q02 retires below five
packages in any full scored year, on nonpositive governed economics, or on an
identity, synchronization, endpoint, side, sizing, stop, atomicity,
lifecycle, or determinism defect. No threshold, sign, direction, carrier,
clock, stop, or hold may be altered after seeing a result to rescue this
lineage.

## Reputable-Source And Duplicate Boundary

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: U.S. government research,
  peer-reviewed Energy Journal evidence, and a governed Williams price-flow
  extraction; adverse oil/gas instability is explicit.
- R2 `PASS`: exact synchronized dates, endpoints, arithmetic, sign state,
  sides, attempt, risk, stops, spreads, and lifecycle are fixed.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 OHLC plus MT5 execution state provide every runtime input.
- R4 `PASS`: deterministic timestamps, logarithms, arithmetic, ATR risk
  plumbing, quotes, positions, and deals only; no banned signal or ML.

The canonical scan found no exact identity and surfaced the expected XAU/XAG
arithmetic parent. The new carrier has a separate physical thesis, price
process, contract metadata, cost surface, and realized return stream. Existing
XTI/XNG candidates use ratio levels, residuals, close-to-close paths, robust
monthly statistics, weekdays, or calendars rather than this two-component
information-time decomposition. Verdict:
`FUZZY_CARRIER_PORT_RESOLVED_DISTINCT_XTIXNG_WEEKLY_RELATIVE_FLOW_DISAGREEMENT_SESSION_FOLLOW_BASKET`.

## Safety Boundary

The OWNER approval authorizes this source packet, one G0 card, deterministic
EA and magic allocation, branch-only non-live build, strict compile, one
logical `RISK_FIXED` backtest setfile, and one paced Q02 enqueue only below the
CPU ceiling. It excludes manual backtests, live/demo/shadow/optimization
presets, AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio gate
changes, portfolio admission, and correlation waivers.
