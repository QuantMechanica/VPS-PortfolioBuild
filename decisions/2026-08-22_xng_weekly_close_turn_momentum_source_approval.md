# XNG weekly close-turn recovery momentum source approval

Date: 2026-08-22

Decision: `APPROVED_SOURCE`

## Authority and bounded scope

The current explicit OWNER instruction delivered to Codex on branch
`agents/board-advisor` authorizes one new structural, low-frequency
commodity/energy edge outside the certified XAU/SP500/NDX/XNG book. It
explicitly permits a second `XNGUSD` edge when its logic differs from
`QM5_12567`, requires a reputable-source record, one QM card and build,
`RISK_FIXED` backtest configuration, and one paced Q02 enqueue, and forbids
`T_Live`, AutoTrading, portfolio-gate, and `T_Live`-manifest changes.

This decision approves source intake for one bounded candidate:

- planned source ID: `BIANCHI-MOP-XNG-WCLOSE-TURN-MOM-2026`;
- planned strategy ID:
  `BIANCHI-MOP-XNG-WCLOSE-TURN-MOM-2026_S01`;
- planned slug: `xng-wclose-turn-mom`;
- carrier and clock: exact `XNGUSD.DWX`, D1, evaluated once at the first
  tradable bar of a new normalized Monday-anchored broker week; and
- governed source records read completely before this approval:
  - `strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md`, SHA-256
    `F2EA59689B0FA0AE21A0BE5689A8F965062C65055516737C5210C65F6B072752`;
  - `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
    `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The first record covers Robert J. Bianchi, Michael E. Drew, and John Hua Fan
(2015), "Combining Momentum with Reversal in Commodity Futures,"
*Journal of Banking & Finance* 59, 423-444, DOI
`10.1016/j.jbankfin.2015.07.006`, with an end-to-end read of the 59-page
accepted manuscript. The second covers Tobias J. Moskowitz, Yao Hua Ooi, and
Lasse Heje Pedersen (2012), "Time Series Momentum," *Journal of Financial
Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, with an
end-to-end read of the published 23-page paper and a durable PDF hash. Both
governed records identify natural gas as a source-universe commodity.

This is source approval only. It does not approve a Strategy Card, allocate
an EA ID or magic, authorize live use, establish efficacy or decorrelation,
or waive any deterministic Q gate.

## Candidate mechanic authorized for extraction

On the first tradable `XNGUSD.DWX` D1 bar of a new normalized broker week,
load the exact immediately completed Monday-anchored broker week. Require
exact seven-calendar-day adjacency, three to five unique and strictly ordered
valid sessions, one uniform energy-label convention, and no current-week
signal data.

Let `c[0] ... c[n-1]` be the completed sessions' closes in chronological
order. Trade only one strict interior close-path turn that fully recovers past
the first close:

```text
there is one k, 1 <= k <= n-2, such that
c[0] > c[1] > ... > c[k] < c[k+1] < ... < c[n-1]
and c[n-1] > c[0]                                      => BUY XNGUSD.DWX

there is one k, 1 <= k <= n-2, such that
c[0] < c[1] < ... < c[k] > c[k+1] > ... > c[n-1]
and c[n-1] < c[0]                                      => SELL XNGUSD.DWX

otherwise                                               => FLAT
```

Strict monotone segments make the interior trough or peak unique. Equality
between adjacent closes, an endpoint turn, more than one turn, incomplete
recovery, malformed or nonadjacent history, or invalid prices remain flat.
Turn depth, recovery magnitude, and turn index never change size.

The intended baseline follows the completed recovery direction for exactly
one broker week. It consumes one durable weekly attempt, uses one fixed-risk
position with a frozen completed-bar ATR hard stop and no target, and reads no
external runtime data. Q00 must lock the exact labels, chronology, risk,
lifecycle, and falsification rules before any build.

## Preliminary non-duplicate boundary

The canonical fail-closed pre-allocation checker scanned 4,589 EA-registry
identities, 1,268 repository cards, and 45 Strategy-Wiki nodes. It returned
the expected fuzzy carrier-sibling hit on
`QM5_41099_wti-wclose-turn-mom` and no exact identity hit. The machine-readable
receipt is
`artifacts/qm5_xng_wclose_turn_mom_preallocation_dedup_20260822.json`.

