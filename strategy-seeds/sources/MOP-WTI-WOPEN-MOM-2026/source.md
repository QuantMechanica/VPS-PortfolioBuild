---
source_id: MOP-WTI-WOPEN-MOM-2026
title: WTI Fixed Week-Opening Segment Momentum
source_type: governed_peer_reviewed_translation_packet
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-16_wti_week_opening_momentum_source_approval.md
approval_commit: e6bc3ffff
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-16
created: 2026-08-16
created_by: Research+Development
strategy_ids: [MOP-WTI-WOPEN-MOM-2026_S01]
parent_sources:
  - MOP-TSMOM-2012
---

# WTI Fixed Week-Opening Segment Momentum Source Packet

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
test a Monday/Tuesday WTI opening segment, Wednesday entry, Friday close,
standalone continuous-CFD execution, fixed-dollar ATR risk, spread caps, or
the QM portfolio.

## Bounded Mechanization

`MOP-WTI-WOPEN-MOM-2026_S01` is one predeclared price-native WTI package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- exact broker-week sequence of prior Friday, Monday, Tuesday, and current
  Wednesday D1 bars, with no holiday shift or substitution;
- formation return `log(TuesdayClose / PriorFridayClose)` from completed,
  positive, finite closes only;
- Wednesday BUY after a positive formation return and SELL after a negative
  formation return, with exact zero consumed flat;
- first-observed-tick deadline of 180 minutes after the Wednesday bar
  timestamp, so a later restart consumes the week without a backfilled entry;
- one persistent exact-Wednesday attempt recorded before every fallible gate;
- one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, frozen
  `3.5 * ATR(20,D1)` hard stop, 1,500-point spread ceiling, and no target;
- framework Friday close at broker hour 21, plus Sunday/Monday/Tuesday and
  six-calendar-day stale repair; and
- no external runtime data, scale-in, or signal-magnitude risk adjustment.

The Monday close is a continuity observation and is not a signal endpoint.
The current Wednesday bar never enters the formation. The two-session weekly
horizon, exact weekday sequence, entry grace, fixed-risk execution, and
Friday lifecycle are disclosed QM choices. No source statistic or result is
imported.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,506 registry rows and 602 root cards
and returned `CLEAN`. Manual family review returned
`CLEAN_WTI_FIXED_WEEK_OPENING_SEGMENT_MOMENTUM_AFTER_FAMILY_REVIEW`:

- `QM5_41013_wti-mopen-mom` uses five current-month sessions and holds the
  residual month;
- `QM5_12965_wti-week-orb` breaks Monday's range with trend, range, buffer,
  and close-location filters;
- `QM5_13049_xti-1w-mom-vol` uses a rolling thresholded five-D1 return and a
  realized-volatility rank;
- `QM5_20154_wti-wed-trend` uses a completed 252-D1 trend state;
- `QM5_20217_wti-wkend-mom` trades a Monday gap outside Friday's buffered
  range; and
- `QM5_12567_cum-rsi2-commodity` is an oscillator pullback.

This packet uses an exact Friday-to-Tuesday opening segment, sign only,
Wednesday entry, and Friday close. It has no rolling horizon, magnitude
threshold, range breakout, volatility signal, or oscillator.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_TRANSLATION_RISK`: peer-reviewed JFE lineage, named
  authors, DOI, complete-paper receipt, durable retrieval hash, explicit WTI
  membership, and a disclosed weekly translation not tested by the source.
- R2 `PASS`: weekday sequence, endpoints, sign, timing, attempt, risk, stop,
  spread, and lifecycle are mechanically locked.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history supplies every runtime
  input.
- R4 `PASS`: native calendar/OHLC/logarithm/ATR/quote/position/deal state only;
  no trained output, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-ordering estimate, not evidence.
- `expected_dd_pct: 30.0` reflects WTI gap, false-continuation, and weekend
  lifecycle risk.
- Expected cadence is approximately 45-52 positions per full post-warm-up
  year before holidays and fail-closed exclusions.
- `risk_class: high`.
- `ml_required: false`.

Q02 must retire on zero trades, fewer than five completed positions per full
year, wrong or shifted weekdays, current-bar leakage, late/repeated entries,
invalid risk mode, weekend carry past repair, nondeterminism, or nonpositive
governed economics. Translation distance, multiple horizon search, futures/CFD
basis, spread, gaps, roll, financing, and later portfolio correlation are
first-order risks. No parameter rescue or correlation waiver is authorized.

## Framework Alignment

- no_trade: exact host/D1/ID/slot, locked inputs, risk mode, news OFF, Friday
  close ON, and identity guards.
- trade_entry: exact Friday-Monday-Tuesday-Wednesday sequence, persistent
  attempt, completed return sign, entry grace, spread/quote/ATR validation,
  and one directed order.
- trade_management: malformed, stale weekday, and six-day repair before
  entry-only gates.
- trade_close: framework Friday close, V5 close path, hard stop, and kill
  switch.

## Safety And Kill Boundary

OWNER G0 authorizes one branch-only non-live build, strict Q01 validation,
one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It excludes a
manual tester dispatch; live/demo/shadow/stress/optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio admission;
portfolio-gate edits; and correlation waivers. If the factory resource ceiling
is binding, the item may be enqueued but no tester may be controlled.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial fixed week-opening extraction | G0 | APPROVED |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-16 | APPROVED; R1-R4 reviewed | source packet, source-approval decision, G0 decision, and Strategy Card |
