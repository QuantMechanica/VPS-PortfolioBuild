# WTI Prior-Month Boundary-Segment Momentum - Source Approval

Date: 2026-08-16

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue authority is not authority to dispatch
a manual tester or exceed the active factory resource ceiling.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, `RISK_FIXED` backtests, and
no live or portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-mends-mom`
- proposed strategy ID: `MOP-WTI-MENDS-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MENDS-MOM-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, symmetric long/short
- decision clock: the first executable D1 bar of a new broker month within the
  governed 180-minute restart boundary
- formation: strict sign agreement between the immediately prior broker
  month's first-five-session return and final-five-session return
- lifecycle: one fixed-risk WTI position held through the first five sessions
  of the new broker month

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The bounded governed packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` was read completely before
this decision. It preserves an end-to-end review of Tobias J. Moskowitz, Yao
Hua Ooi, and Lasse Heje Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The author-hosted 23-page published paper
retrieval has SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
The packet establishes the own-completed-return-sign continuation family,
reports commodity results at monthly cadence, and explicitly identifies
NYMEX WTI in the source universe.

The source does not test a WTI-only first-five/final-five agreement state,
exact month-boundary CFD entry, five-session hold, ATR stop, fixed-dollar
risk, or the QM portfolio. The two disjoint prior-month boundary segments,
strict agreement gate, exact broker-month clock, continuous-CFD mapping,
180-minute restart boundary, fixed risk, ATR stop, spread cap, and five-bar
exit are transparent QM falsification choices. No source return, alpha,
coefficient, significance, trade density, cost, drawdown, WTI-only efficacy,
CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

On each new `XTIUSD.DWX` D1 bar:

1. Repair or close malformed, duplicated, stale, or out-of-lifecycle owned
   exposure before applying entry-only gates.
2. Admit an entry decision only on the first executable D1 bar of a new broker
   month. Support only the governed native same-day energy label or one uniform
   `+1` calendar-day normalization when the raw D1 label is 24-48 hours behind
   broker time. Apply no other offset, holiday shift, or bar substitution.
3. Persist the exact current broker `yyyymm` attempt before history, signal,
   news, spread, quote, ATR, sizing, or order gates. Never retry the month. A
   first observation more than 180 minutes after the executable D1 session
   open consumes the attempt flat and may not be backfilled.
4. Reconstruct every positive, finite completed D1 close in the immediately
   prior normalized broker month plus the immediately preceding broker-month
   end. Require consecutive broker months, at least fifteen completed bars in
   the prior month, and endpoint identity with the newest completed bar.
5. Compute two non-overlapping completed-return segments:
   - `opening_return = log(PriorMonthFifthClose / PriorPriorMonthEndClose)`;
     and
   - `closing_return = log(PriorMonthEndClose / PriorMonthSixthFromEndClose)`.
   The first spans the boundary into the first five prior-month sessions; the
   second spans the final five close-to-close intervals. The current bar and
   the intervening middle-month path enter neither return.
6. BUY only when both returns are strictly positive and SELL only when both
   are strictly negative. Exact zero, invalid arithmetic, or sign disagreement
   consumes the month flat. Signal magnitude never scales risk.
7. Open at most one WTI position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, a frozen `3.5 * ATR(20,D1)` hard stop, no target, and a
   1,500-point entry spread ceiling.
8. Close on the first D1 bar after five normalized bars have completed in the
   entry broker month. Close earlier only for malformed ownership, a broker
   hard stop, the framework kill switch, a changed broker month, or the
   twelve-calendar-day stale guard. Both news axes and Friday close remain
   OFF so management and the fixed five-session lifecycle remain authoritative.

The endpoint identities, minimum prior-month bar count, two non-overlapping
boundary segments, strict agreement, first-bar clock, no-late-entry and
no-retry rules, fixed risk, stop, spread, and five-bar exit are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_TRANSLATION_RISK`: named authors, peer-reviewed JFE
  paper, DOI, complete-paper receipt, durable retrieval hash, explicit WTI
  membership, and monthly commodity continuation evidence; the untested
  boundary-segment agreement translation is explicit.
- R2 `PASS`: completed endpoints, exact segment indexes, sign agreement,
  decision clock, attempt state, direction, risk, stop, spread, and exits are
  deterministic and locked before Q02.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history supplies every runtime input;
  no external futures curve, inventory, event, or analyst feed is required.
- R4 `PASS`: deterministic native calendar, price, logarithm, ATR, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,510 EA-registry rows and 606 root
cards. It found no exact match and raised the expected fuzzy family matches to
`wti-mdual-mom` and `wti-mclose-mom`. Manual review fixes the material
boundaries:

- `QM5_41021_wti-mdual-mom` combines the entire completed prior-month return
  with its nested final-five return. This candidate discards the middle-month
  path and requires two non-overlapping boundary-segment signs; a large middle
  move can therefore make the two EAs take different decisions.
- `QM5_41016_wti-mclose-mom` follows the final-five sign alone. This candidate
  remains flat unless the independent opening segment agrees.
- `QM5_41013_wti-mopen-mom` observes the current month's first five sessions,
  enters on its sixth bar, and holds the residual month. This candidate uses
  only completed prior-month information, enters at the next boundary, and
  exits on the sixth current-month bar.
- `QM5_20187_wti-tsmom1m` forms on the full completed prior month and owns the
  full following month. This candidate neither reads the full-month return nor
  owns a full-month package.
- `QM5_13049_xti-1w-mom-vol` is a rolling any-day five-bar magnitude and
  volatility-state rule. This candidate is exact-calendar, sign-only,
  agreement-gated, and has no magnitude or volatility filter.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers. This candidate is a fixed-clock direct-WTI continuation
  rule without an oscillator or cross-carrier allocator.

Verdict:
`CLEAN_WTI_DISJOINT_PRIOR_MONTH_BOUNDARY_SEGMENT_AGREEMENT_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately 5-8 completed positions per full
post-warm-up year. Q02 must retire on zero trades, below five completed
positions per full year, overlapping or wrong segment indexes, a wrong or
substituted month boundary, current-bar leakage, late or repeated entry, a
disagreement-side trade, wrong five-bar lifecycle, invalid risk mode,
nondeterminism, or nonpositive governed economics. Short-horizon translation,
futures/CFD basis, spread, gaps, financing, roll construction, and later book
correlation are first-order risks. Q09 alone may establish realized
correlation with the certified book.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.
