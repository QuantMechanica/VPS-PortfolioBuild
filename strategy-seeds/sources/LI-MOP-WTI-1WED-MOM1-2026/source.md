---
source_id: LI-MOP-WTI-1WED-MOM1-2026
title: WTI first-Wednesday entry conditioned on completed prior-month return sign
publisher: Energy Economics / Journal of Financial Economics
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
approved_by: "OWNER commodity/energy portfolio mission 2026-08-16"
approved_at: 2026-08-16
source_approval: decisions/2026-08-16_wti_first_wednesday_month_momentum_source_approval.md
strategy_ids:
  - LI-MOP-WTI-1WED-MOM1-2026_S01
parent_sources:
  - LI-WTI-DOW-2022
  - MOP-TSMOM-2012
---

# WTI First-Wednesday / Prior-Month Momentum Source Packet

## Source identity and complete-read evidence

This governed packet joins two approved peer-reviewed source lineages whose
repository packets were read completely before extraction:

1. Wenhui Li, Qi Zhu, Fenghua Wen, and Normaziah Mohd Nor (2022), "The
   evolution of day-of-the-week and the implications in crude oil market,"
   *Energy Economics* 106, article 105817, DOI
   `10.1016/j.eneco.2022.105817`. The approved packet at
   `strategy-seeds/sources/LI-WTI-DOW-2022.md` preserves the paper identity,
   2007-2021 WTI sample, positive Wednesday finding, time-varying-efficiency
   warning, and its explicit abstract/highlights evidence boundary.
2. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The approved packet at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md` preserves an end-to-end
   review of the 23-page paper, its instrument-own trailing-return-sign rule,
   monthly formation/holding variants, and WTI's membership in the commodity
   universe. The author-hosted PDF receipt has SHA-256
   `7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

Li et al. supply the WTI Wednesday information clock. Moskowitz, Ooi, and
Pedersen supply the sign of an instrument's own completed return and the
one-month formation family. Neither paper tests the exact conjunction below.
No source performance, coefficient, significance, trade count, cost,
continuous-CFD basis, drawdown, correlation, or portfolio statistic transfers
to the QM candidate.

## Bounded mechanization

`LI-MOP-WTI-1WED-MOM1-2026_S01` is one predeclared interaction:

- carrier: exact `XTIUSD.DWX`, D1, magic slot 0;
- normalize the WTI D1 label only by the governed zero-or-`+1`-day energy
  convention and require the normalized current label to equal the broker
  date;
- decide only on a normalized Wednesday dated day 1-7 whose immediately prior
  normalized D1 label is Tuesday;
- never shift a missing/holiday first Wednesday to another session;
- admit only the first observed tick within 180 minutes of the executable D1
  session open and consume `yyyymm` before fallible gates;
- reconstruct the immediately completed broker month's last close and the
  preceding broker month's last close, require exact consecutive month keys,
  and compute `log(PriorMonthEnd / PriorPriorMonthEnd)`;
- buy a strictly positive completed-month return and sell a strictly negative
  completed-month return; exact zero stays flat;
- close on the first following normalized D1 boundary, with a five-calendar-
  day stale guard;
- freeze a `3.0 * ATR(20,D1)` broker hard stop, no take-profit, and a
  1,500-point entry spread ceiling; and
- backtest only with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

The first-Wednesday clock is a QM timing translation; the one-session exit is
shorter than the monthly hold studied by Moskowitz, Ooi, and Pedersen. The
candidate is therefore a falsification test of whether the completed-month
direction persists specifically into WTI's source-documented midweek
information session. Expected cadence is ten to twelve completed packages per
full post-warm-up year. Q02 must retire below five per year on average.

## Non-duplicate boundary

The canonical pre-allocation checker scanned 4,511 EA-registry rows and 607
root cards. It found no exact identity and no fuzzy match above threshold for
slug `wti-1wed-mom1`, strategy ID
`LI-MOP-WTI-1WED-MOM1-2026_S01`, and the first-Wednesday/prior-month mechanic.
Manual semantic review resolves the closest builds:

- `QM5_20154_wti-wed-trend` trades every genuine Wednesday, long only, after
  a positive completed 252-D1 return.
- `QM5_20170_wti-wed-bear` trades every genuine Wednesday, long only, after a
  negative completed 252-D1 return.
- `QM5_20022_wti-wed-long` and `QM5_12775_wti-wed-prem` are unconditional
  Wednesday-long packages.
- `QM5_20187_wti-tsmom1m` trades at the month boundary and owns the full next
  month instead of waiting for the first Wednesday and owning one D1 session.
- `QM5_41013_wti-mopen-mom` forms from the current month's first five sessions
  and enters on session six rather than reading the prior completed month.
- `QM5_12567_cum-rsi2-commodity` is a two-day commodity oscillator pullback,
  not a fixed-clock WTI completed-month continuation rule.

The exact first-Wednesday clock, completed calendar-month endpoint pair,
symmetric return-sign direction, and one-session lifecycle are jointly
load-bearing. Removing the month state recreates a Wednesday-premium parent;
removing the Wednesday clock recreates a monthly time-series-momentum parent.

## Reputable-source criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: two named-author peer-reviewed
  primary papers with DOI identity; the MOP paper has complete-text evidence
  and a durable retrieval hash, and the LI packet declares its narrower
  abstract/highlights boundary. The conjunction and short hold are untested.
- R2 `PASS`: label normalization, exact date predicate, endpoint months,
  return sign, direction, attempt state, entry clock, stop, spread, and exit
  are deterministic and frozen.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history supplies every runtime input.
- R4 `PASS`: native calendar, OHLC, logarithm, ATR, quote, position,
  deal-history, and terminal state only; no trained output, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Safety and claim boundary

The durable source approval at commit `01d4b0d45` authorizes one branch-only
Strategy Card, deterministic registry allocation, non-live V5 build, strict
compile, one fixed-risk backtest setfile, and one paced Q02 enqueue. The
deterministic allocator assigned `QM5_41024` at commit `9ee451dab`.

This packet does not authorize a manual backtest, live/demo/shadow/stress
setfile, AutoTrading, `T_Live`, a deploy or T_Live manifest, portfolio
admission, portfolio-gate changes, or a correlation waiver. If the factory
resource ceiling binds at enqueue time, stop without tester control.

## Pipeline history

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial bounded composite source packet | G0 | APPROVED_SOURCE |
