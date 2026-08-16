# QM5_41027 WTI Month-Opening Session Reversal G0 Authorization

Date: 2026-08-16

Decision: `APPROVED` for one branch-only V5 build, strict Q01 validation, one
locked `RISK_FIXED` backtest setfile, and one paced non-live Q02 enqueue. This
is not live, portfolio, or manual-tester authority.

## Identity

- EA: `QM5_41027_wti-mopen-rev1`
- strategy ID: `MOP-YANG-WTI-MOPEN-REV1-2026_S01`
- approved source: `MOP-YANG-WTI-MOPEN-REV1-2026`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41027_wti-mopen-rev1_card.md`
- host/slot 0: `XTIUSD.DWX`, D1, planned magic `410270000`
- risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

The atomic registry allocator assigned `QM5_41027` at commit `f23679b06`.
No ID was inferred or appended by hand.

## Source And Hypothesis Review

The OWNER-authorized source decision is
`decisions/2026-08-16_wti_month_opening_reversal_source_approval.md` at commit
`664785e3f`. The bounded composite packet joins:

- Moskowitz, Ooi, and Pedersen (2012), whose peer-reviewed own-return-sign
  lineage, explicit WTI membership, and governed fixed month-opening-segment
  translation are preserved in the repository; and
- Yang, Goncu, and Pantelous, whose academic commodity-reversal working paper
  supplies fixed-horizon reversal lineage.

The approved hypothesis is intentionally narrower than either source. On the
second genuine normalized D1 session of each WTI broker month, fade the exact
open-to-close sign of the first completed session, then flatten at the next D1
boundary. The ordinal session selector, first-session intrabar endpoints,
continuous CFD, label normalization, attachment grace, fixed risk, hard stop,
spread cap, attempt ledger, and repair behavior are QM translations. No source
performance, significance, density, decorrelation, or portfolio result
transfers.

## G0 Gates

- R1 `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`: one bounded source ID with
  named academic momentum and reversal lineages; the working-paper status,
  source-to-implementation distance, untested conjunction, and
  multiple-testing risk are disclosed.
- R2 `PASS`: exact second-session clock, completed first-session open/close
  return, contrarian mapping, persistent monthly attempt, entry grace, risk,
  stop, spread, next-D1 close, and stale repair are deterministic and frozen.
- R3 `PASS`: registered `XTIUSD.DWX` D1 bars, measured energy-label offset,
  native ATR, quotes, spread, positions, deals, and terminal state supply all
  runtime inputs.
- R4 `PASS`: no trained output, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, or pyramid.

## Locked Execution Contract

1. Run only on exact `XTIUSD.DWX`, D1, EA ID 41027, magic slot 0.
2. Normalize current and historical D1 labels by only the governed same-day
   or uniform `+86400`-second energy convention. Require normalized current
   date to equal broker date.
3. Require current and shift-1 normalized labels to share a broker month,
   shift 2 to belong to the immediately preceding month, and strict timestamp
   order. This is exactly the second genuine session of the month; never shift
   a missing session.
4. Admit only the first observed tick within 180 minutes of executable D1
   open. Persist the broker-month attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates. Never retry or backfill.
5. Compute `log(Close[1]/Open[1])` from the completed first current-month
   session. BUY only for a strictly negative value and SELL only for a
   strictly positive value. Exact zero or invalid arithmetic consumes the
   month flat.
6. Use one fixed-risk position, a frozen `3.0*ATR(20,D1)` broker hard stop,
   no target, and a 1,500-point entry-spread ceiling.
7. Flatten on the first later normalized D1 boundary. Four elapsed calendar
   days, malformed exposure, or framework Friday close at hour 21 is repair.

News temporal mode, compliance profile, and legacy mode are OFF. Signal
magnitude cannot change risk. No optimization or rescue sweep is authorized.

## Non-Duplicate Review

The canonical checker scanned 4,514 registry rows and 610 root cards, found
no exact identity, and raised only the expected `wti-mopen-mom` fuzzy sibling.
Manual review separates the candidate from:

- `QM5_41013_wti-mopen-mom`, which follows five opening sessions from the
  sixth bar through month end rather than fading one session for one bar;
- `QM5_12810_wti-month-orb`, which trades a later range breakout with trend
  and range filters;
- `QM5_41023_wti-mends-mom`, which follows two agreeing prior-month segments
  from the first new-month session for five bars;
- `QM5_41024_wti-1wed-mom1`, which follows the prior completed month on a
  weekday clock; and
- `QM5_12567_cum-rsi2-commodity`, which is a two-day oscillator pullback
  fanout.

Verdict:
`CLEAN_WTI_SECOND_SESSION_FIRST_SESSION_REVERSAL_AFTER_FAMILY_REVIEW`.

## Build And Safety Boundary

The build must contain the approved card, one `.mq5`, one compiled `.ex5`, one
`XTIUSD.DWX` D1 backtest setfile, deterministic reference tests, and the
required active magic row. Q01 must pass strict compile and build validation
before Q02 is enqueued.

Expected cadence is approximately ten to twelve completed positions per full
post-warm-up year. Q02 owns density and economics and must retire zero trades,
below five/year, wrong session identity or endpoints, current-bar leakage,
late or repeated entries, momentum-side exposure, wrong lifecycle, invalid
risk mode, nondeterminism, or nonpositive governed economics. Q09 alone may
establish realized correlation.

This decision excludes manual tester dispatch; live/demo/shadow/stress or
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio admission; portfolio-gate changes; and correlation waivers. A
binding tester ceiling permits only a stop-and-summarize handoff.
