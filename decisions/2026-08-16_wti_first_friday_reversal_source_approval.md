# WTI First-Friday / Prior-Month Reversal - Source Approval

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

- proposed slug: `wti-1fri-rev1`
- proposed strategy ID: `GORSKA-YANG-WTI-1FRI-REV1-2026_S01`
- proposed source ID: `GORSKA-YANG-WTI-1FRI-REV1-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, long-only
- calendar clock: the first genuine normalized broker Friday of each month,
  with normalized day of month in `[1,7]` and a preceding Thursday D1 label
- price state: a strictly negative WTI return over the immediately completed
  broker calendar month
- lifecycle: one Friday-session position flattened by the V5 Friday-close
  guard, with the first later D1 boundary as repair

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following bounded repository sources were read completely before this
decision:

1. `strategy-seeds/sources/GORSKA-WTI-CAL-2015/source.md` preserves Anna
   Gorska and Malgorzata Krawiec (2015), "Calendar Effects in the Market of
   Crude Oil," *Quantitative Methods in Economics* 16(4). The paper studies
   WTI daily returns and reports Friday as the strongest positive average
   weekday in its sample.
2. `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md` preserves Liu
   Yang, Bige Kahraman Goncu, and Athanasios A. Pantelous, "Momentum and
   Reversal in Commodity Futures," SSRN 3069253. It supplies academic
   commodity-reversal lineage and already governs monthly and four-week
   loser-fade translations on the registered energy carriers.

Neither source tests this exact conjunction. Gorska and Krawiec do not limit
the Friday cell to the first Friday of a month or condition it on the prior
month. Yang, Goncu, and Pantelous do not prescribe a Friday-only WTI trade.
The conjunction, first-Friday sparsity rule, continuous-CFD carrier,
broker-label normalization, 180-minute attachment boundary, fixed cash risk,
ATR stop, spread cap, Friday-close implementation, and restart ledger are
transparent QM falsification choices. No source return, coefficient,
significance, trade density, cost, drawdown, CFD equivalence, decorrelation,
or portfolio result transfers.

## Locked Mechanic

On each new `XTIUSD.DWX` D1 bar:

1. Repair or close malformed, duplicated, wrong-side, stale, or
   out-of-lifecycle owned exposure before applying entry-only gates.
2. Normalize the raw D1 label only by the governed native same-day or uniform
   `+1` calendar-day energy convention. Require the normalized current date
   to equal the broker date, be Friday, and have day of month in `[1,7]`.
   Require the immediately preceding normalized D1 label to be Thursday. A
   missing or holiday-shifted Friday is skipped and never substituted.
3. Require the first observed tick within 180 minutes of the executable D1
   session open. Persist the current broker-month attempt before history,
   signal, news, spread, quote, ATR, sizing, or order gates. Never retry or
   backfill the month.
4. Reconstruct the newest completed D1 closes in the two broker calendar
   months immediately before the current normalized month. Require positive
   finite closes, strict timestamp order, and exact consecutive month keys.
   Current-month bars and the live bar enter neither endpoint.
5. Compute `prior_month_return = log(PriorMonthEnd /
   PriorPriorMonthEnd)`. BUY only when it is strictly negative. Exact zero,
   invalid history, or a nonnegative state consumes the month flat. Signal
   magnitude never scales risk.
6. Open at most one WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, a frozen `3.0 * ATR(20,D1)` broker hard stop, no
   target, and a 1,500-point entry-spread ceiling.
7. Flatten through the V5 Friday-close guard at broker hour 21. If the guard
   cannot complete, close on the first later normalized D1 boundary or after
   four calendar days. Both news axes remain OFF.

The exact first-genuine-Friday clock, completed-calendar-month endpoint
identity, negative-only reversal state, long-only direction, no-shift,
no-late-entry and no-retry rules, fixed risk, hard stop, and Friday-session
lifecycle are load-bearing. No day, horizon, direction, stop, hold, threshold,
or retry sweep is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`: a named-author academic
  WTI calendar-effects paper and a named-author commodity-reversal working
  paper, both with durable governed repository packets. The untested
  conjunction, source-sample decay, multiple-testing risk, and working-paper
  status are explicit.
- R2 `PASS`: normalized first-Friday clock, completed month endpoints,
  reversal sign, direction, attempt state, entry grace, risk, stop, spread,
  Friday close, and repair exit are deterministic and locked before Q02.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history supplies every runtime input.
  Its session offset is measured in
  `framework/registry/session_offset_minutes.csv`; no futures curve,
  inventory, event, analyst, CSV, or API feed is required.
- R4 `PASS`: deterministic native calendar, OHLC, logarithm, ATR, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,513 EA-registry rows and 609 root
cards. It found no exact or fuzzy match for the slug, strategy ID, author set,
or full mechanic fingerprint. Manual semantic review fixes the closest family
boundaries:

- `QM5_20172_wti-fri-bear` buys every genuine Friday when the completed
  252-D1 return is negative. This candidate admits only one Friday per broker
  month and reads the exact immediately completed calendar-month return.
- `QM5_12597_wti-fri-prem` buys every eligible Friday without any reversal
  state or monthly attempt ledger.
- `QM5_12709_commodity-reversal-1m` ranks a four-commodity cross-section and
  owns a two-leg monthly package. This candidate is a direct WTI one-session
  calendar/reversal conjunction, not a rank basket.
- `QM5_12621_comm-reversal-4wk-xtiusd` uses a rolling 20-D1 overreaction
  threshold on a weekly clock. This candidate requires exact consecutive
  completed calendar-month endpoints and a first-Friday seasonal state.
- `QM5_41024_wti-1wed-mom1` follows either sign of the prior completed month
  on the first genuine Wednesday. This candidate trades only the negative
  state, reverses it long, uses Friday rather than Wednesday, and delegates
  the ordinary exit to the Friday-close guard.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers. This candidate is direct WTI calendar/reversal logic
  with no RSI, moving-average continuation filter, or cross-carrier fanout.

Verdict:
`CLEAN_WTI_FIRST_FRIDAY_PRIOR_MONTH_REVERSAL_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately four to eight completed positions per full
post-warm-up year. Q02 must retire on zero trades, below three completed
positions per year, a wrong or shifted Friday, wrong month endpoints,
current-bar leakage, late or repeated entry, nonnegative-state entry, wrong
side or lifecycle, invalid risk mode, nondeterminism, or nonpositive governed
economics. Source-sample decay, working-paper risk, futures/CFD basis,
broker-label mapping, spreads, gaps, financing, and later book correlation are
first-order risks. Q09 alone may establish realized correlation with the
certified book.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.

