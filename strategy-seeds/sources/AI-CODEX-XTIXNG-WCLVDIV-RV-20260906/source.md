---
source_id: AI-CODEX-XTIXNG-WCLVDIV-RV-20260906
title: XTI/XNG completed-week opposite close-location reversion
publisher: QuantMechanica governed extraction of reputable sources
source_type: government_peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-06_xtixng_weekly_close_location_divergence_reversion_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
parent_sha256:
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
created: 2026-09-06
created_by: Research+Development
cards_extracted:
  - xtixng-wclv-div-rv
---

# XTI/XNG Completed-Week Opposite Close-Location Reversion

## Approved Source Of Record

The complete governed parent packet
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md` was read before
approval. It covers Villar and Joutz (2006), *The Relationship Between Crude
Oil and Natural Gas Prices*, U.S. Energy Information Administration, and
Ramberg and Parsons (2012), "The Weak Tie Between Natural Gas and Oil Prices,"
*The Energy Journal* 33(2), 13-35, DOI `10.5547/01956574.33.2.2`, together
with modern adverse EIA context.

The durable approval for this bounded child source is
`decisions/2026-09-06_xtixng_weekly_close_location_divergence_reversion_source_approval.md`.
No new online page, inaccessible source, unrecorded result, or inherited
coefficient is used.

## Source Findings Used

Villar/Joutz and Ramberg/Parsons document physical and economic oil/gas links
through substitution, co-production, drilling, finance, transport, and LNG.
They also make instability, regional gas fundamentals, changing coefficients,
and a weak rather than fixed tie binding adverse evidence. Those findings
support testing a transparent relative-value carrier while forbidding any
assumption that a permanent equilibrium, fixed hedge ratio, profitability, or
neutrality already exists.

No source tests completed-week per-leg close locations, outer terciles, the
contrarian direction, a one-week hold, continuous CFDs, equal-notional sizing,
or this conjunction. Those are pre-result QM falsification choices.

## Bounded QM Mechanization

On the first executable synchronized `XTIUSD.DWX` / `XNGUSD.DWX` D1 bar of a
new Monday-anchored broker week, aggregate every synchronized completed D1 bar
from the immediately preceding broker week. Require three to five unique
sessions with identical timestamps. For each leg compute independently:

```text
range_leg = completed_week_high - completed_week_low
clv_leg   = (completed_week_final_close - completed_week_low) / range_leg

XTI clv > 2/3 and XNG clv < 1/3 => SELL XTI / BUY XNG
XTI clv < 1/3 and XNG clv > 2/3 => BUY XTI / SELL XNG
otherwise                         => consume week flat
```

All inputs are completed before the decision week. Equality at a boundary,
interior states, invalid ranges, asynchronous timestamps, missing/extra
sessions, late attachment, or invalid arithmetic consumes the week flat.
Persist the attempt before history, signal, spread, quote, ATR, sizing, news,
margin, or order gates. Signal distance never changes side or risk.

## Frozen Basket And Risk Contract

- host `XTIUSD.DWX`, D1, slot 0; companion `XNGUSD.DWX`, D1, slot 1;
- one attempt within 180 minutes of the first synchronized weekly D1 bar;
- one opposed package targeting equal absolute USD notionals;
- maximum post-rounding notional mismatch 20 percent;
- combined normalized stop risk capped at one `RISK_FIXED=1000` budget;
- `RISK_PERCENT=0.0`, `PORTFOLIO_WEIGHT=1.0`;
- frozen per-leg hard stop `3.5*ATR(20,D1)`, no take-profit;
- positive-spread ceilings 1,500 XTI points and 3,000 XNG points;
- both news axes OFF and Friday close OFF;
- first-later-week exit and ten-calendar-day stale repair;
- no retry, partial close, trail, break-even, scale-in, pyramid, grid,
  martingale, external data, fitted model, trained output, or fallback signal.

## Expected Cadence And Falsification

Strict opposite outer-tercile locations are expected to produce roughly six
to twelve logical packages per full post-warm-up year. Q02 retires below five
completed packages in any full scored year, on nonpositive governed
economics, or on any identity, synchronization, aggregation, boundary, side,
risk, stop, atomicity, lifecycle, or determinism defect. No observed result
may be rescued by changing the terciles, accepting equality, switching side,
adding a filter, or fitting a center or beta.

## Reputable-Source And Duplicate Boundary

- R1 `PASS_WITH_RULE_TRANSLATION_RISK`: complete U.S. government and
  peer-reviewed oil/gas relationship evidence, with adverse instability
  preserved; the weekly CLV fade remains explicitly untested.
- R2 `PASS`: exact clock, synchronized week membership, OHLC aggregation,
  strict boundaries, sides, attempt, risk, stops, and lifecycle are fixed.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 OHLC and MT5 execution state provide every runtime input.
- R4 `PASS`: deterministic timestamps, OHLC arithmetic, ATR risk plumbing,
  quotes, positions, deals, and persistent state only; no banned signal or ML.

The canonical scan covered 4,844 registry rows and 1,457 cards. It found no
exact identity and one expected fuzzy match: `QM5_41088_xauxag-wclv-div-rv`.
That sibling uses the same transparent statistic on precious metals. This
candidate owns a different physical/economic carrier, contract metadata,
cost surface, source thesis, and realized energy return stream. Existing
XTI/XNG candidates use ratio levels, fitted residuals, returns, robust monthly
statistics, weekday/calendar effects, price-flow decomposition, common-shock
returns, weekly overshoot/acceleration/retracement, or deceleration states;
none uses independent completed-week auction locations. Verdict:
`FUZZY_MECHANIC_PORT_RESOLVED_DISTINCT_XTIXNG_COMPLETED_WEEK_OPPOSITE_LEG_CLOSE_LOCATION_TERCILE_REVERSION`.

## Safety Boundary

The OWNER mission authorizes this source packet, one G0 card, deterministic
EA and magic allocation, a branch-only non-live build, strict Q01 validation,
and one paced logical `RISK_FIXED` Q02 enqueue only below the CPU ceiling. It
excludes manual backtests, live/demo/shadow/optimization presets, terminal
control, AutoTrading, `T_Live`, deploy or live manifests, portfolio-gate
changes, portfolio admission, decorrelation claims, and correlation waivers.
