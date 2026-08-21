# WTI weekly excursion-imbalance momentum source approval

Date: 2026-08-21

Decision: `APPROVED_SOURCE`

## Authority and scope

The current explicit OWNER instruction delivered to Codex on branch
`agents/board-advisor` authorizes one new structural, low-frequency
commodity/energy edge outside the certified XAU/SP500/NDX/XNG book. It
requires a reputable-source record, one QM card and build, `RISK_FIXED`
backtest configuration, one paced Q02 handoff, branch-only commits, and no
`T_Live`, AutoTrading, portfolio-gate, or `T_Live`-manifest changes.

This decision approves source intake for one bounded candidate:

- planned source ID: `MOP-WTI-WEXCURSION-IMBALANCE-MOM-2026`;
- planned strategy ID: `MOP-WTI-WEXCURSION-IMBALANCE-MOM-2026_S01`;
- planned slug: `wti-wexcursion-imbalance-mom`;
- instrument and clock: exact `XTIUSD.DWX`, D1, evaluated once at the first
  tradable bar of a new normalized Monday-anchored broker week; and
- governed source record read completely before extraction:
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
  `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

This is source approval only. It does not approve a Strategy Card, allocate
an EA ID or magic number, authorize a build, establish efficacy or
decorrelation, waive a Q gate, or authorize live use.

## Candidate mechanic authorized for extraction

Aggregate the immediately completed broker week from native WTI D1 OHLC.
The package must contain three to five unique, strictly ordered sessions and
must be the exact week immediately preceding the current decision week.
Current-week OHLC is excluded.

Define the completed week's open-centred directional excursions:

```text
up_excursion   = week_high - week_open
down_excursion = week_open - week_low
```

Require strict two-to-one excursion imbalance plus settlement agreement:

```text
up_excursion > 2 * down_excursion and week_close > week_open
    => BUY XTIUSD.DWX

down_excursion > 2 * up_excursion and week_close < week_open
    => SELL XTIUSD.DWX

otherwise
    => FLAT
```

Ratio equality, close/open equality, excursion/settlement disagreement,
invalid geometry, malformed history, or an incomplete package stays flat.
Excursion magnitude beyond qualification never changes the risk budget.

The intended baseline follows that completed directional auction for exactly
one broker week, with one durable attempt, one fixed-risk position, a frozen
completed-bar ATR hard stop, no target, and no external runtime data. The
source read and Q00 process must lock the exact label, session, risk,
lifecycle, and falsification contracts before build.

## Preliminary non-duplicate boundary

The canonical fail-closed pre-allocation checker scanned 4,584 EA-registry
identities and 1,264 repository cards. Its configured optional Strategy-Wiki
root was unavailable, so the checker correctly returned a non-clean
`FUZZY_MATCH` result instead of silently treating that source as empty. This
input limitation is retained here and supplemented by repository-wide exact
and semantic review; it is not restated as a clean automated verdict.

The checker surfaced `QM5_41092_wti-wbody-dominance-mom`, its XNG carrier
sibling `QM5_41094`, and `QM5_41089_wti-wrange-migrate-mom` as fuzzy relatives.
Repository-wide search found no WTI EA whose complete signal is a strict
open-centred weekly directional-excursion imbalance with matching settlement
sign. The load-bearing manual distinctions are:

- `QM5_41092_wti-wbody-dominance-mom` compares absolute weekly close/open
  body with the full range. It can qualify without either open-centred
  excursion being twice the other. The proposal compares `high-open` with
  `open-low`; body magnitude is irrelevant beyond settlement sign.
- `QM5_41089_wti-wrange-migrate-mom` compares both aggregate extremes across
  two consecutive weeks. The proposal is invariant to every parent-week
  value and classifies one completed week around its own first-session open.
- `QM5_41080_wti-wclose-location-mom` compares a parent close with the newest
  close and requires an outer-fifth close location. The proposal has no
  parent return and no close-location threshold.
- `QM5_41093_wti-wclose-breakout-mom` requires a newest close beyond a prior
  multi-week closing extreme. The proposal reads no prior closing channel.
- `QM5_41073_wti-woutside-settle` requires an outside parent range and a
  settlement beyond the parent extreme. The proposal has no parent geometry.
- generic marubozu, wick, hammer, or candlestick identities operate on
  different bar periods and add body, wick, trend, oscillator, target, or
  dynamic-exit contracts. None is the exact WTI weekly aggregate proposed.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  cumulative-RSI2 pullback below a slow mean. The proposal is direct WTI,
  symmetric long/short, weekly, and oscillator-free.

Q00 still owes a fresh post-allocation identity scan and exact repository
self-hit review. Any pre-existing exact WTI identity discovered before
approval must stop allocation and build.

## Source and claim boundary

Moskowitz, Ooi, and Pedersen (2012) is approved as lineage for the broad
proposition that an asset's own past price direction can contain continuation
information and for explicit WTI membership in the governed source's
commodity-futures universe. The authors do not test weekly aggregate
open-centred excursions, a two-to-one imbalance condition, Darwinex
continuous CFDs, fixed cash risk, an ATR stop, or a one-week hold. Those are
transparent QM hypotheses, not source claims.

No source return, WTI-specific alpha, profit factor, drawdown, trade count,
cost, CFD equivalence, neutrality, or book-correlation statistic may transfer
to the card. Q02 owns frequency and baseline economics. Q09 alone may measure
realized portfolio correlation; Q11 alone owns portfolio admission.

## Safety boundary

This approval authorizes only complete reading of the bounded governed
source, creation of one child source packet, and subsequent Q00
consideration. It does not authorize a manual tester run, terminal control,
live/demo/shadow/stress/optimization preset, AutoTrading action, `T_Live`
change, deploy or `T_Live`-manifest edit, portfolio-gate edit, portfolio
admission, correlation waiver, after-result parameter salvage, or a duplicate
queue row.
