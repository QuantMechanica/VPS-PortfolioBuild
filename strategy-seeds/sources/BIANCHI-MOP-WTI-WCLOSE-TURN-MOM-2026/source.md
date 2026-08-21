---
source_id: BIANCHI-MOP-WTI-WCLOSE-TURN-MOM-2026
title: WTI completed-week single-turn close-path recovery momentum
publisher: QuantMechanica governed extraction of peer-reviewed commodity research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_wti_weekly_close_turn_momentum_source_approval.md
parent_source_ids:
  - BIANCHI-MOMREV-2015
  - MOP-TSMOM-2012
parent_sha256:
  BIANCHI-MOMREV-2015: F2EA59689B0FA0AE21A0BE5689A8F965062C65055516737C5210C65F6B072752
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - wti-wclose-turn-mom
---

# WTI Completed-Week Single-Turn Close-Path Recovery Momentum

## Approved sources of record

This bounded extraction uses two governed repository records read completely
after the durable OWNER source approval was committed:

1. `strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md`, covering Robert J.
   Bianchi, Michael E. Drew, and John Hua Fan (2015), "Combining Momentum with
   Reversal in Commodity Futures," *Journal of Banking & Finance* 59,
   423-444, DOI `10.1016/j.jbankfin.2015.07.006`. The record preserves an
   end-to-end read of the 59-page institutional accepted manuscript and WTI
   crude oil as an explicit source constituent.
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, covering Tobias J.
   Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time Series
   Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The record preserves an end-to-end read of
   the 23-page published paper, a retrieval receipt and PDF hash, and NYMEX
   WTI as an explicit source constituent.

Their byte hashes are fixed in the front matter. The OWNER source approval is
`decisions/2026-08-22_wti_weekly_close_turn_momentum_source_approval.md`,
commit `854ef19f5a720e6fc4653303cef5ee549ce25696`. No new online page,
blocked content, inferred paper text, or unrecorded source is used.

## Source findings used

Bianchi, Drew, and Fan document distinct momentum and longer-horizon reversal
components in commodity futures. Moskowitz, Ooi, and Pedersen document
own-return continuation across liquid futures and include WTI in the source
universe. Together they provide reputable lineage for falsifying a completed
reversal whose final direction persists on an explicit WTI carrier.

Neither paper defines a within-week close path, strict monotone legs, a single
interior turning point, full recovery beyond the first session close, a
Darwinex continuous CFD, broker-label normalization, fixed-dollar ATR risk,
or a one-week hold. Every such choice below is a declared QM translation. No
reported source performance, significance, trade count, risk statistic, or
correlation is an expectation for this candidate.

## Bounded QM mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each normalized
Monday-anchored broker week, load the exact immediately completed week from
completed native D1 bars. Apply one configured energy-label convention
uniformly to the current and historical bars: native same-day labels or a
uniform `+1` calendar-day offset.

The completed package must be exactly seven calendar days behind the current
week anchor and contain three to five unique, strictly ordered sessions. Use
only the chronological closes `c[0] ... c[n-1]`. Require each close to be
positive and finite. No current-week open, high, low, close, return, or quote
may enter the signal.

For a long state, there must be one interior index `k`, with
`1 <= k <= n-2`, such that the close path strictly decreases into `k`, then
strictly increases after `k`, and the final close finishes strictly above the
first close:

```text
c[0] > c[1] > ... > c[k]
c[k] < c[k+1] < ... < c[n-1]
c[n-1] > c[0]
```

For a short state, require the exact mirror:

```text
c[0] < c[1] < ... < c[k]
c[k] > c[k+1] > ... > c[n-1]
c[n-1] < c[0]
```

The strict monotone legs guarantee a unique interior trough or peak. Equality
between adjacent closes, a monotone path with no interior turn, multiple
turns, an endpoint turn, a final close equal to or not beyond the first close,
invalid chronology, or malformed history is flat. Turn position, depth, and
recovery magnitude never alter size.

## Exact event, risk, and lifecycle contract

- host and traded symbol: exact `XTIUSD.DWX` only;
- period: exact D1 only;
- decision: first executable tick of a new normalized broker week, within 180
  elapsed minutes of the raw current D1 bar open;
- signal data: every chronological close from the exact immediately completed
  three-to-five-session week only;
- attempt: persist the normalized Monday anchor before history, signal, news,
  spread, quote, ATR, sizing, or order gates; never retry that week;
