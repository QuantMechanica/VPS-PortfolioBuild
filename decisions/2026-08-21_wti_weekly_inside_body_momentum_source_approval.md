# WTI weekly inside-range body momentum source approval

Date: 2026-08-21

Decision: `APPROVED_SOURCE`

## Authority and scope

The current explicit OWNER instruction delivered to Codex on branch
`agents/board-advisor` authorizes one new structural, low-frequency
commodity/energy edge outside the certified XAU/SP500/NDX/XNG book. It
explicitly permits an `XTIUSD` trend/seasonality candidate and requires a
reputable-source record, one QM card and build, `RISK_FIXED` backtest
configuration, a paced Q02 handoff, branch-only commits, and no `T_Live`,
AutoTrading, portfolio-gate, or `T_Live`-manifest changes.

This decision approves source intake for one bounded candidate:

- planned source ID: `MOP-WTI-WINSIDE-BODY-MOM-2026`;
- planned strategy ID: `MOP-WTI-WINSIDE-BODY-MOM-2026_S01`;
- planned slug: `wti-winside-body-mom`;
- instrument and clock: exact `XTIUSD.DWX`, D1, evaluated once at the first
  tradable bar of a new Monday-anchored broker week; and
- governed source record to read completely before extraction:
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

This is source approval only. It does not approve a Strategy Card, allocate an
EA ID or magic number, authorize a build, establish efficacy or decorrelation,
waive any Q gate, or authorize live use.

## Candidate mechanic authorized for extraction

Aggregate the immediately completed broker week and its consecutive parent
week from native WTI D1 OHLC. Each package must contain three to five unique
sessions, the anchors must be exactly seven calendar days apart, and the
current decision week must be excluded.

Require the newer completed week to be strictly contained inside its parent:

```text
newer_high < parent_high && newer_low > parent_low
```

- BUY only when the newer inside week's final close is strictly above its
  first-session open.
- SELL only when the newer inside week's final close is strictly below its
  first-session open.
- Equality, non-inside geometry, malformed history, incomplete packages, or
  nonconsecutive anchors stay flat.

The intended baseline follows that completed inside week's own body direction
for exactly one broker week, with one durable attempt, one fixed-risk
position, a frozen completed-bar ATR hard stop, no target, and no external
runtime data. The source read and Q00 process must lock the exact label,
session, risk, lifecycle, and falsification contracts before build.

## Preliminary non-duplicate boundary

The canonical fail-closed pre-allocation checker used the complete mechanic,
the actual Company Reference Wiki root, and author lineage. It scanned 4,580
EA-registry identities, 1,253 repository cards, and 45 Strategy Wiki nodes and
returned `CLEAN`, with no exact or fuzzy match.

Manual intake review found no existing WTI EA with the jointly load-bearing
combination of strict completed-week containment, the contained week's own
open-to-close sign, boundary entry, and one-week hold:

- `QM5_13075_xti-inweek-brk` waits for a current-week D1 close beyond the
  frozen inside-week extreme and adds SMA, ATR-range, close-location, target,
  and failed-breakout rules. This candidate consumes no current-week signal
  price and enters only at the boundary from the completed inside-week body.
- `QM5_41061_wti-week-nr7-brk` ranks seven completed ranges and waits for a
  current-week close breakout. This candidate has no range rank and no
  breakout.
- `QM5_41073_wti-woutside-settle` requires the opposite geometry, a strict
  outside week, plus settlement and close-location confirmation.
- `QM5_41089_wti-wrange-migrate-mom` requires both completed range endpoints
  to migrate in the same direction and explicitly leaves inside geometry
  flat.
- `QM5_41090_wti-wmid-overlap-mom` compares high/low midpoints under any
  positive overlap and excludes every open and close. This candidate requires
  full strict containment and uses only the contained week's open/close body
  for side.
- `QM5_41080_wti-wclose-location-mom` uses parent-close to newest-close return
  sign plus an outer-fifth close-location threshold. This candidate uses no
  parent close and no close-location threshold.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG cumulative-RSI2
  pullback under a slow trend filter on a different carrier.

Q00 still owes a fresh post-allocation identity scan and full semantic family
review. Any exact identity discovered before approval must stop allocation and
build.

## Source and claim boundary

Moskowitz, Ooi, and Pedersen (2012) is approved as the sole lineage source for
the broad proposition that an asset's own past price direction can carry
continuation information; the governed record states that crude-oil futures
are in the paper's commodity universe. The authors do not test weekly inside
ranges, weekly candle bodies, Darwinex continuous CFDs, fixed cash risk, an
ATR stop, or a one-week hold. Those are transparent QM hypotheses, not source
claims.

No source return, WTI-specific alpha, profit factor, drawdown, trade count,
cost, CFD equivalence, neutrality, or book-correlation statistic may transfer
to the card. Q02 owns frequency and baseline economics. Q09 alone may measure
realized portfolio correlation; Q11 alone owns portfolio admission.

## Safety boundary

This approval authorizes only complete reading of the bounded governed source,
creation of one child source packet, and subsequent Q00 consideration. It does
not authorize a manual tester run, terminal control, live/demo/shadow/stress/
optimization preset, AutoTrading action, `T_Live` change, deploy or
`T_Live`-manifest edit, portfolio-gate edit, portfolio admission, correlation
waiver, after-result parameter salvage, or a duplicate queue row.
