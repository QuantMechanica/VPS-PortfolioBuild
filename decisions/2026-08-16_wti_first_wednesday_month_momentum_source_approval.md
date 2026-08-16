# WTI First-Wednesday / Prior-Month Momentum - Source Approval

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

- proposed slug: `wti-1wed-mom1`
- proposed strategy ID: `LI-MOP-WTI-1WED-MOM1-2026_S01`
- proposed source ID: `LI-MOP-WTI-1WED-MOM1-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, symmetric long/short
- decision clock: the first genuine Wednesday D1 session of each normalized
  broker month, within the governed 180-minute restart boundary
- formation: sign of the immediately completed broker-calendar month's WTI
  close-to-close log return
- lifecycle: one fixed-risk WTI position closed at the first following D1
  boundary

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

Two already approved repository source packets were read completely before
this decision:

1. `strategy-seeds/sources/LI-WTI-DOW-2022.md` preserves Wenhui Li, Qi Zhu,
   Fenghua Wen, and Normaziah Mohd Nor (2022), "The evolution of
   day-of-the-week and the implications in crude oil market," *Energy
   Economics* 106, 105817, DOI `10.1016/j.eneco.2022.105817`. Its explicitly
   bounded abstract/highlights evidence reports an abnormal positive Wednesday
   WTI return and time-varying weekday efficiency.
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md` preserves a complete-paper
   review of Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
   DOI `10.1016/j.jfineco.2011.11.003`. The author-hosted 23-page paper receipt
   has SHA-256
   `7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
   The source defines instrument-own return-sign continuation, monthly
   formation/holding variants, and explicitly includes NYMEX WTI.

The sources do not test their exact conjunction. Li et al. do not condition
the Wednesday effect on the preceding calendar month or prescribe a
long/short rule. Moskowitz, Ooi, and Pedersen do not use the first Wednesday as
an entry clock or a one-session hold. The composite clock, short-hold
translation, continuous-CFD mapping, normalized energy labels, fixed cash
risk, ATR stop, spread cap, and restart ledger are transparent QM
falsification choices. No source return, coefficient, significance, trade
density, cost, drawdown, CFD equivalence, decorrelation, or portfolio result
transfers.

## Locked Mechanic

On each new `XTIUSD.DWX` D1 bar:

1. Repair or close malformed, duplicated, stale, or out-of-lifecycle owned
   exposure before applying entry-only gates.
2. Normalize the raw D1 label by either zero or one uniform `+1` calendar day,
   using the same governed energy-label rule as the current WTI builds. Admit
   a decision only when the normalized bar date equals the broker date, is a
   Wednesday, falls on calendar day 1-7, and the immediately prior normalized
   D1 label is Tuesday. A missing/holiday first Wednesday is not shifted.
3. Require the first observed tick within 180 minutes of the executable D1
   session open. Persist the exact broker `yyyymm` attempt before history,
   signal, news, spread, quote, ATR, sizing, or order gates. Never retry the
   month or backfill a late attachment.
4. Reconstruct the newest positive finite completed D1 close in the immediately
   prior normalized broker month and the newest completed close in the month
   before it. Require both exact consecutive month keys and strict timestamp
   order. Current-month bars and the live bar enter neither endpoint.
5. Compute `prior_month_return = log(PriorMonthEnd /
   PriorPriorMonthEnd)`. BUY when it is strictly positive and SELL when it is
   strictly negative. Exact zero or invalid history/arithmetic consumes the
   month flat. Signal magnitude never scales risk.
6. Open at most one WTI position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.0 * ATR(20,D1)` hard stop, no target, and a 1,500-point entry spread
   ceiling.
7. Close on the first following normalized D1 boundary, after five calendar
   days as a stale guard, or for malformed ownership. Friday close remains
   enabled at broker hour 21; both news axes remain OFF.

The first-Wednesday month clock, completed-calendar-month endpoint identity,
strict sign direction, no-late-entry/no-retry rules, one-session lifecycle,
fixed risk, stop, and spread ceiling are load-bearing. No weekday, horizon,
hold, stop, or threshold sweep is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: two named-author peer-reviewed
  primary papers with DOI identity; the MOP paper has complete-text evidence
  and a durable hash, while the Li packet explicitly limits itself to the
  published abstract/highlights boundary. The untested conjunction and
  shortened hold are disclosed.
- R2 `PASS`: exact calendar clock, normalized labels, endpoint months, return
  sign, direction, attempt state, entry grace, risk, stop, spread, and exit are
  deterministic and locked before Q02.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history supplies every runtime
  input; no futures curve, inventory, event, analyst, CSV, or API feed is
  required.
- R4 `PASS`: deterministic native calendar, price, logarithm, ATR, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,511 EA-registry rows and 607 root
cards and returned `CLEAN` with no exact or fuzzy match above threshold for
slug `wti-1wed-mom1`, strategy ID
`LI-MOP-WTI-1WED-MOM1-2026_S01`, and the exact first-Wednesday/prior-month
mechanic. Manual semantic review fixes the material boundaries:

- `QM5_20154_wti-wed-trend` evaluates every genuine Wednesday, buys only in a
  positive completed 252-D1 state, and never uses completed calendar months.
- `QM5_20170_wti-wed-bear` evaluates every genuine Wednesday and buys a
  negative 252-D1 state as a bounce; this candidate instead trades once per
  month in the prior-month return direction.
- `QM5_20022_wti-wed-long` and `QM5_12775_wti-wed-prem` are unconditional
  Wednesday-long packages without a completed-month state.
- `QM5_20187_wti-tsmom1m` enters at the month boundary and owns the following
  month; this candidate waits for the first genuine Wednesday and owns one D1
  session.
- `QM5_41013_wti-mopen-mom` forms from the first five sessions of the current
  month and enters on session six; this candidate uses the completed prior
  month and only the first Wednesday clock.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers. This candidate is fixed-clock direct-WTI continuation
  without an oscillator or cross-carrier allocator.

Verdict:
`CLEAN_WTI_FIRST_WEDNESDAY_PRIOR_MONTH_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed packages per full
post-warm-up year. Q02 must retire on zero trades, below five completed
positions per full year, a wrong/shifted Wednesday, wrong month endpoints,
current-bar leakage, late or repeated entry, sign/direction mismatch, hold
beyond the next D1 boundary, invalid risk mode, nondeterminism, or nonpositive
governed economics. Source decay, monthly-to-daily hold translation,
futures/CFD basis, broker-label mapping, spread, gaps, financing, and later
book correlation are first-order risks. Q09 alone may establish realized
correlation with the certified book.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.
