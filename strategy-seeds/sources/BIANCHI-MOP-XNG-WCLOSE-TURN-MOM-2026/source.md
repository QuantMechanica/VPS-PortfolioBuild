---
source_id: BIANCHI-MOP-XNG-WCLOSE-TURN-MOM-2026
title: XNG completed-week single-turn close-path recovery momentum
publisher: QuantMechanica governed extraction of peer-reviewed commodity research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_xng_weekly_close_turn_momentum_source_approval.md
parent_source_ids:
  - BIANCHI-MOMREV-2015
  - MOP-TSMOM-2012
parent_sha256:
  BIANCHI-MOMREV-2015: F2EA59689B0FA0AE21A0BE5689A8F965062C65055516737C5210C65F6B072752
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - xng-wclose-turn-mom
---

# XNG Completed-Week Single-Turn Close-Path Recovery Momentum

## Approved sources of record

This bounded extraction uses two governed repository records read completely
after the durable OWNER source approval was written:

1. `strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md`, covering Robert J.
   Bianchi, Michael E. Drew, and John Hua Fan (2015), "Combining Momentum with
   Reversal in Commodity Futures," *Journal of Banking & Finance* 59,
   423-444, DOI `10.1016/j.jbankfin.2015.07.006`. The record preserves an
   end-to-end read of the 59-page institutional accepted manuscript and
   natural gas as an explicit source constituent.
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, covering Tobias J.
   Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time Series
   Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The record preserves an end-to-end read of
   the 23-page published paper, a retrieval receipt and PDF hash, and natural
   gas as an explicit source-universe commodity.

Their byte hashes are fixed in the front matter. The OWNER source approval is
`decisions/2026-08-22_xng_weekly_close_turn_momentum_source_approval.md`.
Its approval commit is `e0fd6935a`. No new online page, blocked content,
inferred paper text, or unrecorded source is used.

## Source findings used

Bianchi, Drew, and Fan document distinct momentum and longer-horizon reversal
components in commodity futures. Moskowitz, Ooi, and Pedersen document
own-return continuation across liquid futures and include natural gas in the
source universe. Together they provide reputable lineage for falsifying a
completed reversal whose final direction persists on an explicit XNG
carrier.

Neither paper defines a within-week close path, strict monotone legs, a single
interior turning point, full recovery beyond the first session close, a
Darwinex continuous CFD, broker-label normalization, fixed-dollar ATR risk,
or a one-week hold. Every such choice below is a declared QM translation. No
reported source performance, significance, trade count, risk statistic, or
correlation is an expectation for this candidate.

## Bounded QM mechanization

On the first tradable `XNGUSD.DWX` D1 bar of each normalized Monday-anchored
broker week, load the exact immediately completed week from completed native
D1 bars. Apply one configured energy-label convention uniformly to the
current and historical bars: native same-day labels or a uniform `+1`
calendar-day offset.

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

Strict monotone legs guarantee a unique interior trough or peak. Equality
between adjacent closes, a monotone path with no interior turn, multiple
turns, an endpoint turn, a final close equal to or not beyond the first close,
invalid chronology, or malformed history is flat. Turn position, depth, and
recovery magnitude never alter size.

## Exact event, risk, and lifecycle contract

- host and traded symbol: exact `XNGUSD.DWX` only;
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
- maximum entry spread: 1,500 XNG points;
- news axes and Friday close: OFF/NONE and OFF;
- normal exit: first tick carrying a later normalized Monday anchor;
- stale repair: ten elapsed calendar days after entry; and
- no retry, reversal-in-place, target, trail, break-even move, partial close,
  scale-in, grid, martingale, pyramid, or external runtime data.

## Non-duplicate boundary

The fail-closed pre-allocation checker scanned 4,589 registry identities,
1,268 cards, and 45 Strategy-Wiki nodes. It returned only the expected fuzzy
WTI carrier sibling; the evidence is
`artifacts/qm5_xng_wclose_turn_mom_preallocation_dedup_20260822.json`.

Manual family review establishes a distinct XNG information object:

- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback
  below a slow mean with a five-bar maximum hold. This extraction is
  symmetric, oscillator-free, weekly, and follows a completed recovery.
- `QM5_41081_xng-wclose-location-mom` uses two completed weekly packages,
  parent-to-new return sign, and high-low close location. This extraction
  uses one week, only its chronological closes, and a strict single turn.
- `QM5_41094_xng-wbody-dominance-mom` reads the weekly open and high-low range
  to impose a body-share condition. This extraction reads neither the weekly
  open nor intraday extremes.
- `QM5_41067_xng-wflip-mom` compares two adjacent weekly return signs. This
  extraction compares adjacent sessions within one completed week and reads
  no older week-end return.
- `QM5_41063_xng-week-nr7-brk` ranks seven weekly ranges and uses a
  current-week breakout. This extraction has no rank or current-week signal.
- `QM5_41099_wti-wclose-turn-mom` is the exact WTI carrier sibling. The
  current OWNER mission and the established WTI/XNG carrier-pair precedent
  authorize a separate XNG falsification; no WTI result transfers.

The exact XNG carrier, one immediately completed three-to-five-session week,
every chronological session close, one strict interior turning point, strict
monotone legs, final-close recovery beyond the first close, equality/no-turn/
multi-turn/incomplete-recovery-flat behavior, first-new-week entry, durable
attempt, fixed risk, and next-week exit are jointly load-bearing.

## Reputable-source criteria

- R1: `PASS_WITH_WEEKLY_CLOSE_PATH_TRANSLATION_RISK`. Two named-author,
  peer-reviewed DOI sources have complete-read evidence and explicit natural-
  gas membership; the weekly close-path conjunction is disclosed as untested.
- R2: `PASS`. Exact carrier, label, anchor, session chronology, strict turn,
  recovery, side, attempt, spread, stop, risk, and lifecycle are fixed.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XNGUSD.DWX` D1 history plus native MT5 state supplies every runtime input.
- R4: `PASS`. Runtime uses timestamps, completed closes, comparisons, ATR,
  quotes, and native trade state only; no trained model, banned signal,
  external feed, grid, martingale, scale-in, or pyramid.

## Claim, kill, and safety boundary

The sources motivate a falsifiable commodity continuation hypothesis; they do
not establish efficacy for this XNG weekly rule. Expected cadence is six to
eighteen completed positions per full post-warm-up year. Q02 must retire below
five trades per year, on zero trades or nonpositive governed economics, or on
any label, chronology, direction, attempt, risk, lifecycle, or determinism
defect. Q09 alone may establish realized portfolio correlation.

No failure may be rescued by accepting equality, endpoint or multiple turns,
incomplete recovery, reversing the side, changing the hold, or adding a depth,
return, range, body, wick, close-location, calendar, volatility, volume,
moving-average, oscillator, inventory, event, or external-data filter.

This packet supports one Q00 card, branch-only non-live build, Q01 validation,
fixed-risk backtest preset, and one paced target-only Q02 enqueue below the
tester and host-CPU ceilings. It does not authorize a manual backtest,
terminal control, live artifact, `T_Live`, AutoTrading, deploy manifest,
portfolio-gate change, portfolio admission, correlation waiver, or
decorrelation claim.
