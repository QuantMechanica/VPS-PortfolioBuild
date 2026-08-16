---
source_id: MOP-WTI-MDUAL-MOM-2026
title: WTI Month-Boundary Dual-Horizon Momentum
source_type: governed_peer_reviewed_translation_packet
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-16_wti_month_dual_momentum_source_approval.md
approval_commit: c147775f2
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-16
created: 2026-08-16
created_by: Research+Development
strategy_ids: [MOP-WTI-MDUAL-MOM-2026_S01]
parent_sources:
  - MOP-TSMOM-2012
---

# WTI Month-Boundary Dual-Horizon Momentum Source Packet

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
test agreement between a completed WTI month and its final five sessions, a
first-new-month clock, a five-session hold, standalone continuous-CFD
execution, fixed-dollar ATR risk, spread caps, or the QM portfolio.

## Bounded Mechanization

`MOP-WTI-MDUAL-MOM-2026_S01` is one predeclared price-native WTI package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- decision only on the first D1 bar of a new broker month and only within five
  minutes of its executable open;
- native same-day D1 labels are used directly; if the factory energy label is
  24-48 hours behind broker time, the current and historical D1 labels are
  normalized by one uniform +1 calendar day before month membership checks;
- the opening-grace calculation uses elapsed raw-label time modulo one day so
  both governed label conventions behave identically;
- exact immediately prior and prior-prior broker-month-end closes for
  `month_return = log(prior_month_end / prior_prior_month_end)`;
- exact six newest completed bars in the prior broker month for
  `closing_return = log(prior_month_end / prior_month_close_6)`, spanning its
  final five close-to-close intervals;
- BUY only when both returns are positive and SELL only when both are
  negative; disagreement, exact zero, or invalid arithmetic consumes the
  month flat;
- one persistent exact-`yyyymm` attempt recorded before every fallible gate;
- one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, frozen
  `3.5 * ATR(20,D1)` hard stop, 1,500-point spread ceiling, and no target;
- close at the first tick of the sixth D1 bar in the entry month, with a
  premature month change and twelve-calendar-day stale guard; and
- no external runtime data, scale-in, or signal-magnitude risk adjustment.

The complete-month endpoint and nested final-five endpoint are both completed
before entry. The current-month price never enters either signal. The dual-
horizon agreement, exact month boundary, five-minute grace, fixed-risk
execution, and first-five-session lifecycle are disclosed QM choices. No
source statistic or result is imported.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_TRANSLATION_RISK`: exactly one governed source ID,
  backed by a named peer-reviewed JFE paper, DOI, complete-paper evidence,
  durable retrieval hash, explicit WTI membership, and a disclosed short-
  segment translation not tested by the paper.
- R2 `PASS`: month endpoints, final-five endpoints, strict agreement, timing,
  persistent attempt, risk, stop, spread, and exit are deterministic and
  locked before testing.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history and MT5-native execution state
  supply every runtime input.
- R4 `PASS`: native calendar, completed prices, logarithms, ATR risk plumbing,
  quote, position, deal-history, and framework state only; no trained output,
  banned signal indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,508 EA-registry rows and 604 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review
returned
`CLEAN_WTI_MONTH_AND_CLOSING_SEGMENT_AGREEMENT_MOMENTUM_AFTER_FAMILY_REVIEW`:

- `QM5_41016_wti-mclose-mom` follows the final-five sign alone at the same
  boundary; this packet adds the independent completed-month sign and makes
  strict agreement a load-bearing entry state;
- `QM5_20187_wti-tsmom1m` follows the completed-month sign alone and owns the
  complete following month; this packet owns only the first five sessions;
- `QM5_20056_wti-dual-mom` and
  `QM5_12711_commodity-tsmom-dual-6-12` compare medium/long monthly horizons
  and hold monthly packages, not a nested one-month/five-session state;
- `QM5_20244_wti-trend-sign` compares a twelve-month return with the breadth
  of twelve monthly signs and has neither this endpoint pair nor lifecycle;
- `QM5_13049_xti-1w-mom-vol` is a rolling five-D1 magnitude/volatility rule,
  not a once-per-month sign agreement rule;
- `QM5_41013_wti-mopen-mom` forms on current-month bars 1-5, enters at bar 6,
  and holds the residual month; this packet is flat by bar 6 and uses only
  prior-month information; and
- `QM5_12567_cum-rsi2-commodity` is a short-horizon oscillator pullback across
  commodity carriers, not a WTI month-boundary continuation rule.

The two completed-return horizons, exact first-new-month decision, strict
agreement-flat state, and first-five-session ownership are the auditable
identity. A failed result may not be rescued by removing the agreement gate,
moving either endpoint, changing direction, widening risk, or extending the
hold.

## Safety And Extraction Boundary

The approval at commit `c147775f2` authorizes exactly one card, deterministic
ID allocation, one branch-only non-live build, strict Q01, one `RISK_FIXED`
backtest setfile, and one paced Q02 enqueue. It excludes manual tester
dispatch; live/demo/shadow/stress/optimization setfiles; AutoTrading;
`T_Live`; deploy or T_Live manifests; portfolio admission; portfolio-gate
edits; and correlation waivers. Q09 alone may establish realized correlation
with the certified book.

Expected cadence is approximately six to ten completed packages per full
post-warm-up year. Q02 must retire the card on zero trades, below five/year,
wrong month or endpoint reconstruction, current-bar leakage, late/repeated
entry, disagreement-side entry, wrong hold length, nondeterminism, invalid
risk mode, or nonpositive governed economics.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial month-boundary dual-horizon extraction | G0 | APPROVED |
| v1-build | 2026-08-16 | deterministic V5 implementation and strict validation | Q01 | PASS |
| v1-queue | 2026-08-16 | first canonical fixed-risk baseline work item | Q02 | ENQUEUED |
