---
source_id: BOROWSKI-MOP-WTI-DOMMOM1-2026
title: WTI exact day-8/day-26 entries conditioned on completed prior-month direction
publisher: Journal of Management and Financial Sciences / Journal of Financial Economics
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
approved_by: "OWNER commodity/energy portfolio mission 2026-08-16"
approved_at: 2026-08-16
source_approval: decisions/2026-08-16_wti_dom_month_momentum_source_approval.md
approval_commit: 600106d4e
strategy_ids:
  - BOROWSKI-MOP-WTI-DOMMOM1-2026_S01
parent_sources:
  - BOROWSKI-WTI-DOM26-2016
  - MOP-TSMOM-2012
---

# WTI Day-of-Month / Prior-Month Momentum Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins two governed peer-reviewed source lineages read
completely before extraction:

1. Krzysztof Borowski (2016), "Analysis of Selected Seasonality Effects in
   Markets of Future Contracts with the Following Underlying Instruments:
   Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle,
   Live Cattle, Lean Hogs and Lumber," *Journal of Management and Financial
   Sciences* 26, 27-44. The complete public paper and official SGH issue
   identity are reviewed in
   `strategy-seeds/sources/BOROWSKI-WTI-DOM26-2016/source.md`. Section 4.3
   reports a positive WTI day-8 cell (`p=0.0430`) and negative day-26 cell
   (`p=0.0424`) in NYMEX observations through 2016-03-31.
2. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete 23-page published paper was
   read end to end and is reviewed in
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`; its author-hosted PDF
   receipt has SHA-256
   `7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
   Section 3.2 defines direction from an instrument's completed own-return
   sign, Table 2 includes the `k=1`, `h=1` commodity family, and Appendix A
   names NYMEX WTI.

Borowski supplies the exact calendar directions. Moskowitz, Ooi, and Pedersen
supply the immediately completed own-month return sign. Neither paper tests
their conjunction, a one-D1 hold, a Darwinex continuous CFD, normalized broker
labels, fixed cash risk, or an ATR stop. No source performance, coefficient,
drawdown, cost, WTI-only efficacy, CFD equivalence, correlation, or portfolio
result transfers.

## Bounded Mechanization

`BOROWSKI-MOP-WTI-DOMMOM1-2026_S01` is one predeclared direct-WTI package:

- exact carrier `XTIUSD.DWX`, D1, magic slot 0;
- normalize D1 labels only by the governed same-day or uniform `+1`-day
  energy convention and require normalized date to equal broker date;
- decide only on exact normalized calendar day 8 or 26, within 180 minutes of
  the executable D1 open, with no holiday/weekend shift;
- persist the exact normalized `yyyymmdd` attempt before every fallible gate;
- reconstruct the newest completed D1 close in each of the two broker months
  preceding the decision month and require exact consecutive month keys;
- compute `log(PriorMonthEnd / PriorPriorMonthEnd)` from those completed
  endpoints only;
- on exact day 8, BUY only for a strictly positive completed-month return;
- on exact day 26, SELL only for a strictly negative completed-month return;
- exact zero, invalid endpoints, or a disagreeing sign consumes the date flat;
- use one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
  `2.75 * ATR(20,D1)` hard stop, a 2,500-point spread ceiling, and no target;
- close on the first following normalized D1 boundary, with a five-calendar-
  day stale guard and framework Friday-close fail-safe; and
- use no external runtime data, magnitude scaling, retry, scale-in, grid,
  martingale, or pyramid.

The calendar/month interaction, endpoint convention, 180-minute attachment
boundary, risk, stop, spread, and lifecycle are disclosed QM choices. The
sources do not test this interaction or shortened hold.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_AND_MULTIPLE_TESTING_RISK`: named authors, two
  peer-reviewed papers, complete repository reviews, exact WTI membership and
  table cells, JFE DOI, and a durable MOP retrieval hash. Borowski's broad
  anomaly search, uncorrected multiple comparisons, old endpoint, and the
  untested conjunction are explicit.
- R2 `PASS`: exact dates, normalized labels, completed month endpoints, sign
  map, direction, attempt state, entry timing, risk, stop, spread, and exit
  are deterministic and locked before testing.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history and MT5 execution state supply
  every runtime input. The direct WTI D1 session offset is measured in
  `framework/registry/session_offset_minutes.csv`.
- R4 `PASS`: native calendar, OHLC, logarithm, ATR, quote, position,
  deal-history, and framework state only; no trained output, banned signal
  indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,512 EA-registry rows and 608 root
cards. It found no exact identity and raised only `wti-dom-ctrreg` for manual
review. The review returned
`CLEAN_WTI_DAY8_DAY26_PRIOR_MONTH_AGREEMENT_AFTER_FAMILY_REVIEW`:

- `QM5_41017_wti-dom-ctrreg` admits the two dates only in the opposing
  completed 252-D1 state. This packet requires agreement with the immediately
  completed calendar month. Its shared-date signals are mutually exclusive
  whenever the one-month and 252-D1 signs agree.
- `QM5_20215_wti-dom-trend` uses day 1/day 26 and a completed 252-D1 state.
  This packet uses source-significant day 8/day 26 and exact consecutive
  calendar-month endpoints.
- `QM5_20036_wti-dom8-long` and `QM5_20027_wti-dom26-short` are unconditional
  source parents. This packet makes a separate completed-month agreement gate
  load-bearing.
- `QM5_20187_wti-tsmom1m` enters at the month boundary and owns the following
  month. This packet samples the state only at two exact calendar clocks and
  owns one D1 interval.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon oscillator pullback across
  commodity carriers, not a WTI calendar/trend interaction.

The exact day pair, source directions, prior-calendar-month endpoints,
agreement rule, and one-D1 lifecycle are the auditable identity. A failed
result may not be rescued by moving a date, changing the horizon or sign,
dropping the agreement gate, widening risk, or extending the hold.

## Safety And Extraction Boundary

The approval at commit `600106d4e` authorizes exactly one card, deterministic
ID allocation, one branch-only non-live build, strict Q01, one `RISK_FIXED`
backtest setfile, and one paced Q02 enqueue. The deterministic allocator
assigned `QM5_41025` at commit `5e1571bf1`.

It excludes manual tester dispatch; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; and correlation waivers. Q09 alone may
establish realized correlation with the certified book.

Expected cadence is approximately eight to ten completed packages per full
post-warm-up year. Q02 must retire on zero trades, below five/year, wrong
dates/endpoints/signs, shifted dates, current-bar leakage, late or repeated
entry, wrong lifecycle, nondeterminism, invalid risk mode, or nonpositive
governed economics.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | bounded composite source extraction | G0 | APPROVED_SOURCE |
| v1-build | 2026-08-16 | exact-date agreement EA, fixed-risk setfile, strict compile/build check, and static artifact validation | Q01 | PASS |
| v1-q02 | 2026-08-16 | target-only paced baseline handoff | Q02 | ENQUEUED |
