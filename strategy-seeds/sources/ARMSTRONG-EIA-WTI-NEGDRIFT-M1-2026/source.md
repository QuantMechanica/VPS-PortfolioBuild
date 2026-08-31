---
source_id: ARMSTRONG-EIA-WTI-NEGDRIFT-M1-2026
title: WTI EIA negative-news five-minute price drift
publisher: Journal of Financial Economics / U.S. Energy Information Administration
source_type: peer_reviewed_event_study_bounded_mechanization
status: approved_source_complete_bounded
approval_basis: decisions/2026-08-31_wti_eia_negative_drift_m1_source_approval.md
authors:
  - Will J. Armstrong
  - Laura Cardella
  - Nasim Sabah
created: 2026-08-31
created_by: Research
cards_extracted:
  - wti-eia-negdrift-m1
---

# WTI EIA Negative-News Five-Minute Drift Source Packet

## Source Identity And Retrieval

- Source: `https://www.sciencedirect.com/science/article/pii/S0304405X21000350`
- Title: "Information shocks, disagreement, and drift"
- Platform / publisher: ScienceDirect / Elsevier, *Journal of Financial
  Economics* 140(3), 916-940
- Authors: Will J. Armstrong, Laura Cardella, Nasim Sabah
- DOI: `10.1016/j.jfineco.2021.02.002`
- Retrieval status: complete read of accessible publisher landing record,
  abstract, introduction/result synopsis, and section synopsis on 2026-08-31;
  full journal text was not accessible through the retrieval route
- Predecessor metadata: `https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3314221`
- SSRN status: complete read of public metadata and abstract; 65-page PDF not
  accessible through the retrieval route
- Official schedule:
  `https://www.eia.gov/petroleum/supply/weekly/schedule.php`
- EIA status: complete read of the current public release-schedule page on
  2026-08-31

The durable authorization and exact access boundary are recorded in
`decisions/2026-08-31_wti_eia_negative_drift_m1_source_approval.md`.

## Findings Used

Armstrong, Cardella, and Sabah study price discovery around the recurring
Weekly Petroleum Status Report in a liquid crude-oil futures market without
short-sale constraints. The accessible publisher and abstract material state
that prices reflect positive news within one-half second, while negative news
moves prices sharply in the news direction and continues to drift for five
minutes. The authors connect the asymmetric negative-news delay to investor
disagreement and a surge in buying pressure that impedes convergence after
price drops.

The official EIA schedule identifies Wednesday after 10:30 a.m. Eastern as
the standard WPSR release clock and lists holiday exceptions. The existing
governed packet
`strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md` preserves the
same event identity, New York clock, standard-Wednesday proxy convention, and
no-external-runtime-feed boundary.

The paper's news classification is based on the unexpected inventory change,
not on a one-minute bar. It studies futures trades and quotes at much finer
resolution than a Darwinex CFD M1 bar. The source does not test a market order
at minute 1, the remaining four-minute holding window, fixed-dollar sizing,
an ATR stop, or the current portfolio.

No source return, coefficient, hit rate, Sharpe ratio, drawdown, transaction-
cost result, single-CFD equivalence, trade frequency, correlation, or
portfolio conclusion is imported.

## Bounded QM Mechanization

The card uses the completed 10:30-10:31 New York M1 price reaction as a noisy,
fully native proxy for negative report news. At the first tick of the 10:31
bar, it enters short only if that completed bar closes strictly below its
open, then exits at 10:35. This begins after the proxy is observable and uses
only the remaining four minutes of the source's five-minute drift window.

This classifier and entry rule are a transparent QM falsification hypothesis.
They are not attributed to the authors. A negative first-minute CFD return can
occur without negative inventory news, and holiday-shifted weeks can make the
standard-Wednesday label false. Q02 therefore tests the unchanged proxy rule,
not a direct replication of the paper.

## Exact Calendar And Bar Contract

- Host and traded carrier: exact `XTIUSD.DWX`, M1, symbol slot zero.
- Convert broker timestamps to UTC and then New York using the V5 broker-time
  and U.S.-DST helpers.
- Decision label: Wednesday 10:31 New York.
- Release-proxy bar: immediately preceding completed M1 bar, same New York
  date, label 10:30, exactly 60 broker-time seconds before the current bar.
- Entry grace: current New York seconds 0 through 29 at the first observed
  tick of the 10:31 bar.
