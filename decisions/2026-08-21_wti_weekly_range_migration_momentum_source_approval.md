# WTI weekly range-migration momentum source approval

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

- planned source ID: `MOP-WTI-WRANGE-MIGRATE-MOM-2026`;
- planned strategy ID: `MOP-WTI-WRANGE-MIGRATE-MOM-2026_S01`;
- planned slug: `wti-wrange-migrate-mom`;
- instrument and clock: exact `XTIUSD.DWX`, D1, evaluated once at the first
  tradable bar of a new Monday-anchored broker week; and
- primary governed source record to read completely before extraction:
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

It is source approval only. It does not approve a Strategy Card, allocate an
EA ID or magic number, authorize a build, establish efficacy or decorrelation,
waive any Q gate, or authorize live use.

## Candidate mechanic authorized for extraction

Aggregate the two immediately preceding consecutive completed broker weeks
from native WTI D1 OHLC. Each completed week must contain three to five unique
sessions, and the current decision week is excluded.

- BUY only when the newest completed week has both a strict higher high and a
  strict higher low than its parent week.
- SELL only when it has both a strict lower high and a strict lower low.
- Mixed, equal, overlapping, malformed, incomplete, or nonconsecutive states
  remain flat.

The intended baseline follows this completed weekly auction-range migration
for exactly one broker week, with one durable attempt, one fixed-risk position,
a frozen completed-bar ATR hard stop, no target, and no external runtime data.
The source read and G0 process must lock the exact session, risk, lifecycle,
and falsification contracts before build.

## Preliminary non-duplicate boundary

The canonical pre-allocation checker scanned 4,578 EA-registry identities and
625 root cards and returned `CLEAN`, with no exact or fuzzy match for the
planned slug, strategy ID, author set, or mechanic. Manual intake review found
no existing WTI weekly EA that trades strict same-direction migration of both
completed-week range endpoints:

- `QM5_41073_wti-woutside-settle` requires a higher high *and lower low*, plus
  settlement outside the parent range and close/body confirmation;
- `QM5_41080_wti-wclose-location-mom` uses close-to-close return sign and the
  newest week's close location;
- `QM5_41087_wti-wr4-close-mom` ranks four weekly ranges and requires body/CLV
  agreement;
- `QM5_41061_wti-week-nr7-brk` and `QM5_13075_xti-inside-week-brk` require
  compression followed by a later breakout;
- the WTI weekly return-path family uses completed closes rather than strict
  migration of both weekly auction extremes; and
- `QM5_10596_mql5-highlow` is a multi-bar H4 star/flip system, not an exact
  completed-week WTI auction-range carrier or one-week lifecycle.

G0 still owes a fresh post-allocation check and full semantic family review.
Any exact identity discovered before approval must stop allocation and build.

## Source and claim boundary

Moskowitz, Ooi, and Pedersen (2012) is approved as the sole lineage source for
the broad proposition that an asset's own past price direction can carry
continuation information; the governed record states that crude-oil futures
are in the paper's commodity universe. The authors do not test this weekly
higher-high/higher-low or lower-high/lower-low state, Darwinex continuous CFD,
fixed cash risk, ATR stop, or one-week hold. Those are transparent QM
hypotheses, not source claims.

No source return, WTI-specific alpha, profit factor, drawdown, trade count,
cost, CFD equivalence, neutrality, or book-correlation statistic may transfer
to the card. Q02 owns frequency and baseline economics. Q09 alone may establish
realized portfolio correlation.

## Safety boundary

This approval authorizes only complete reading of the bounded governed source,
creation of a child source packet, and subsequent G0 consideration. It does
not authorize a manual tester run, terminal control, live/demo/shadow/stress/
optimization preset, AutoTrading action, `T_Live` change, deploy or
`T_Live`-manifest edit, portfolio-gate edit, portfolio admission, correlation
waiver, after-result parameter salvage, or a duplicate queue row.