- exposure: at most one owned position and one entry deal per week;
- backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`;
- hard stop: frozen `3.5*ATR(20,D1)` from the completed D1 bar;
- take-profit: none;
- maximum entry spread: 1,500 WTI points;
- news axes and Friday close: OFF/NONE and OFF;
- normal exit: first tick carrying a later normalized Monday anchor;
- stale repair: ten elapsed calendar days after entry; and
- no retry, reversal-in-place, target, trail, break-even move, partial close,
  scale-in, grid, martingale, pyramid, or external runtime data.

## Non-duplicate boundary

The fail-closed pre-allocation checker scanned 4,588 registry identities and
1,267 cards and found no exact or fuzzy match. The optional Strategy-Wiki root
was unavailable, so the receipt honestly remains `INPUT_ERROR_FAIL_CLOSED`:
`artifacts/qm5_wti_wclose_turn_mom_preallocation_dedup_20260822.json`.

Manual family review establishes a distinct information object:

- `QM5_41098_wti-wextreme-sequence-mom` uses the chronological order of the
  sessions carrying the aggregate weekly high and low, then checks the weekly
  open-to-close sign. This extraction never reads opens, highs, or lows and
  requires every session close to participate in a strict single-turn path.
- `QM5_41084_wti-wdaybreadth-mom` counts five adjacent D1 return signs and
  requires four-of-five breadth plus a parent-to-final weekly net sign. This
  extraction has no sign count or parent close: a multi-turn path is flat even
  when four returns share one sign.
- `QM5_41092_wti-wbody-dominance-mom` compares an aggregate body with a
  weekly high-low range. This extraction computes no weekly body or range.
- `QM5_41095_wti-wexcursion-imbalance-mom` and
  `QM5_41096_wti-wexcursion-reject-rv` compare high/open and open/low
  excursions at a strict ratio. This extraction is invariant to the open and
  intraday extremes.
- `QM5_41065`, `QM5_41068` through `QM5_41072`, `QM5_41074`, and
  `QM5_41082` classify paths across multiple completed weekly returns. This
  extraction classifies the within-week close sequence of one completed week.
- `QM5_41029`, `QM5_41032`, and `QM5_41033` decompose overnight and
  intraday flow. This extraction reads no open and performs no gap/body
  decomposition.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback below a slow mean. This extraction is symmetric direct
  WTI, weekly, and oscillator-free.

The exact carrier, completed-week membership, every chronological close, one
strict interior turn, strict monotone legs, full endpoint recovery, boundary
entry, durable attempt, fixed risk, and next-week exit are jointly
load-bearing.

## Reputable-source criteria

- R1: `PASS_WITH_WEEKLY_CLOSE_PATH_TRANSLATION_RISK`. Both primary records
  cover named-author peer-reviewed DOI papers with complete reads and explicit
  WTI membership. The exact close-path conjunction is untested.
- R2: `PASS`. Label convention, anchor, session count, chronology, strict
  inequalities, unique interior turn, recovery side, attempt, fixed risk,
  stop, spread, and lifecycle are deterministic.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered native
  `XTIUSD.DWX` D1 history and MT5 state supply every runtime input. Q02 owns
  label, density, fill, cost, and continuous-CFD falsification.
- R4: `PASS`. Runtime inputs are timestamps, completed closes, comparisons,
  ATR, spread, quote, position/deal history, and terminal state only; no
  banned signal, trained output, external feed, adaptive fitting, grid,
  martingale, scale-in, or pyramid exists.

## Claim, kill, and safety boundary

Expected cadence is approximately six to eighteen completed positions per
full post-warm-up year. This is a design prior only. Q02 must measure cadence
and baseline economics and retire any full scored year below five trades,
zero-trade result, nonpositive economics, or implementation defect. Q09 alone
may measure realized portfolio correlation.

No failure may be rescued by accepting adjacent equality, an endpoint or
multiple turns, incomplete recovery, reversing the side, changing the hold,
or adding a turn-depth, return, range, body, wick, close-location, trend,
calendar, volatility, volume, event, inventory, moving-average, oscillator,
external series, or prior-result filter.

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live Q02 enqueue only. It does not authorize a manual backtest,
live/demo/shadow/stress/optimization preset, terminal control, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio-gate change, portfolio
admission, correlation waiver, or decorrelation claim.
