---
source_id: MOP-ZHAO-WTI-WDUAL-MOM-2026
title: WTI split-week dual-segment momentum
source_type: governed_composite_research_packet
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-16_wti_week_dual_momentum_source_approval.md
approval_commit: 354986d94
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-16
created: 2026-08-16
created_by: Research+Development
strategy_ids: [MOP-ZHAO-WTI-WDUAL-MOM-2026_S01]
parent_sources:
  - MOP-TSMOM-2012
  - 28681f5d-aa78-584e-9698-750d1402e485
---

# WTI Split-Week Dual-Segment Momentum Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet combines two governed source records read completely
before extraction:

1. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete 23-page published-paper
   review and author-hosted retrieval SHA-256
   `7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`
   are preserved at `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.
   The paper supplies the own-completed-return-sign continuation family and
   explicitly lists NYMEX WTI in its commodity-futures universe.
2. Shen Zhao, Yiyi Ding, Jianfeng Yu, and Wenjin Kang (2026), "Momentum and
   Reversal on the Short-Term Horizon: Evidence from Commodity Markets,"
   SSRN 6425598, DOI `10.2139/ssrn.6425598`. The complete accessible bounded
   packet is
   `strategy-seeds/sources/28681f5d-aa78-584e-9698-750d1402e485/source.md`;
   the complete governed research note is
   `D:/QM/strategy_farm/artifacts/source_notes/28681f5d-aa78-584e-9698-750d1402e485.md`.
   Its accessible abstract and methodology material report positive
   next-week prediction from the residual component of weekly commodity
   returns. The full paper was inaccessible, so no table, coefficient,
   performance statistic, or parameter is inferred.

Moskowitz, Ooi, and Pedersen test monthly rolled-futures excess-return rules,
not this weekly rule. Zhao et al. use an investor-position decomposition that
is unavailable to the QM runtime, not a price-only split-week agreement
state. Neither source establishes a WTI-only result, continuous-CFD transfer,
fixed Monday entry, Friday exit, costs, fixed-dollar sizing, ATR stop, or
portfolio decorrelation.

## Bounded Mechanization

`MOP-ZHAO-WTI-WDUAL-MOM-2026_S01` tests one predeclared price-only weekly
continuation package:

- carrier: exact `XTIUSD.DWX`, D1, magic slot 0;
- decision: first executable Monday D1 tick within 180 minutes of the raw D1
  session timestamp;
- history: the exact six completed normalized bars ending on the prior
  Friday and beginning on the Friday before that;
- opening segment: `log(PriorTuesdayClose / PrecedingFridayClose)`;
- closing segment: `log(PriorFridayClose / PriorTuesdayClose)`;
- direction: BUY only when both are positive, SELL only when both are
  negative, otherwise consume the week flat;
- lifecycle: one attempt per exact broker Monday and framework Friday close;
- risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, one frozen
  `3.5 * ATR(20,D1)` stop, no target, and a 1,500-point spread ceiling.

The two intervals are disjoint except for their shared completed Tuesday
endpoint. The current Monday price enters neither signal. The exact normalized
weekday sequence must be Friday, Thursday, Wednesday, Tuesday, Monday,
Friday, with calendar offsets 3, 4, 5, 6, 7, and 10 days before the decision
Monday. A holiday-broken sequence is not shifted or repaired.

The split, agreement filter, clock, label normalization, restart grace,
continuous-CFD carrier, hard stop, spread cap, fixed risk, attempt ledger, and
Friday exit are disclosed QM translations. No source result transfers.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_AND_ACCESS_RISK`: the primary lineage is a named,
  peer-reviewed JFE paper with DOI, complete-paper review, retrieval hash, and
  explicit WTI membership. A named 2026 SSRN paper supplies bounded weekly-
  commodity context; its inaccessible full text and the untested split-week
  translation are explicit.
- R2 `PASS`: completed endpoints, exact weekday sequence, agreement map,
  decision clock, attempt state, stop, spread, risk, and exit are fixed.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history supplies every runtime
  input. No investor-position, COT, external calendar, CSV, or API feed is
  required.
- R4 `PASS`: native price, broker calendar, logarithm, ATR risk, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,509 EA-registry rows and 605 root
cards. It found no exact identity and raised only the expected fuzzy family
neighbors `wti-wopen-mom` and `wti-wclose-mom`.

- `QM5_41019_wti-wopen-mom` observes the current week's opening segment,
  enters Wednesday from that single sign, and exits Friday. This package uses
  the completed prior week's opening and closing segments, requires strict
  agreement, enters the following Monday, and never owns the signal week.
- `QM5_41020_wti-wclose-mom` uses only the prior closing segment, enters on
  the same Monday clock, and exits Wednesday. This package requires the
  disjoint opening segment to agree and remains owned through Friday.
- `QM5_41021_wti-mdual-mom` combines a complete broker month with its nested
  final five sessions and trades the next month's first five sessions. This
  package uses two disjoint within-week segments and an exact weekday
  sequence.
- `QM5_13049_xti-1w-mom-vol` uses a rolling five-D1 magnitude threshold and
  realized-volatility rank with any-new-day evaluation and reversal/time
  exits. This package is exact-calendar and sign-only, with no magnitude or
  volatility signal filter.
- `QM5_21521_wti-flow-switch` classifies tick-volume tails and switches
  between continuation and reversal. This package reads no volume and never
  reverses the prior return.
- Weekly range, ORB, and cumulative-RSI commodity EAs use different
  information objects and entry/exit clocks.

Verdict:
`CLEAN_WTI_DISJOINT_SPLIT_WEEK_AGREEMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately 20-35 completed positions per full
post-warm-up year. Q02 retires below five completed trades per year, on zero
trades, wrong weekday reconstruction, current-bar leakage, late or repeated
entry, disagreement-side entry, wrong Friday lifecycle, invalid risk mode,
nondeterminism, or nonpositive governed economics. Q09 alone may establish
realized portfolio correlation.

This packet authorizes one branch-only Strategy Card, deterministic V5 build,
strict Q01 validation, one fixed-risk backtest setfile, and one paced Q02
enqueue. It authorizes no manual backtest, live/demo/shadow/stress setfile,
portfolio admission, portfolio-gate mutation, deploy or T_Live manifest,
`T_Live` action, or AutoTrading change.

## Provenance Chain

- source approval: commit `354986d94`;
- deterministic EA allocation: commit `4ff30002c`, EA `QM5_41022`;
- parent published-paper review:
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`;
- parent weekly bounded review:
  `strategy-seeds/sources/28681f5d-aa78-584e-9698-750d1402e485/source.md`.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial bounded split-week extraction | G0 | APPROVED |
| v1-build | 2026-08-16 | deterministic V5 implementation and strict validation | Q01 | PASS |
