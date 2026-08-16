# QM5_41028 WTI Month-Boundary Gap Fade G0 Authorization

Date: 2026-08-16

Decision: `APPROVED` for one branch-only V5 build, strict Q01 validation, one
locked `RISK_FIXED` backtest setfile, and one paced non-live Q02 enqueue. This
is not live, portfolio, or manual-tester authority.

## Identity

- EA: `QM5_41028_wti-mgap-fade`
- strategy ID: `TGIF-YANG-WTI-MGAP-2026_S01`
- approved source: `TGIF-YANG-WTI-MGAP-2026`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41028_wti-mgap-fade_card.md`
- host/slot 0: `XTIUSD.DWX`, D1, planned magic `410280000`
- risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

The atomic registry allocator assigned `QM5_41028` at commit `304417eb6`.
No ID was inferred or appended by hand.

## Source And Hypothesis Review

The OWNER-authorized source decision is
`decisions/2026-08-16_wti_month_boundary_gap_fade_source_approval.md` at
commit `50d77b36a`. The bounded composite packet joins:

- Hoelscher, Mbanga, and Nelson (2017), whose peer-reviewed WTI
  weekday/weekend return study and explicit close-to-open timing boundary are
  preserved in the repository; and
- Yang, Goncu, and Pantelous, whose academic commodity-reversal working paper
  supplies fixed-horizon reversal lineage.

The approved hypothesis is intentionally narrower than either source. On the
first genuine normalized D1 session of each WTI broker month, fade the exact
prior-month-final-close to current-month-first-open gap, then flatten at the
next D1 boundary. The month selector, close/open endpoints, continuous CFD,
label normalization, attachment grace, fixed risk, hard stop, spread cap,
attempt ledger, and repair behavior are QM translations. No source
performance, significance, density, decorrelation, or portfolio result
transfers.

## G0 Gates

- R1 `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`: one bounded source ID with
  named academic WTI calendar and commodity-reversal lineages; the
  working-paper status, source-to-implementation distance, untested
  conjunction, and multiple-testing risk are disclosed.
- R2 `PASS`: exact first-session clock, prior-close/current-open gap,
  contrarian mapping, persistent monthly attempt, entry grace, risk, stop,
  spread, next-D1 close, and stale repair are deterministic and frozen.
- R3 `PASS`: registered `XTIUSD.DWX` D1 bars, measured energy-label offset,
  native ATR, quotes, spread, positions, deals, and terminal state supply all
  runtime inputs.
- R4 `PASS`: no trained output, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, or pyramid.

## Locked Execution Contract

1. Run only on exact `XTIUSD.DWX`, D1, EA ID 41028, magic slot 0.
2. Normalize current and historical D1 labels by only the governed same-day
   or uniform `+86400`-second energy convention. Require normalized current
   date to equal broker date.
3. Require the normalized current bar and immediately preceding completed bar
   to belong to different, exactly consecutive broker months with strict
   timestamp order. This is the first genuine session of the month; never
   shift a missing session.
4. Admit only the first observed tick within 180 minutes of executable D1
   open. Persist the broker-month attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates. Never retry or backfill.
5. Compute `log(Open[0]/Close[1])` from the fixed first-session open and prior
   completed final-session close. BUY only for a strictly negative value and
   SELL only for a strictly positive value. Exact zero or invalid arithmetic
   consumes the month flat.
6. Use one fixed-risk position, a frozen `3.0*ATR(20,D1)` broker hard stop,
   no target, and a 1,500-point entry-spread ceiling.
7. Flatten on the first later normalized D1 boundary. Four elapsed calendar
   days, malformed exposure, or framework Friday close at hour 21 is repair.

News temporal mode, compliance profile, and legacy mode are OFF. Gap
magnitude cannot change risk. No threshold, target, optimization, or rescue
sweep is authorized.

## Non-Duplicate Review

The canonical checker scanned 4,515 registry rows and 611 root cards and
returned `CLEAN`. Manual semantic review separates the candidate from:

- `QM5_12750` and `QM5_12779`, which are thresholded, one-sided,
  target-to-prior-close Friday/Monday gap systems;
- `QM5_20217` and `QM5_20230`, which follow prior-range breakaway gaps after
  volatility and optional physical-season gates;
- `QM5_41027_wti-mopen-rev1`, which waits for the first current-month session
  to complete and fades its intraday return during the second session;
- `QM5_41016_wti-mclose-mom`, which follows a five-interval prior-month
  formation for five current-month sessions; and
- `QM5_12567_cum-rsi2-commodity`, which is a two-day oscillator-pullback
  fanout.

Verdict:
`CLEAN_WTI_FIRST_MONTH_SESSION_BOUNDARY_GAP_FADE_AFTER_FAMILY_REVIEW`.

## Build And Safety Boundary

The build must contain the approved card, one `.mq5`, one compiled `.ex5`, one
`XTIUSD.DWX` D1 backtest setfile, deterministic reference tests, and the
required active magic row. Q01 must pass strict compile and build validation
before Q02 is enqueued.

Expected cadence is approximately ten to twelve completed positions per full
post-warm-up year. Q02 owns density and economics and must retire zero trades,
below five/year, wrong session identity or endpoints, current-tick leakage,
late or repeated entries, continuation-side exposure, wrong lifecycle,
invalid risk mode, nondeterminism, or nonpositive governed economics. Q09
alone may establish realized correlation.

This decision excludes manual tester dispatch; live/demo/shadow/stress or
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio admission; portfolio-gate changes; and correlation waivers. A
binding tester ceiling permits only a stop-and-summarize handoff.
