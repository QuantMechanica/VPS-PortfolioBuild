# WTI Month-Boundary Dual-Horizon Momentum - Source Approval

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

- proposed slug: `wti-mdual-mom`
- proposed strategy ID: `MOP-WTI-MDUAL-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MDUAL-MOM-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, symmetric long/short
- decision clock: the first executable tick, within five minutes of the bar
  timestamp, of the first D1 bar in a new broker month
- formation: agreement between the immediately completed broker-month return
  and the return across that same month's final five close-to-close intervals
- lifecycle: one fixed-risk WTI position held through the first five completed
  D1 bars of the new broker month and closed at the first tick of bar six

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The complete governed repository packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` was read before this
decision. It preserves an end-to-end review of Tobias J. Moskowitz, Yao Hua
Ooi, and Lasse Heje Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The author-hosted 23-page published-paper
retrieval has SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The paper reports positive own-return continuation over the first twelve
monthly lags, defines direction from the sign of completed own return, and
explicitly includes NYMEX WTI in its commodity-futures universe. It does not
test agreement between a completed WTI month and its final five sessions, a
first-new-month entry, a five-session hold, WTI alone, a continuous CFD, an
ATR stop, or fixed-dollar risk.

The dual endpoint reconstruction, strict same-sign gate, exact broker-month
clock, five-minute restart boundary, one consumed attempt, continuous-CFD
mapping, fixed risk, ATR stop, spread cap, and five-session lifecycle are
transparent QM falsification choices. No source return, alpha, coefficient,
significance, trade density, cost, drawdown, WTI-only efficacy, CFD
equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

On each new `XTIUSD.DWX` D1 bar:

1. Repair or close malformed, duplicated, stale, or out-of-lifecycle owned
   exposure before applying entry-only gates.
2. Admit an entry decision only on the first D1 bar of a new broker month.
   Require the first observed tick no more than five minutes after the raw D1
   bar timestamp. A later first observation consumes the month flat and may
   not backfill an entry.
3. Persist the exact current `yyyymm` attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates. Never retry the month.
4. Reconstruct the immediately prior broker-month-end close and the broker-
   month-end close immediately before it. Require consecutive completed
   broker months, positive finite closes, and no current-bar price in either
   return.
5. Require the six immediately preceding completed D1 bars to belong to the
   immediately prior broker month, with the newest close equal to that
   month's final completed close. Compute:
   - `month_return = log(prior_month_end / prior_prior_month_end)`; and
   - `closing_return = log(prior_month_end / prior_month_close_6)`, covering
     the final five completed close-to-close intervals.
6. BUY only when both returns are strictly positive and SELL only when both
   are strictly negative. Exact zero, invalid arithmetic, or sign
   disagreement consumes the month flat. Signal magnitude never scales risk.
7. Open at most one WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a
   frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point entry
   spread ceiling.
8. Close at the first tick of the sixth D1 bar in the entry broker month. A
   premature month change, twelve calendar days, or malformed exposure is a
   stale repair boundary. Friday close and both news axes remain OFF so they
   do not truncate the fixed five-session carrier.
9. The framework kill switch and frozen broker hard stop remain authoritative.

The two completed-return endpoints, prior-month membership, strict sign
agreement, exact decision clock, no-late-entry and no-retry rules, fixed risk,
stop, spread, and five-session exit are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_TRANSLATION_RISK`: one named peer-reviewed JFE paper,
  DOI identity, complete-paper receipt, durable retrieval hash, explicit WTI
  membership, and a disclosed short-segment agreement translation not tested
  by the paper.
- R2 `PASS`: endpoints, month membership, sign agreement, decision clock,
  attempt state, direction, risk, stop, spread, and exits are deterministic
  and locked before Q02.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history supplies every runtime input.
- R4 `PASS`: deterministic native calendar, price, logarithm, ATR, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,508 EA-registry rows and 604 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review fixes
the material family boundaries:

- `QM5_41016_wti-mclose-mom` uses only the final-five-interval sign and enters
  every valid month. This candidate also requires the independent complete-
  month sign to agree; disagreement is a load-bearing flat state.
- `QM5_20187_wti-tsmom1m` follows the completed-month sign unconditionally and
  owns the full following month. This candidate adds the final-five agreement
  gate and owns only the following month's first five sessions.
- `QM5_20056_wti-dual-mom` and
  `QM5_12711_commodity-tsmom-dual-6-12` compare medium/long monthly horizons
  and hold monthly packages. This candidate compares a complete one-month
  return with a nested five-session closing segment at an exact boundary and
  exits after five sessions.
- `QM5_20244_wti-trend-sign` compares a twelve-month return with the breadth
  of twelve individual monthly signs. It has neither a final-five segment nor
  this short owned lifecycle.
- `QM5_13049_xti-1w-mom-vol` uses a rolling five-D1 magnitude threshold, a
  volatility-rank gate, and an any-new-day clock. This candidate is once per
  broker month, sign-only, and uses no magnitude or volatility filter.
- `QM5_41013_wti-mopen-mom` forms on the first five current-month sessions,
  enters on bar six, and holds the residual month. This candidate is already
  flat at bar six and uses only prior-month information.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers. This candidate is fixed-clock WTI continuation without
  an oscillator or cross-carrier allocator.

Verdict:
`CLEAN_WTI_MONTH_AND_CLOSING_SEGMENT_AGREEMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately six to ten completed positions per full
post-warm-up year. Q02 must retire on zero trades, below five completed
positions per full year, a wrong or nonconsecutive month reconstruction,
current-bar leakage, late or repeated entries, a disagreement-side trade,
wrong hold length, invalid risk mode, nondeterminism, or nonpositive governed
economics. Short-horizon translation, futures/CFD basis, spread, gaps,
financing, roll construction, and later book correlation are first-order
risks. Q09 alone may establish realized correlation with the certified book.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.
