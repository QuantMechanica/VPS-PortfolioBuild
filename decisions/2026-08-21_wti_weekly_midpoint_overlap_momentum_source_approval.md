# WTI weekly midpoint-overlap momentum source approval

Date: 2026-08-21

Decision: `APPROVED_SOURCE`

## Authority and scope

The OWNER instruction delivered to Codex on branch `agents/board-advisor`
authorizes one new structural, low-frequency commodity/energy edge, explicitly
including an `XTIUSD` trend candidate. It requires a reputable-source record,
one QM card and build, `RISK_FIXED` backtest configuration, a paced Q02 handoff,
branch-only commits, and no `T_Live`, AutoTrading, portfolio-gate, or
`T_Live`-manifest changes.

This decision approves source intake for the following bounded candidate:

- planned source ID: `MOP-WTI-WMID-OVERLAP-MOM-2026`;
- planned strategy ID: `MOP-WTI-WMID-OVERLAP-MOM-2026_S01`;
- planned slug: `wti-wmid-overlap-mom`;
- instrument and clock: exact `XTIUSD.DWX`, D1, evaluated once at the first
  tradable bar of a new Monday-anchored broker week; and
- primary governed source record to read completely before extraction:
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

It is source approval only. It does not approve a Strategy Card, allocate an
EA ID or magic number, authorize a build, establish efficacy or decorrelation,
waive any Q gate, or authorize live use.

## Candidate mechanic authorized for extraction

Aggregate the two immediately preceding consecutive completed broker weeks
from native WTI D1 highs and lows. Each completed week must contain three to
five unique sessions, and the current decision week is excluded.

Let each completed week's auction midpoint be `(weekly_high + weekly_low) / 2`.
Require the two weekly ranges to overlap strictly:

```text
max(newer_low, older_low) < min(newer_high, older_high)
```

- BUY only when the newer completed midpoint is strictly above the older
  midpoint.
- SELL only when the newer completed midpoint is strictly below the older
  midpoint.
- Equality, non-overlap, malformed, incomplete, or nonconsecutive states stay
  flat.

The intended baseline follows this completed weekly auction-center drift for
exactly one broker week, with one durable attempt, one fixed-risk position, a
frozen completed-bar ATR hard stop, no target, and no external runtime data.
The source read and G0 process must lock the exact session, risk, lifecycle,
and falsification contracts before build.

## Preliminary non-duplicate boundary

The canonical pre-allocation checker included author and complete-mechanic
fields, scanned 4,579 EA-registry identities and 625 root cards, and returned
`CLEAN`, with no exact or fuzzy match. Manual intake review found no existing
WTI weekly EA that trades strict midpoint drift only when consecutive
completed weekly auction ranges overlap:

- `QM5_41089_wti-wrange-migrate-mom` requires both weekly endpoints to migrate
  strictly in the same direction; this candidate instead requires overlap and
  compares only the two high/low midpoints, so partial one-endpoint shifts can
  qualify while non-overlapping ranges cannot;
- `QM5_41073_wti-woutside-settle` requires a higher high and lower low plus
  settlement, body, and close-location confirmation; this candidate excludes
  every open and close;
- `QM5_41080_wti-wclose-location-mom` and the weekly return-path family use
  completed closes or return signs; this candidate reads no close;
- `QM5_41087_wti-wr4-close-mom` ranks four weekly widths and requires body and
  close-location agreement; this candidate ranks no width and uses two weeks;
- `QM5_41061_wti-week-nr7-brk`, `QM5_13075_xti-inside-week-brk`, and
  `QM5_12965_wti-week-orb` wait for a current-week breakout; this candidate
  excludes current-week signal price and enters only at the boundary; and
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG cumulative-RSI2
  pullback under a slow trend filter on a different carrier.

G0 still owes a fresh post-allocation check and full semantic family review.
Any exact identity discovered before approval must stop allocation and build.

## Source and claim boundary

Moskowitz, Ooi, and Pedersen (2012) is approved as the sole lineage source for
the broad proposition that an asset's own past price direction can carry
continuation information; the governed record states that crude-oil futures
are in the paper's commodity universe. The authors do not test weekly auction
midpoints, an overlap gate, Darwinex continuous CFDs, fixed cash risk, an ATR
stop, or a one-week hold. Those are transparent QM hypotheses, not source
claims.

No source return, WTI-specific alpha, profit factor, drawdown, trade count,
cost, CFD equivalence, neutrality, or book-correlation statistic may transfer
to the card. Q02 owns frequency and baseline economics. Q09 alone may establish
realized portfolio correlation.

## Safety boundary

This approval authorizes only complete reading of the bounded governed source,
creation of a child source packet, and subsequent G0 consideration. It does not
authorize a manual tester run, terminal control, live/demo/shadow/stress/
optimization preset, AutoTrading action, `T_Live` change, deploy or
`T_Live`-manifest edit, portfolio-gate edit, portfolio admission, correlation
waiver, after-result parameter salvage, or a duplicate queue row.
