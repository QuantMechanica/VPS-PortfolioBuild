# WTI weekly closing-breakout momentum source approval

Date: 2026-08-21

Decision: `APPROVED_SOURCE`

## Authority and scope

The current explicit OWNER instruction delivered to Codex on branch
`agents/board-advisor` authorizes one new structural, low-frequency
commodity/energy edge outside the certified XAU/SP500/NDX/XNG book. It
explicitly permits an `XTIUSD` structural trend candidate and requires a
reputable-source record, one QM card and build, `RISK_FIXED` backtest
configuration, one paced Q02 handoff, branch-only commits, and no `T_Live`,
AutoTrading, portfolio-gate, or `T_Live`-manifest changes.

This decision approves source intake for one bounded candidate:

- planned source ID: `MOP-SZAKMARY-WTI-WCLOSE-BRK-2026`;
- planned strategy ID: `MOP-SZAKMARY-WTI-WCLOSE-BRK-2026_S01`;
- planned slug: `wti-wclose-breakout-mom`;
- instrument and clock: exact `XTIUSD.DWX`, D1, evaluated once at the first
  tradable bar of a new normalized Monday-anchored broker week; and
- governed records to read completely before extraction:
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md` and
  `strategy-seeds/sources/SZAKMARY-WTI-MCH3-2010/source.md`.

This is source approval only. It does not approve a Strategy Card, allocate an
EA ID or magic number, authorize a build, establish efficacy or decorrelation,
waive a Q gate, or authorize live use.

## Candidate mechanic authorized for extraction

Reconstruct two exact, consecutive, completed broker weeks from native WTI D1
OHLC. Each package must contain three to five unique, strictly ordered
sessions. The newest package must be the week immediately before the current
decision week, and the parent must be the week immediately before the newest.
All current decision-week OHLC is excluded.

Define the parent range and the newest final settlement:

```text
parent_high  = max(parent session highs)
parent_low   = min(parent session lows)
newest_close = chronologically final close of the newest completed week
```

- BUY only when `newest_close > parent_high`.
- SELL only when `newest_close < parent_low`.
- Equality at either parent extreme, a close inside the parent range, invalid
  geometry, malformed history, or a nonconsecutive package stays flat.

The intended baseline follows the completed closing breakout for exactly one
broker week, with one durable attempt, one fixed-risk position, a frozen
completed-bar ATR hard stop, no target, and no external runtime data. The
source read and Q00 process must lock the exact label, session, risk,
lifecycle, and falsification contracts before build.

## Preliminary non-duplicate decision

The canonical fail-closed pre-allocation checker used the actual Company
Reference Wiki root plus complete author and mechanic fields. It scanned 4,582
EA-registry identities, 1,255 repository cards, and 45 Strategy Wiki nodes.
It found no exact slug or strategy-ID collision and surfaced five lexical
family matches for manual review.

The candidate is not an alias of any surfaced family member:

- `QM5_41091_wti-winside-body-mom` requires the newest weekly high and low to
  be strictly contained by the parent and follows the newest body's sign.
  This candidate requires the newest final close outside a parent extreme, so
  the two entry geometries are mutually exclusive.
- `QM5_41080_wti-wclose-location-mom` uses parent-final to newest-final return
  sign plus the newest close's location inside its own range. This candidate
  ignores the parent close and newest own-range location and instead compares
  the newest final close with the parent high and low.
- `QM5_41081_xng-wclose-location-mom` is the analogous close-location family
  on natural gas, not a parent-range closing breakout on WTI.
- `QM5_41073_wti-woutside-settle` requires the newest week to exceed both
  parent extremes, agree with its own open-to-close body, and settle in its
  own matching outer quartile. This candidate requires only a final close
  beyond one parent extreme; it has no opposite-side expansion, body, or
  close-location condition.
- `QM5_41089_wti-wrange-migrate-mom` compares both high and low across the two
  weekly packages and never makes the final close decisive. This candidate
  ignores newest-range migration and makes the final close versus the parent
  extremes the complete signal.

Manual repository-wide phrase and mechanic searches found no existing WTI EA
whose complete signal is the immediately completed weekly final close strictly
outside the immediately preceding weekly high-low range, followed only for the
next broker week. `QM5_41061_wti-week-nr7-brk` first requires a strict NR7
week and then waits for a close in the following in-progress week to break
that compressed range; it is neither a fixed next-week boundary decision nor
an unconditional parent-range closing breakout.

Verdict:
`NO_EXACT_DUPLICATE_FUZZY_WEEKLY_OHLC_FAMILY_MANUALLY_DISTINCT`.

Q00 still owes a fresh post-allocation identity scan and full semantic family
review. Any exact identity discovered before approval must stop allocation and
build.

## Source and claim boundary

Moskowitz, Ooi, and Pedersen (2012) is approved for the broad proposition that
an instrument's own past direction can contain continuation information and
for explicit WTI membership in the study's commodity-futures universe.
Szakmary, Shen, and Sharma (2010) is approved for the source-defined concept
that a completed commodity value outside prior completed extrema can form a
mechanical trend-following channel signal.

Neither source tests a two-week WTI weekly-closing breakout, a one-week hold,
Darwinex continuous CFDs, fixed-dollar ATR risk, or the QM portfolio. The
weekly clock, one-parent range, strict final-close comparison, energy-label
normalization, fixed risk, stop, attempt ledger, and lifecycle are transparent
QM hypotheses, not source claims.

No source return, WTI-specific alpha, profit factor, drawdown, trade count,
cost, CFD equivalence, or book-correlation statistic may transfer to the card.
Q02 owns frequency and baseline economics. Q09 alone may measure realized
portfolio correlation; Q11 alone owns portfolio admission.

## Safety boundary

This approval authorizes only complete reading of the two bounded governed
records, creation of one child source packet, and subsequent Q00
consideration. It does not authorize a manual tester run, terminal control,
live/demo/shadow/stress/optimization preset, AutoTrading action, `T_Live`
change, deploy or `T_Live`-manifest edit, portfolio-gate edit, portfolio
admission, correlation waiver, after-result parameter salvage, or a duplicate
queue row.
