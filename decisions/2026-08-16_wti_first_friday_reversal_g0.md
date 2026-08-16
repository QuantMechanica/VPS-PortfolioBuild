# QM5_41026 WTI First-Friday / Prior-Month Reversal G0 Authorization

Date: 2026-08-16

Decision: `APPROVED` for one branch-only V5 build, strict Q01 validation, one
locked `RISK_FIXED` backtest setfile, and one paced non-live Q02 enqueue. This
is not live, portfolio, or manual-tester authority.

## Identity

- EA: `QM5_41026_wti-1fri-rev1`
- strategy ID: `GORSKA-YANG-WTI-1FRI-REV1-2026_S01`
- approved source: `GORSKA-YANG-WTI-1FRI-REV1-2026`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41026_wti-1fri-rev1_card.md`
- host/slot 0: `XTIUSD.DWX`, D1, planned magic `410260000`
- risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

The atomic registry allocator assigned `QM5_41026` at commit `6bfeffee3`.
No ID was inferred or appended by hand.

## Source And Hypothesis Review

The OWNER-authorized source decision is
`decisions/2026-08-16_wti_first_friday_reversal_source_approval.md` at commit
`5b0bd7603`. The bounded composite packet combines:

- Gorska and Krawiec (2015), an academic WTI calendar-effects paper whose
  governed extraction records Friday as the strongest positive average WTI
  weekday in the source sample; and
- Yang, Goncu, and Pantelous, an academic commodity momentum/reversal paper
  whose governed extraction supplies fixed-horizon loser-fade lineage.

The approved hypothesis is intentionally narrower than either source. On the
first genuine normalized broker Friday of a month, buy WTI only when the
immediately completed broker-calendar month return is strictly negative, then
flatten through the V5 Friday-close guard. The first-Friday selector,
calendar-month endpoints, continuous CFD, label normalization, attachment
grace, fixed risk, hard stop, spread cap, attempt ledger, and repair behavior
are QM translations. No source performance, significance, density,
decorrelation, or portfolio result transfers.

## G0 Gates

- R1 `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`: named academic sources and
  complete governed repository packets; the untested conjunction,
  multiple-testing risk, working-paper status, and post-sample decay are
  disclosed.
- R2 `PASS`: exact first-Friday clock, consecutive completed calendar-month
  endpoints, negative-only long mapping, persistent monthly attempt, entry
  grace, risk, stop, spread, Friday close, and repair are deterministic and
  frozen before Q02.
- R3 `PASS`: registered `XTIUSD.DWX` D1 bars, measured energy-label offset,
  native ATR, quotes, spread, positions, deals, and terminal state supply all
  runtime inputs.
- R4 `PASS`: no trained output, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, or pyramid.

## Locked Execution Contract

1. Run only on exact `XTIUSD.DWX`, D1, EA ID 41026, magic slot 0.
2. Normalize current and historical D1 labels by only the governed same-day
   or uniform `+86400`-second energy convention. Require normalized current
   date to equal broker date.
3. Decide only when the normalized current label is Friday with day of month
   `[1,7]` and the immediately preceding normalized D1 label is Thursday.
   Never shift a missing or holiday Friday.
4. Admit only the first observed tick within 180 minutes of executable D1
   open. Persist the broker-month attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates. Never retry or backfill.
5. Reconstruct the newest completed D1 close in each of the two immediately
   preceding consecutive broker months. Compute
   `log(PriorMonthEnd/PriorPriorMonthEnd)` without current-month leakage.
6. BUY only when that return is strictly negative. Exact zero, a nonnegative
   value, invalid arithmetic, or missing endpoints consumes the month flat.
7. Use one fixed-risk position, a frozen `3.0*ATR(20,D1)` broker hard stop,
   no target, and a 1,500-point entry-spread ceiling.
8. Flatten via framework Friday close at broker hour 21. A later normalized
   D1 label or four elapsed calendar days forces repair. Malformed, duplicate,
   or wrong-side owned exposure closes before any entry gate.

News temporal mode, compliance profile, and legacy mode are OFF. Friday close
is enabled. Signal magnitude cannot change risk. No optimization or rescue
sweep is authorized.

## Non-Duplicate Review

The canonical checker scanned 4,513 registry rows and 609 root cards and
returned `CLEAN` without an exact or fuzzy match. Manual review also separates
the candidate from:

- `QM5_20172_wti-fri-bear`, which trades every genuine Friday from a 252-D1
  negative state;
- `QM5_12597_wti-fri-prem`, which is an unconditional weekly Friday trade;
- `QM5_12709_commodity-reversal-1m`, which is a four-carrier two-leg rank
  basket held for a month;
- `QM5_12621_comm-reversal-4wk-xtiusd`, which uses a rolling 20-D1 threshold;
- `QM5_41024_wti-1wed-mom1`, which follows either prior-month sign on first
  Wednesday and exits at the next D1 boundary; and
- `QM5_12567_cum-rsi2-commodity`, which is a two-day oscillator pullback
  fanout.

Verdict:
`CLEAN_WTI_FIRST_FRIDAY_PRIOR_MONTH_REVERSAL_AFTER_FAMILY_REVIEW`.

## Build And Safety Boundary

The build must contain the approved card, one `.mq5`, one compiled `.ex5`,
one `XTIUSD.DWX` D1 backtest setfile, deterministic reference tests, and the
required active magic row. Q01 must pass strict compile and build validation
before Q02 is enqueued.

Expected cadence is approximately four to eight completed positions per full
post-warm-up year. Q02 owns density and economics and must retire zero trades,
below three/year, wrong dates or endpoints, current-bar leakage, late or
repeated entries, nonnegative-state entries, wrong-side exposure, wrong
lifecycle, invalid risk mode, nondeterminism, or nonpositive governed
economics. Q09 alone may establish realized correlation.

This decision excludes manual tester dispatch; live/demo/shadow/stress or
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio admission; portfolio-gate changes; and correlation waivers. A
binding tester ceiling permits only a stop-and-summarize handoff.