- Standard Wednesdays only. Do not infer or trade a Thursday/Monday holiday
  shift. A holiday week's ordinary Wednesday 10:30 bar remains a known false-
  event risk of the frozen price-only proxy.
- Missing, displaced, nonfinite, nonpositive, inverted, or incomplete OHLC
  consumes the date flat. No neighboring bar, larger timeframe, or late
  attachment may substitute.

## Exact Signal Contract

For completed finite release-proxy OHLC:

```text
signal = SELL when close < open
         FLAT when close >= open
```

The comparison is strict. Equality is flat. Do not require or infer an
inventory value, consensus, surprise, minimum return, minimum body, range
breakout, pre-release range, pullback, reclaim, trend, season, volume, open
interest, futures curve, or another signal.

## Execution And Risk Contract

- Repair malformed owned state before entry-only checks.
- Persist the New York `yyyymmdd` attempt before history, signal, news,
  spread, quote, ATR, sizing, or submission. Never retry after any failure or
  stop-out on that date.
- Enter one market SELL only. Long is impossible.
- Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` for the
  sole non-live backtest setfile.
- Attach one frozen `3.0 * ATR(20,M1)` broker hard stop and no take-profit.
- Reject crossed or negative spreads and a genuinely positive spread above
  1,500 points. Modeled zero spread is valid.
- Close at the first tick at or after 10:35 New York on the entry date. Close
  on New York date change or ten elapsed minutes only as repair.
- Close duplicate, wrong-symbol, invalid-side, wrong-magic, or stopless owned
  exposure immediately.
- Lock current news temporal/compliance axes and legacy news mode OFF because
  the scheduled WPSR is the strategy event. Framework Friday flattening stays
  enabled but is not expected to fire.
- Never retry, reverse, place a pending order, scale in, pyramid, grid,
  martingale, partially close, trail, move to break even, optimize, or use an
  external runtime input.

## Non-Duplicate Boundary

The canonical receipt
`artifacts/qm5_wti_eia_negdrift_m1_preallocation_dedup_20260831.json`,
SHA-256
`0421E9B96BF80F46439170824993450BB335BAE6297DE933CEFADF416090133C`,
found no exact or above-threshold fuzzy identity across 4,741 registry rows,
1,379 cards, and 45 Strategy Wiki nodes.

The closest WTI WPSR builds use a pre-release M5 straddle, a delayed symmetric
M30 sign, completed D1 event bars, a two-event D1 state, or completed M30
pullback/failure sequences. None is negative-only, decides from the first
completed M1 bar, enters at 10:31, and exits at 10:35.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_STANDARD_WEDNESDAY_NEGATIVE_FIRST_MINUTE_REACTION_SHORT_DRIFT`.

## Reputable-Source Criteria

- R1: `PASS_WITH_PRICE_PROXY_AND_ACCESS_BOUNDARY`. The peer-reviewed JFE
  article directly reports negative-only five-minute WTI futures drift. The
  accessible publisher and abstract material was read completely, but the
  full article was not retrieved. The first-minute CFD sign is a disclosed
  translation.
- R2: `PASS`. The event clock, exact completed bar, strict sign, direction,
  attempt, fixed risk, stop, spread, and exit are locked.
- R3: `PASS_WITH_CFD_MICROSTRUCTURE_HOLIDAY_AND_TIME_MAPPING_RISK`. The
  governed registry records `XTIUSD.DWX` M1 history for 2017-2025. Native
  timestamps, OHLC, quotes, ATR, position, deal, and terminal state supply all
  runtime fields.
- R4: `PASS`. Deterministic calendar/OHLC arithmetic and ATR risk control
  only; no ML, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Kill And Safety Boundary

The weekly maximum and a roughly half-sign prior suggest 15-30 completed
positions/year, not a result. Q02 retires the unchanged baseline on zero
positions, fewer than five in any full scored year, nonpositive governed
economics, a wrong clock/bar, long or positive/flat-proxy entry, duplicate
date, missing stop, wrong exit, invalid risk mode, or nondeterminism. No
after-result direction, classifier, window, stop, or lifecycle change is
authorized.

The WTI event carrier is a candidate exposure outside the certified
XAU/SP500/NDX/XNG book, not proof of low correlation. Q09 alone may measure
realized overlap.

This packet authorizes no manual tester run, live/demo/shadow/stress/
optimization setfile, terminal control, AutoTrading action, `T_Live`, deploy
artifact, portfolio-gate change, portfolio admission, decorrelation claim, or
waiver.