Manual review classifies the fuzzy hit as a separately authorized carrier
falsification rather than an in-place WTI revision. The current OWNER mission
explicitly permits a second XNG strategy when its logic differs from
`QM5_12567`; the registry precedent `QM5_41080`/`QM5_41081` likewise assigns
separate identities to predeclared WTI and XNG carriers of one completed-week
mechanic. No WTI result transfers, and the XNG history, cost, density, basis,
and book overlap are independently falsified.

The load-bearing distinctions from existing XNG work are:

- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-
  RSI2 pullback below a slow mean with a five-bar maximum hold. This candidate
  is symmetric, oscillator-free, evaluates one complete week, and holds to
  the next weekly boundary.
- `QM5_41081_xng-wclose-location-mom` uses two completed weekly packages, a
  parent-to-new close return sign, and the newest week's high-low close
  location. This candidate reads one week's chronological closes only, never
  reads highs or lows, and requires a strict single-turn/full-recovery path.
- `QM5_41094_xng-wbody-dominance-mom` compares aggregate weekly body size
  with high-low range. This candidate has no body-share threshold and is
  invariant to weekly opens and intraday extremes.
- `QM5_41067_xng-wflip-mom` classifies two adjacent week-end return signs.
  This candidate uses one within-week session-close path and no older weekly
  return.
- `QM5_41063_xng-week-nr7-brk` ranks seven weekly ranges and waits for a
  current-week breakout. This candidate ranks nothing and excludes every
  current-week price from its signal.
- `QM5_41099_wti-wclose-turn-mom` is the exact WTI carrier sibling. The XNG
  carrier is the only expected fuzzy match and creates no performance prior.

The exact XNG carrier, one immediately completed three-to-five-session week,
every chronological session close, one strict interior turn, strict monotone
legs, final-close recovery beyond the first close, boundary entry, durable
attempt, fixed risk, and next-week exit are jointly load-bearing. Q00 still
owes a post-allocation identity scan; any second XNG implementation found
before approval stops the build.

## Source and claim boundary

Bianchi, Drew, and Fan supply peer-reviewed evidence that commodity returns
can contain distinct momentum and longer-horizon reversal components.
Moskowitz, Ooi, and Pedersen supply peer-reviewed own-return continuation
evidence. Natural gas is present in both governed source universes.

Neither source tests a within-week single-turn close path, strict monotone
segments, full endpoint recovery, a weekly XNG-only rule, Darwinex continuous
CFDs, broker-label normalization, fixed cash risk, an ATR stop, or a one-week
hold. Those are transparent QM hypotheses. No source return, XNG-only alpha,
frequency, profit factor, drawdown, cost, CFD equivalence, or portfolio-
correlation result may transfer.

## Reputable-source criteria

- R1 `PASS_WITH_WEEKLY_CLOSE_PATH_TRANSLATION_RISK`: both lineages are
  named-author, peer-reviewed DOI sources with complete manuscript reads and
  explicit natural-gas membership. The single-turn/full-recovery conjunction
  is explicitly untested.
- R2 `PASS`: carrier, uniform label convention, week anchor, session count,
  close ordering, strict inequalities, unique interior turn, recovery side,
  attempt, fixed risk, spread, hard stop, and lifecycle must be mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XNGUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  label, density, fill, cost, and continuous-CFD falsification.
- R4 `PASS`: timestamps, completed closes, comparisons, ATR, quotes,
  positions, deals, and terminal state only; no banned indicator, trained
  output, external feed, adaptive fit, grid, martingale, scale-in, or pyramid.

## Falsification and safety boundary

Expected cadence is approximately six to eighteen completed positions per
full post-warm-up year. Q02 must retire a full scored year below five trades,
zero trades, nonpositive governed economics, or any label, anchor, session,
chronology, strict-turn, recovery, direction, attempt, risk, lifecycle, or
determinism defect. A weak result may not be rescued by accepting equality,
endpoint or multiple turns, incomplete recovery, changing the hold, or
adding a turn-depth, return, range, body, wick, close-location, calendar,
volatility, volume, moving-average, oscillator, event, inventory, or external-
data filter.

This approval authorizes only extraction of one complete bounded child source
packet and subsequent Q00 consideration. It does not authorize a manual
backtest, terminal control, live/demo/shadow/stress/optimization preset,
AutoTrading, `T_Live`, deploy or `T_Live` manifest, portfolio-gate change,
portfolio admission, correlation waiver, after-result salvage, or a duplicate
queue row.
