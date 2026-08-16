# WTI Month-Opening Session Reversal - Source Approval

Date: 2026-08-16

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. This decision does not authorize a manual
tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, `RISK_FIXED` backtests, and
no live or portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-mopen-rev1`
- proposed strategy ID: `MOP-YANG-WTI-MOPEN-REV1-2026_S01`
- proposed source ID: `MOP-YANG-WTI-MOPEN-REV1-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, symmetric long/short
- decision clock: the second genuine normalized broker D1 session of each
  month
- price state: the signed open-to-close return of the first completed broker
  session of that same month
- lifecycle: fade the first-session sign for one D1 interval, with a
  four-calendar-day repair guard

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following bounded repository sources were read completely before this
decision:

1. `strategy-seeds/sources/MOP-WTI-MOPEN-MOM-2026/source.md` preserves a
   bounded translation of Moskowitz, Ooi, and Pedersen (2012), "Time Series
   Momentum," *Journal of Financial Economics* 104(2). It supplies
   peer-reviewed own-return-sign lineage, explicit WTI membership, and the
   governed idea of a fixed broker-month opening segment.
2. `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md` preserves Liu
   Yang, Bige Kahraman Goncu, and Athanasios A. Pantelous, "Momentum and
   Reversal in Commodity Futures," SSRN 3069253. It supplies academic
   commodity-reversal lineage on fixed price horizons.

Neither source tests this exact conjunction. Moskowitz, Ooi, and Pedersen do
not prescribe a one-session WTI reversal or a second-session decision. Yang,
Goncu, and Pantelous do not prescribe a broker-month opening clock. The exact
first-session endpoint identity, second-session clock, continuous-CFD carrier,
broker-label normalization, 180-minute attachment boundary, fixed cash risk,
ATR stop, spread cap, one-D1 hold, and restart ledger are transparent QM
falsification choices. No source return, coefficient, significance, trade
density, cost, drawdown, CFD equivalence, decorrelation, or portfolio result
transfers.

## Locked Mechanic

On each new `XTIUSD.DWX` D1 bar:

1. Repair or close malformed, duplicated, wrong-side, stale, or
   out-of-lifecycle owned exposure before applying entry-only gates.
2. Normalize current and historical D1 labels only by the governed native
   same-day or uniform `+1` calendar-day energy convention. Require the
   normalized current date to equal the broker date.
3. Require the current bar and immediately preceding completed bar to share a
   broker month, while the next older completed bar belongs to the immediately
   preceding broker month. This makes the current bar exactly the second
   genuine D1 session of the month; missing holidays are not substituted.
4. Require the first observed tick within 180 minutes of the executable D1
   session open. Persist the current broker-month attempt before history,
   signal, news, spread, quote, ATR, sizing, or order gates. Never retry or
   backfill the month.
5. Compute the first session's completed intrabar return as
   `log(FirstSessionClose / FirstSessionOpen)`. BUY WTI only when this return
   is strictly negative and SELL WTI only when it is strictly positive. Exact
   zero or invalid history consumes the month flat. Signal magnitude never
   scales risk.
6. Open at most one WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, a frozen `3.0 * ATR(20,D1)` broker hard stop, no
   target, and a 1,500-point entry-spread ceiling.
7. Flatten on the first later normalized D1 boundary. If that close cannot
   complete, close after four calendar days. Framework Friday close remains
   enabled as a fail-safe. Both news axes remain OFF.

The exact first-session open/close state, second-session clock, contrarian
direction, no-shift/no-late-entry/no-retry rules, fixed risk, hard stop, and
one-D1 lifecycle are load-bearing. No bar count, direction, threshold, stop,
hold, or retry sweep is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`: one bounded source ID
  preserves named-author academic momentum and commodity-reversal lineages.
  The untested conjunction, source-to-implementation distance, working-paper
  status, and multiple-testing risk are explicit.
- R2 `PASS`: normalized month/session identity, completed first-session
  endpoints, reversal mapping, attempt state, entry grace, risk, stop, spread,
  next-D1 exit, and repair are deterministic and locked before Q02.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history supplies every runtime input.
  Its session offset is measured in
  `framework/registry/session_offset_minutes.csv`; no futures curve,
  inventory, event, analyst, CSV, or API feed is required.
- R4 `PASS`: deterministic native calendar, OHLC, logarithm, ATR, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,514 EA-registry rows and 610 root
cards. It found no exact match and raised only `wti-mopen-mom` for manual
review. Manual semantic review fixes the family boundaries:

- `QM5_41013_wti-mopen-mom` waits until five current-month sessions have
  completed, follows their aggregate sign from the sixth session, and owns the
  residual month. This candidate fades only the first session, enters on the
  second session, and exits at the next D1 boundary.
- `QM5_12810_wti-month-orb` measures the first five-session high/low range and
  waits for a later buffered breakout with trend and range filters. This
  candidate has no range, breakout, trend indicator, or delayed trigger.
- `QM5_41023_wti-mends-mom` enters at the first new-month boundary when two
  non-overlapping prior-month segments agree and follows that direction for
  five bars. This candidate observes the already completed first current-
  month session and trades the opposite direction for one bar.
- `QM5_41024_wti-1wed-mom1` follows the prior completed calendar-month return
  on the first Wednesday. This candidate ignores prior-month direction and
  fades the first current-month session on an ordinal-session clock.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers. This candidate is direct WTI calendar/reversal logic
  with no RSI, moving average, or cross-carrier fanout.

Verdict:
`CLEAN_WTI_SECOND_SESSION_FIRST_SESSION_REVERSAL_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed positions per full
post-warm-up year. Q02 must retire on zero trades, below five completed
positions per year, wrong month/session identity, current-bar leakage, late or
repeated entry, momentum-side entry, wrong lifecycle, invalid risk mode,
nondeterminism, or nonpositive governed economics. Source-sample decay,
working-paper risk, futures/CFD basis, broker-label mapping, spreads, gaps,
financing, and later book correlation are first-order risks. Q09 alone may
establish realized correlation with the certified book.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.
