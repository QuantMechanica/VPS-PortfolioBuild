# WTI Fixed Week-Opening Segment Momentum - Source Approval

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

- proposed slug: `wti-wopen-mom`
- proposed strategy ID: `MOP-WTI-WOPEN-MOM-2026_S01`
- proposed source ID: `MOP-WTI-WOPEN-MOM-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, symmetric long/short
- formation: completed prior-Friday close through completed Tuesday close,
  with an exact Monday/Tuesday sequence
- decision clock: the first executable tick, within 180 minutes of the bar
  timestamp, of the immediately following broker Wednesday D1 bar
- lifecycle: one fixed-risk WTI position held through the balance of the
  broker week and flattened by the framework Friday-close boundary

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The following complete governed repository evidence was read before this
decision:

1. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete 23-page published-paper review
   is preserved at `strategy-seeds/sources/MOP-TSMOM-2012/source.md`; its
   author-hosted PDF retrieval SHA-256 is
   `7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
   The paper reports positive own-return continuation across futures at the
   first twelve monthly lags, defines direction from the sign of completed
   own return, and explicitly includes NYMEX WTI in its commodity universe.
2. `strategy-seeds/sources/MOP-WTI-MOPEN-MOM-2026/source.md`, the governed
   earlier WTI translation packet, records the source-to-CFD boundary for a
   fixed calendar segment, completed-price endpoints, persistent attempt,
   fixed-dollar risk, and no-late-entry behavior.

Moskowitz, Ooi, and Pedersen do not test a two-session Monday/Tuesday WTI
formation, Wednesday entry, Friday close, a standalone WTI sleeve, a Darwinex
continuous CFD, an ATR stop, fixed-dollar risk, transaction costs, or the QM
portfolio. The fixed broker-week segmentation is a transparent QM
falsification hypothesis, not a claimed replication. No source return,
Sharpe ratio, coefficient, significance result, trade density, drawdown, CFD
equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

On every new `XTIUSD.DWX` D1 bar:

1. Repair or close malformed, duplicated, stale, or out-of-lifecycle owned
   exposure before applying entry-only gates.
2. Admit an entry decision only on a broker Wednesday whose three immediately
   preceding completed D1 bars are exactly Tuesday, Monday, and the prior
   Friday. Missing holiday sessions are not shifted or substituted.
3. Require the first observed tick to be no more than 180 minutes after the
   Wednesday D1 bar timestamp. A later first observation consumes the week
   flat and may not backfill an entry.
4. Persist the exact Wednesday `yyyymmdd` attempt before signal history, news,
   spread, quote, ATR, sizing, or order gates. Never retry the week.
5. Compute `opening_return = log(TuesdayClose / PriorFridayClose)` from
   positive, finite completed D1 closes. The current Wednesday bar and Monday
   close do not enter the return; Monday is required only as a continuity
   observation.
6. BUY when `opening_return > 0`, SELL when `opening_return < 0`, and consume
   the week flat on exact zero or invalid history. Signal magnitude never
   scales risk.
7. Open at most one WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a
   frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point entry
   spread ceiling.
8. Hold through the balance of the week and let the framework Friday-close
   boundary flatten at broker hour 21. A position surviving into Sunday,
   Monday, or Tuesday, or for six calendar days, is stale and is closed before
   any new entry logic.
9. Both news axes remain OFF. The framework kill switch and hard stop remain
   authoritative.

The exact weekday sequence, completed endpoints, sign map, no-shift rule,
180-minute restart boundary, attempt ledger, Friday close, risk, stop, spread,
and stale repair are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_TRANSLATION_RISK`: one named peer-reviewed JFE paper,
  DOI identity, complete-paper receipt, durable retrieval hash, explicit WTI
  membership, and a disclosed weekly-segment translation not tested by the
  paper.
- R2 `PASS`: weekdays, endpoint order, completed-bar boundary, strict sign,
  attempt state, entry grace, direction, risk, stop, spread, and exits are
  deterministic and locked before Q02.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history supplies every runtime input.
- R4 `PASS`: deterministic native calendar, price, logarithm, ATR, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,506 EA-registry rows and 602 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review fixes
the semantic boundaries:

- `QM5_41013_wti-mopen-mom` forms on the first five sessions of a broker month,
  decides on the sixth, and holds to the next month. This candidate owns an
  exact Friday-Monday-Tuesday weekly segment, decides Wednesday, and closes
  Friday.
- `QM5_12965_wti-week-orb` trades a later break of Monday's high/low with SMA,
  ATR-range, buffer, and close-location filters. This candidate has no range
  breakout or signal indicator and decides only from the opening segment's
  net return sign.
- `QM5_13049_xti-1w-mom-vol` evaluates a rolling five-D1 thresholded return,
  requires a realized-volatility percentile state, and exits on time or
  reversal. This candidate uses an exact two-session weekly segment, sign
  only, no volatility signal gate, and a fixed Friday close.
- `QM5_20154_wti-wed-trend` uses a completed 252-D1 return state on Wednesday
  and holds at most two days. This candidate uses only the current broker
  week's Friday-to-Tuesday opening segment.
- `QM5_20217_wti-wkend-mom` trades a Monday gap outside Friday's range plus a
  volatility buffer and exits next D1. This candidate enters Wednesday from
  completed Monday/Tuesday continuation and does not use a gap, range, or
  volatility signal.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback rather than
  a fixed-clock WTI weekly continuation.

Verdict:
`CLEAN_WTI_FIXED_WEEK_OPENING_SEGMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately 45-52 completed positions per full
post-warm-up year before holiday and fail-closed exclusions. Q02 must retire
on zero trades, below five completed positions per full year, a wrong or
shifted weekday sequence, current-bar leakage, late or repeated entries,
weekend carry past the repair boundary, invalid risk mode, or nonpositive
governed economics. Weekly horizon translation, futures/CFD basis, spread,
gaps, financing, roll construction, and later book correlation are first-order
risks. Q09 alone may establish realized correlation with the certified book.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.
