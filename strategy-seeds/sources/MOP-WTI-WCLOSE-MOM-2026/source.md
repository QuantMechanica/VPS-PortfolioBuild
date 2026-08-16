---
source_id: MOP-WTI-WCLOSE-MOM-2026
title: WTI Fixed Week-Closing Segment Momentum
source_type: governed_peer_reviewed_translation_packet
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-16_wti_week_closing_momentum_source_approval.md
approval_commit: db5a2c257
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-16
created: 2026-08-16
created_by: Research+Development
strategy_ids: [MOP-WTI-WCLOSE-MOM-2026_S01]
parent_sources:
  - MOP-TSMOM-2012
---

# WTI Fixed Week-Closing Segment Momentum Source Packet

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
test a Tuesday-through-Friday WTI closing segment, Monday entry, Wednesday
exit, standalone continuous-CFD execution, fixed-dollar ATR risk, spread caps,
or the QM portfolio.

## Bounded Mechanization

`MOP-WTI-WCLOSE-MOM-2026_S01` is one predeclared price-native WTI package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- exact broker-week sequence of prior Tuesday, Wednesday, Thursday, Friday,
  and current Monday D1 bars, with no holiday shift or substitution;
- broker time defines the Monday decision and attempt date; native same-day D1
  labels are used directly, while a factory energy label 24-48 hours behind
  broker time normalizes the current and all four completed labels by one
  uniform +1 calendar day before sequence checks;
- formation return `log(PriorFridayClose / PriorTuesdayClose)` from completed,
  positive, finite closes only;
- Monday BUY after a positive formation return and SELL after a negative
  formation return, with exact zero consumed flat;
- first-observed-tick deadline of 180 minutes after executable session open,
  computed from the raw D1 label modulo one day so both governed label
  conventions behave identically; a later restart consumes the week without a
  backfilled entry;
- one persistent exact-Monday attempt recorded before every fallible gate;
- one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, frozen
  `3.5 * ATR(20,D1)` hard stop, 1,500-point spread ceiling, and no target;
- first-Wednesday D1 close path, plus Thursday/Friday and five-calendar-day
  stale repair; framework Friday close remains enabled as a fail-safe; and
- no external runtime data, scale-in, or signal-magnitude risk adjustment.

The intervening Wednesday and Thursday closes are continuity observations and
are not signal endpoints. The current Monday bar never enters the formation.
The three-session weekly horizon, exact weekday sequence, entry grace,
fixed-risk execution, and Wednesday lifecycle are disclosed QM choices. No
source statistic or result is imported.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,507 registry rows and 603 root cards.
It found no exact identity match and returned one expected fuzzy family hit to
`wti-wopen-mom`. Manual review returned
`CLEAN_WTI_FIXED_WEEK_CLOSING_SEGMENT_MOMENTUM_AFTER_FAMILY_REVIEW`:

- `QM5_41019_wti-wopen-mom` forms from prior Friday through Tuesday, enters
  Wednesday, and exits Friday; this packet forms over the disjoint prior
  Tuesday-through-Friday segment, enters Monday, and exits Wednesday;
- `QM5_20217_wti-wkend-mom` trades the Monday gap beyond Friday's range plus a
  lagged-volatility buffer and exits on the next D1 bar;
- `QM5_20149_wti-montrend` and `QM5_20173_wti-mon-bullfade` use a 252-D1 trend
  state for a one-session Monday package;
- `QM5_13049_xti-1w-mom-vol` uses a rolling five-D1 return above a 1.25%
  threshold, a twenty-D1 volatility-rank gate, any-new-day timing, and a
  seven-day or reversal exit;
- `QM5_20029_wti-monfri-daily` is an unconditional Monday-short/Friday-long
  weekday rotation;
- `QM5_12965_wti-week-orb`, `QM5_13075_xti-inweek-brk`, and
  `QM5_13095_xti-outweek-fade` use weekly range shapes, levels, and additional
  trend/range filters; and
- `QM5_12567_cum-rsi2-commodity` is an oscillator pullback.

Registry row `21503,xti-weekly-tsmom-lowvol` has no card, EA directory,
setfile, or magic row in this branch and therefore is not an already-built
mechanic. Its name is still a disclosed family-level fuzzy concern; this
packet's exact endpoints, sign-only rule, Monday clock, and Wednesday exit are
the auditable identity.

This packet uses an exact completed Tuesday-to-Friday closing segment, sign
only, Monday entry, and Wednesday exit. It has no gap, rolling horizon,
magnitude threshold, range breakout, volatility signal, or oscillator.

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
- `expected_dd_pct: 30.0` reflects WTI gaps and false-continuation risk.
- Expected cadence is approximately 45-52 positions per full post-warm-up
  year before holidays and fail-closed exclusions.
- `risk_class: high`.
- `ml_required: false`.

Q02 must retire on zero trades, fewer than five completed positions per full
year, wrong or shifted weekdays, current-bar leakage, late/repeated entries,
invalid risk mode, carry past Wednesday repair, nondeterminism, or nonpositive
governed economics. Translation distance, multiple horizon search,
futures/CFD basis, spread, gaps, roll, financing, and later portfolio
correlation are first-order risks. No parameter rescue or correlation waiver
is authorized.

## Framework Alignment

- no_trade: exact host/D1/ID/slot, locked inputs, risk mode, news OFF, Friday
  close ON, and identity guards.
- trade_entry: broker-clock Monday, uniform known energy-label normalization,
  exact Tuesday-through-Friday sequence, persistent attempt, completed return
  sign, entry grace, spread/quote/ATR validation, and one directed order.
- trade_management: malformed, Wednesday-or-later, and five-day repair before
  entry-only gates.
- trade_close: first-Wednesday V5 close path, framework Friday fail-safe, hard
  stop, and kill switch.

## Safety And Kill Boundary

OWNER G0 authorizes one branch-only non-live build, strict Q01 validation, one
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It excludes a manual
tester dispatch; live/demo/shadow/stress/optimization setfiles; AutoTrading;
`T_Live`; deploy or T_Live manifests; portfolio admission; portfolio-gate
edits; and correlation waivers. If the factory resource ceiling is binding,
the item may be enqueued but no tester may be controlled.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial fixed week-closing extraction | G0 | APPROVED |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-16 | APPROVED; R1-R4 reviewed | source packet, source-approval decision, G0 decision, and Strategy Card |
