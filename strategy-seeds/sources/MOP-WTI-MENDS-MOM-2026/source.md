---
source_id: MOP-WTI-MENDS-MOM-2026
title: WTI Prior-Month Boundary-Segment Momentum
source_type: governed_peer_reviewed_translation_packet
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-16_wti_month_ends_momentum_source_approval.md
approval_commit: 75f0881c0
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-16
created: 2026-08-16
created_by: Research+Development
strategy_ids: [MOP-WTI-MENDS-MOM-2026_S01]
parent_sources:
  - MOP-TSMOM-2012
---

# WTI Prior-Month Boundary-Segment Momentum Source Packet

## Source Identity And Complete-Read Evidence

The governed parent is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`.

The complete 23-page published paper was retrieved from author Lasse Heje
Pedersen's NYU faculty site and read end to end. The durable review is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; its retrieval receipt and
PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`
are recorded there. Section 3.1 reports positive own-return continuation over
the first twelve monthly lags. Section 3.2 defines direction from the sign of
an instrument's completed own return. Appendix A includes NYMEX WTI among the
commodity futures.

The paper uses rolled futures excess returns, monthly formation/holding
horizons, ex-ante volatility scaling, and diversified portfolios. It does not
test agreement between WTI's first and final five sessions of one completed
month, an exact next-month clock, a five-session hold, standalone continuous-
CFD execution, fixed-dollar ATR risk, spread caps, or the QM portfolio.

## Bounded Mechanization

`MOP-WTI-MENDS-MOM-2026_S01` is one predeclared price-native WTI package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- decision only on the first D1 bar of a new broker month and only within 180
  minutes of its executable open;
- native same-day D1 labels are used directly; if the factory energy label is
  24-48 hours behind broker time, the current and historical D1 labels are
  normalized by one uniform +1 calendar day before month membership checks;
- at least fifteen positive, finite completed bars in the immediately prior
  broker month plus its immediately preceding broker-month-end anchor;
- `opening_return = log(PriorMonthFifthClose /
  PriorPriorMonthEndClose)`, spanning the boundary into the first five prior-
  month sessions;
- `closing_return = log(PriorMonthEndClose /
  PriorMonthSixthFromEndClose)`, spanning the final five prior-month close-to-
  close intervals;
- BUY only when both returns are positive and SELL only when both are
  negative; disagreement, exact zero, or invalid arithmetic consumes the
  month flat;
- one persistent exact-`yyyymm` attempt recorded before every fallible gate;
- one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, frozen
  `3.5 * ATR(20,D1)` hard stop, 1,500-point spread ceiling, and no target;
- close at the first tick of the sixth D1 bar in the entry month, with a
  premature month change and twelve-calendar-day stale guard; and
- no external runtime data, scale-in, or signal-magnitude risk adjustment.

The two signal intervals are completed before entry and share no return
interval. The intervening middle-month path and current-month price enter
neither return. The boundary-segment agreement, exact month clock, restart
boundary, fixed-risk execution, and first-five-session lifecycle are
disclosed QM choices. No source statistic or result is imported.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_TRANSLATION_RISK`: one governed source ID backed by a
  named peer-reviewed JFE paper, DOI, complete-paper evidence, durable
  retrieval hash, explicit WTI membership, and a disclosed boundary-segment
  translation not tested by the paper.
- R2 `PASS`: month endpoints, segment indexes, strict agreement, timing,
  persistent attempt, risk, stop, spread, and exit are deterministic and
  locked before testing.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history and MT5-native execution state
  supply every runtime input.
- R4 `PASS`: native calendar, completed prices, logarithms, ATR risk plumbing,
  quote, position, deal-history, and framework state only; no trained output,
  banned signal indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,510 EA-registry rows and 606 root
cards. It found no exact match and raised expected fuzzy matches to
`wti-mdual-mom` and `wti-mclose-mom`. Manual review returned
`CLEAN_WTI_DISJOINT_PRIOR_MONTH_BOUNDARY_SEGMENT_AGREEMENT_AFTER_FAMILY_REVIEW`:

- `QM5_41021_wti-mdual-mom` combines a completed full-month return with its
  nested final-five return; this packet uses only two non-overlapping opening
  and closing segments and discards the middle path;
- `QM5_41016_wti-mclose-mom` follows the final-five sign alone; this packet
  makes the independent opening-segment agreement load-bearing;
- `QM5_41013_wti-mopen-mom` observes the current month, enters on its sixth
  bar, and owns its residual sessions; this packet enters at the boundary from
  completed prior-month information and is flat by bar six;
- `QM5_20187_wti-tsmom1m` follows and owns complete months, not two boundary
  segments and a five-session package;
- `QM5_13049_xti-1w-mom-vol` is a rolling any-day magnitude/volatility rule,
  not a once-per-month sign agreement rule; and
- `QM5_12567_cum-rsi2-commodity` is a short-horizon oscillator pullback across
  commodity carriers, not a WTI month-boundary continuation rule.

The two completed boundary segments, first-new-month decision, strict
agreement-flat state, and first-five-session ownership are the auditable
identity. A failed result may not be rescued by removing the agreement gate,
moving either endpoint, changing direction, widening risk, or extending the
hold.

## Safety And Extraction Boundary

The approval at commit `75f0881c0` authorizes exactly one card, deterministic
ID allocation, one branch-only non-live build, strict Q01, one `RISK_FIXED`
backtest setfile, and one paced Q02 enqueue. It excludes manual tester
dispatch; live/demo/shadow/stress/optimization setfiles; AutoTrading;
`T_Live`; deploy or T_Live manifests; portfolio admission; portfolio-gate
edits; and correlation waivers. Q09 alone may establish realized correlation
with the certified book.

Expected cadence is approximately five to eight completed packages per full
post-warm-up year. Q02 must retire the card on zero trades, below five/year,
wrong month or segment reconstruction, overlapping return intervals,
current-bar leakage, late/repeated entry, disagreement-side entry, wrong hold
length, nondeterminism, invalid risk mode, or nonpositive governed economics.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial prior-month boundary-segment extraction | G0 | APPROVED |
