# WTI Fixed Week-Closing Segment Momentum - Source Approval

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

- proposed slug: `wti-wclose-mom`
- proposed strategy ID: `MOP-WTI-WCLOSE-MOM-2026_S01`
- proposed source ID: `MOP-WTI-WCLOSE-MOM-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, symmetric long/short
- formation: the completed prior-Tuesday close through completed prior-Friday
  close, with an exact Tuesday/Wednesday/Thursday/Friday sequence
- decision clock: the first executable tick, within 180 minutes of the bar
  timestamp, of the immediately following broker Monday D1 bar
- lifecycle: one fixed-risk WTI position held through Monday and Tuesday and
  closed at the first following broker-Wednesday D1 boundary

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
   first twelve monthly lags, defines direction from the sign of completed own
   return, and explicitly includes NYMEX WTI in its commodity universe.
2. `strategy-seeds/sources/MOP-WTI-WOPEN-MOM-2026/source.md`, the governed
   complementary WTI weekly translation packet, records the source-to-CFD
   boundary for exact weekday sequences, completed-price endpoints, persistent
   attempts, fixed-dollar risk, known factory energy-label normalization, and
   no-late-entry behavior.

Moskowitz, Ooi, and Pedersen do not test a Tuesday-through-Friday WTI
formation, Monday entry, Wednesday exit, a standalone WTI sleeve, a Darwinex
continuous CFD, an ATR stop, fixed-dollar risk, transaction costs, or the QM
portfolio. The fixed broker-week segmentation is a transparent QM
falsification hypothesis, not a claimed replication. No source return,
Sharpe ratio, coefficient, significance result, trade density, drawdown, CFD
equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

On every new `XTIUSD.DWX` D1 bar:

1. Repair or close malformed, duplicated, stale, or out-of-lifecycle owned
   exposure before applying entry-only gates.
2. Admit an entry decision only on a broker Monday whose four immediately
   preceding completed D1 bars are exactly Friday, Thursday, Wednesday, and
   Tuesday. Missing holiday sessions are not shifted or substituted.
3. Require the first observed tick to be no more than 180 minutes after the
   Monday D1 bar timestamp. A later first observation consumes the week flat
   and may not backfill an entry.
4. Persist the exact Monday `yyyymmdd` attempt before signal history, news,
   spread, quote, ATR, sizing, or order gates. Never retry the week.
5. Compute `closing_return = log(PriorFridayClose / PriorTuesdayClose)` from
   positive, finite completed D1 closes. The current Monday bar and the
   intervening Wednesday/Thursday closes do not enter the return; those bars
   are required only as continuity observations.
6. BUY when `closing_return > 0`, SELL when `closing_return < 0`, and consume
   the week flat on exact zero or invalid history. Signal magnitude never
   scales risk.
7. Open at most one WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a
   frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point entry
   spread ceiling.
8. Close at the first genuine broker-Wednesday D1 boundary. A position
   surviving into Thursday or Friday, or for five calendar days, is stale and
   is closed before any new entry logic. Framework Friday close remains ON at
   broker hour 21 as an additional fail-safe.
9. Both news axes remain OFF. The framework kill switch and hard stop remain
   authoritative.

The exact weekday sequence, completed endpoints, sign map, no-shift rule,
180-minute restart boundary, attempt ledger, Wednesday exit, risk, stop,
spread, and stale repair are load-bearing.

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

The canonical pre-card checker scanned 4,507 EA-registry rows and 603 root
cards. It found no exact identity match and raised only the expected fuzzy
family match to `wti-wopen-mom`; manual review resolves that match. The
semantic boundaries are:

- `QM5_41019_wti-wopen-mom` forms from prior Friday through Tuesday, enters
  Wednesday, and exits Friday. This candidate forms over the disjoint late-
  week Tuesday-through-Friday segment, enters the following Monday, and exits
  Wednesday. Neither strategy shares signal endpoints, an entry day, or an
  owned holding segment.
- `QM5_20217_wti-wkend-mom` trades a Monday opening gap beyond Friday's range
  plus a volatility buffer and exits on the next D1 bar. This candidate
  excludes the Monday gap from its signal, uses a completed multi-session
  close-to-close sign without a magnitude threshold, and holds through
  Tuesday.
- `QM5_20149_wti-montrend` and `QM5_20173_wti-mon-bullfade` use a completed
  252-D1 state for one Monday session. This candidate uses only the prior
  Tuesday-to-Friday segment and is symmetric long/short.
- `QM5_20029_wti-monfri-daily` is an unconditional weekday rotation that
  shorts Monday and buys Friday. This candidate takes either Monday direction
  conditionally and never enters Friday.
- `QM5_12965_wti-week-orb`, `QM5_13075_xti-inweek-brk`, and
  `QM5_13095_xti-outweek-fade` use weekly range states, breakouts or fades,
  trend/range filters, and price levels. This candidate uses two completed
  closes and their sign only.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers. This candidate is a fixed-clock WTI weekly continuation
  with no oscillator or cross-carrier allocation.

Verdict:
`CLEAN_WTI_FIXED_WEEK_CLOSING_SEGMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately 45-52 completed positions per full
post-warm-up year before holiday and fail-closed exclusions. Q02 must retire
on zero trades, below five completed positions per full year, a wrong or
shifted weekday sequence, current-bar leakage, late or repeated entries,
carry past the Wednesday repair boundary, invalid risk mode, or nonpositive
governed economics. Weekly horizon translation, futures/CFD basis, spread,
gaps, financing, roll construction, and later book correlation are first-order
risks. Q09 alone may establish realized correlation with the certified book.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.
