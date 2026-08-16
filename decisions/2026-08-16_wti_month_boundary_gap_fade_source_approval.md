# WTI Month-Boundary Gap Fade - Source Approval

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

- proposed slug: `wti-mgap-fade`
- proposed strategy ID: `TGIF-YANG-WTI-MGAP-2026_S01`
- proposed source ID: `TGIF-YANG-WTI-MGAP-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, symmetric long/short
- decision clock: the first genuine normalized broker D1 session of each
  month
- price state: the signed close-to-open gap from the final completed session
  of the prior month to the fixed open of the first current-month session
- lifecycle: fade the boundary-gap sign until the next normalized D1
  boundary, with a four-calendar-day repair guard

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following bounded repository sources were read completely before this
decision:

1. Hoelscher, Mbanga, and Nelson (2017), "TGIF? The Weekend Effect in Energy
   Commodities," *Journal of Finance Issues* 16(1), 47-68, DOI
   `10.58886/jfi.v16i1.2264`. The governed packet at
   `strategy-seeds/sources/TGIF-WTI-WEEKEND-2017/source.md` preserves the
   complete-paper review, WTI target-market evidence, and the important
   boundary that a close-to-close Monday return includes a non-tradable
   close-to-open component.
2. Liu Yang, Bige Kahraman Goncu, and Athanasios A. Pantelous, "Momentum and
   Reversal in Commodity Futures," SSRN 3069253. The governed packet at
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md` supplies the
   fixed-horizon commodity-reversal lineage.

Neither source tests the proposed conjunction. Hoelscher, Mbanga, and Nelson
study weekday-labelled spot returns, not first-of-month CFD gaps. Yang, Goncu,
and Pantelous do not prescribe a close-to-open gap, a month-boundary clock, or
a one-session hold. The exact Darwinex carrier, normalized broker-month
selector, gap endpoints, 180-minute attachment boundary, fixed cash risk, ATR
stop, spread cap, no-target lifecycle, and restart ledger are transparent QM
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
3. Require the normalized current bar to be in a different broker month from
   the immediately preceding completed bar, and require those two months to
   be exactly consecutive. This makes the current bar the first genuine D1
   session of the month. Missing holidays are not shifted or substituted.
4. Require the first observed tick within 180 minutes of the executable D1
   open. Persist the current broker-month attempt before history, signal,
   news, spread, quote, ATR, sizing, or order gates. Never retry or backfill
   the month.
5. Compute the boundary gap only from the fixed current D1 open and the prior
   completed D1 close:
   `gap_return = log(CurrentMonthFirstOpen / PriorMonthFinalClose)`.
6. BUY after a strictly negative gap and SELL after a strictly positive gap.
   Exact zero or invalid history consumes the month flat. Gap magnitude never
   scales risk.
7. Open at most one WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, a frozen `3.0 * ATR(20,D1)` hard stop, a 1,500-point
   spread ceiling, and no target.
8. Flatten on the first later normalized D1 boundary. If that close cannot
   complete, close after four calendar days. Framework Friday close remains
   enabled at broker hour 21 as a fail-safe. Both news axes remain OFF.

The exact cross-month close/open endpoints, first-session clock, contrarian
direction, no-shift/no-late-entry/no-retry rules, fixed risk, hard stop, and
one-D1 lifecycle are load-bearing. No gap threshold, weekday filter, target,
direction flip, shifted date, multi-bar formation, or longer hold is
authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`: one peer-reviewed,
  named-author WTI weekend/weekday study with complete official-paper review
  and one academic commodity-reversal working paper. The untested
  month-boundary conjunction, source-to-implementation distance, working-paper
  status, and multiple-testing risk are explicit.
- R2 `PASS`: normalized first-session identity, cross-boundary endpoints,
  contrarian mapping, attempt state, entry timing, risk, stop, spread, and
  next-D1 exit are deterministic and locked.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history and MT5 execution state supply
  every runtime input. Its direct-carrier session offset is measured in
  `framework/registry/session_offset_minutes.csv`.
- R4 `PASS`: native calendar, OHLC, logarithm, ATR risk plumbing, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,515 EA-registry rows and 611 root
cards and returned `CLEAN` without an exact or fuzzy identity. Manual semantic
review fixes the nearest-family boundaries:

- `QM5_12750_wti-weekend-gap-fade` and
  `QM5_12779_wti-weekend-gap-bounce` require a genuine Friday-to-Monday
  boundary, a 0.75% magnitude threshold, one-sided entries, and a prior-close
  fill target. This candidate accepts any genuine first session of a new
  month, is symmetric, has no magnitude threshold or target, and exits at the
  next D1 boundary.
- `QM5_20217_wti-wkend-mom` follows a Monday open beyond the prior Friday
  high/low plus a lagged-volatility buffer. This candidate uses only the prior
  close and current open and trades in the opposite direction.
- `QM5_20230_wti-seas-gap` further requires agreement with a fixed physical
  season and follows a threshold break. This candidate has no season map,
  range, volatility threshold, or continuation side.
- `QM5_41027_wti-mopen-rev1` waits for the first current-month session to
  complete, fades that session's open-to-close return on the second session,
  and therefore owns the following interval. This candidate trades the first
  session itself from the prior close/current open boundary gap.
- `QM5_41016_wti-mclose-mom` follows five completed prior-month intervals for
  the first five current-month sessions. This candidate reads one
  cross-boundary gap, fades it, and owns only one session.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon oscillator pullback across
  multiple commodity carriers, not a fixed-clock WTI boundary-gap strategy.

Verdict: `CLEAN_WTI_FIRST_MONTH_SESSION_BOUNDARY_GAP_FADE_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed positions per full
post-warm-up year. Q02 must retire on zero trades, below five completed
positions per year, wrong month/session identity, current-tick leakage into
the gap endpoints, late or repeated entry, continuation-side entry, wrong
lifecycle, nondeterminism, invalid risk mode, or nonpositive governed
economics. Weekend/month-end overlap, source-sample decay, working-paper risk,
continuous-futures/CFD roll and basis, broker-label mapping, spreads, gaps,
financing, and later book correlation are first-order risks. Q09 alone may
establish realized correlation with the certified book.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.
