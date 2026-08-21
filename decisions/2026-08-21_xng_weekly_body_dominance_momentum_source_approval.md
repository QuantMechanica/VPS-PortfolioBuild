# XNG weekly body-dominance momentum source approval

Date: 2026-08-21

Decision: `APPROVED_SOURCE`

## Authority and scope

The current explicit OWNER instruction delivered to Codex on branch
`agents/board-advisor` authorizes one new structural, low-frequency
commodity/energy edge outside the certified XAU/SP500/NDX/XNG book. It
explicitly permits a second `XNGUSD` candidate only when its logic differs
from certified `QM5_12567`, and requires a reputable-source record, one QM
card and build, `RISK_FIXED` backtest configuration, one paced Q02 handoff,
branch-only commits, and no `T_Live`, AutoTrading, portfolio-gate, or
`T_Live`-manifest changes.

This decision approves source intake for one bounded candidate:

- planned source ID: `MOP-XNG-WBODY-DOMINANCE-MOM-2026`;
- planned strategy ID: `MOP-XNG-WBODY-DOMINANCE-MOM-2026_S01`;
- planned slug: `xng-wbody-dominance-mom`;
- instrument and clock: exact `XNGUSD.DWX`, D1, evaluated once at the first
  tradable bar of a new normalized Monday-anchored broker week; and
- governed source record to read completely before extraction:
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

This is source approval only. It does not approve a Strategy Card, allocate
an EA ID or magic number, authorize a build, establish efficacy or
decorrelation, waive a Q gate, or authorize live use.

## Candidate mechanic authorized for extraction

Aggregate the immediately completed broker week from native natural-gas D1
OHLC. The package must contain three to five unique, strictly ordered
sessions and must be the exact week immediately preceding the current
decision week. Current-week OHLC is excluded.

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
- Threshold equality, body equality, invalid geometry, malformed history,
  or an incomplete package stays flat.

The intended baseline follows that completed directional auction for exactly
one broker week, with one durable attempt, one fixed-risk position, a frozen
completed-bar ATR hard stop, no target, and no external runtime data. The
source read and Q00 process must lock the exact label, session, risk,
lifecycle, and falsification contracts before build.

## Preliminary non-duplicate boundary

The canonical fail-closed pre-allocation checker scanned 4,583 EA-registry
identities and 1,263 repository cards. Its configured optional Strategy-Wiki
root was unavailable, so the checker correctly returned a non-clean
`FUZZY_MATCH` result instead of silently treating that source as empty. This
input limitation is retained here and is supplemented by repository-wide
exact and semantic review; it is not restated as a clean automated verdict.

The checker surfaced `QM5_41092_wti-wbody-dominance-mom` as the closest fuzzy
relative because it deliberately applies the same falsifiable weekly auction
test to WTI. That is a carrier-family relative, not an existing XNG build.
Repository-wide search found no existing XNG or natural-gas EA whose complete
signal is a strict two-thirds completed-week real-body share followed for one
week. The load-bearing manual distinctions are:

- `QM5_41092_wti-wbody-dominance-mom` trades exact `XTIUSD.DWX`. The proposed
  identity trades exact `XNGUSD.DWX`; symbol, history, volatility, seasonality,
  gap/roll behavior, spread limit, and resulting return stream are separate
  test subjects. The proposal is not a second ID on the same carrier.
- `QM5_41081_xng-wclose-location-mom` requires a parent-to-newest weekly close
  direction plus the newest close in its own outer fifth. It never reads the
  newest weekly open and does not require a dominant real body.
- `QM5_41067_xng-wflip-mom` classifies a two-week return-sign flip. It does not
  aggregate or threshold one completed weekly real body.
- `QM5_41063_xng-week-nr7-brk` ranks seven completed ranges and waits for a
  later in-progress-week breakout. The proposal has no range rank or current-
  week signal price and decides only at a weekly boundary.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-
  RSI2 pullback below a slow mean. The proposal is symmetric long/short,
  weekly, price-action continuation with no oscillator or moving average.
- generic marubozu/candlestick identities use intraday bars, wick limits,
  trend filters, targets, or different multi-symbol contracts. None is the
  exact XNG completed-week aggregate and next-week lifecycle proposed here.

Q00 still owes a fresh post-allocation identity scan and exact repository
self-hit review. Any pre-existing XNG identity discovered before approval
must stop allocation and build.

## Source and claim boundary

Moskowitz, Ooi, and Pedersen (2012) is approved as lineage for the broad
proposition that an asset's own past price direction can contain continuation
information and for explicit natural-gas membership in the governed source's
commodity-futures universe. The authors do not test weekly aggregate candle
bodies, a two-thirds body/range condition, Darwinex continuous CFDs, fixed
cash risk, an ATR stop, or a one-week hold. Those are transparent QM
hypotheses, not source claims.

No source return, natural-gas-specific alpha, profit factor, drawdown, trade
count, cost, CFD equivalence, neutrality, or book-correlation statistic may
transfer to the card. Q02 owns frequency and baseline economics. Q09 alone
may measure realized portfolio correlation; Q11 alone owns portfolio
admission.

## Safety boundary

This approval authorizes only complete reading of the bounded governed
source, creation of one child source packet, and subsequent Q00
consideration. It does not authorize a manual tester run, terminal control,
live/demo/shadow/stress/optimization preset, AutoTrading action, `T_Live`
change, deploy or `T_Live`-manifest edit, portfolio-gate edit, portfolio
admission, correlation waiver, after-result parameter salvage, or a duplicate
queue row.
