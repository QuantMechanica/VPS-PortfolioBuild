# WTI weekly body-dominance momentum source approval

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

- planned source ID: `MOP-WTI-WBODY-DOMINANCE-MOM-2026`;
- planned strategy ID: `MOP-WTI-WBODY-DOMINANCE-MOM-2026_S01`;
- planned slug: `wti-wbody-dominance-mom`;
- instrument and clock: exact `XTIUSD.DWX`, D1, evaluated once at the first
  tradable bar of a new Monday-anchored broker week; and
- governed source record to read completely before extraction:
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

This is source approval only. It does not approve a Strategy Card, allocate an
EA ID or magic number, authorize a build, establish efficacy or decorrelation,
waive any Q gate, or authorize live use.

## Candidate mechanic authorized for extraction

Aggregate the immediately completed broker week from native WTI D1 OHLC. The
package must contain three to five unique, strictly ordered sessions and must
be the exact week immediately preceding the current decision week. The current
decision week is excluded.

Define the completed-week range and absolute real body:

```text
week_range = week_high - week_low
week_body  = abs(week_close - week_open)
```

Require strict body dominance without a fitted decimal threshold:

```text
3 * week_body > 2 * week_range
```

- BUY only when the strict body-dominance condition holds and the completed
  week closes strictly above its first-session open.
- SELL only when it holds and the completed week closes strictly below its
  first-session open.
- Threshold equality, body equality, invalid geometry, malformed history, or
  an incomplete package stays flat.

The intended baseline follows that completed directional auction for exactly
one broker week, with one durable attempt, one fixed-risk position, a frozen
completed-bar ATR hard stop, no target, and no external runtime data. The
source read and Q00 process must lock the exact label, session, risk,
lifecycle, and falsification contracts before build.

## Preliminary non-duplicate boundary

The canonical fail-closed pre-allocation checker used the complete mechanic,
the actual Company Reference Wiki root, and author lineage. It scanned 4,581
EA-registry identities, 1,254 repository cards, and 45 Strategy Wiki nodes and
returned `CLEAN`, with no exact or fuzzy match.

Manual intake review found no existing WTI EA with the jointly load-bearing
combination of one completed weekly OHLC package, a strict two-thirds real-body
share, its own body direction, boundary entry, and one-week hold:

- `QM5_41080_wti-wclose-location-mom` uses the parent close to newest close
  and an outer-fifth close location. It does not read the newest weekly open
  or require its real body to dominate the range.
- `QM5_41087_wti-wr4-close-mom` ranks four completed weekly ranges and follows
  a narrow week's parent-to-newest close return. This candidate has no range
  rank, parent close, or compression condition.
- `QM5_41089_wti-wrange-migrate-mom` requires both weekly high and low to
  migrate in one direction across two weeks. This candidate uses one completed
  week and is invariant to the parent range endpoints.
- `QM5_41090_wti-wmid-overlap-mom` requires two positively overlapping weekly
  ranges and compares their high-low midpoints while excluding opens and
  closes. This candidate requires neither a parent nor overlap and uses the
  completed week's open and close as load-bearing endpoints.
- `QM5_41091_wti-winside-body-mom` requires strict containment inside a parent
  week before following the contained week's body. This candidate has no
  parent geometry condition and instead requires the body itself to occupy
  more than two-thirds of the completed range.
- `QM5_9413_mql5-paq-marubozu` trades H1 bars across a different multi-symbol
  identity with a 90% body, separate wick limits, ATR range and EMA filters,
  target, and dynamic exits. This candidate aggregates an exact WTI broker
  week, has no wick-specific, EMA, or range-size filter, and time-exits at the
  next weekly boundary.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG cumulative-RSI2
  pullback under a slow trend filter on a different carrier.

Q00 still owes a fresh post-allocation identity scan and full semantic family
review. Any exact identity discovered before approval must stop allocation and
build.

## Source and claim boundary

Moskowitz, Ooi, and Pedersen (2012) is approved as the sole lineage source for
the broad proposition that an asset's own past price direction can carry
continuation information; the governed record states that WTI crude-oil
futures are in the paper's commodity universe. The authors do not test weekly
aggregate candle bodies, a two-thirds body/range condition, Darwinex
continuous CFDs, fixed cash risk, an ATR stop, or a one-week hold. Those are
transparent QM hypotheses, not source claims.

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
