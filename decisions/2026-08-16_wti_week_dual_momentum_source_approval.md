# WTI Split-Week Dual-Segment Momentum - Source Approval

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

- proposed slug: `wti-wdual-mom`
- proposed strategy ID: `MOP-ZHAO-WTI-WDUAL-MOM-2026_S01`
- proposed source ID: `MOP-ZHAO-WTI-WDUAL-MOM-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, symmetric long/short
- decision clock: the first executable Monday D1 tick within the governed
  180-minute restart boundary
- formation: strict sign agreement between the prior full broker week's
  disjoint opening segment (previous Friday close through Tuesday close) and
  closing segment (Tuesday close through Friday close)
- lifecycle: one fixed-risk WTI position held through the new broker week and
  flattened by the framework Friday close

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

Two bounded governed repository packets were read completely before this
decision:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md` preserves an end-to-end
   review of Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
   DOI `10.1016/j.jfineco.2011.11.003`. The author-hosted 23-page published
   paper retrieval has SHA-256
   `7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
   It establishes the own-completed-return-sign continuation family and
   explicitly identifies NYMEX WTI in its commodity-futures universe.
2. `strategy-seeds/sources/28681f5d-aa78-584e-9698-750d1402e485/source.md`
   and its complete governed research note at
   `D:/QM/strategy_farm/artifacts/source_notes/28681f5d-aa78-584e-9698-750d1402e485.md`
   preserve the accessible material for Shen Zhao, Yiyi Ding, Jianfeng Yu,
   and Wenjin Kang (2026), "Momentum and Reversal on the Short-Term Horizon:
   Evidence from Commodity Markets," SSRN 6425598, DOI
   `10.2139/ssrn.6425598`. Its accessible abstract/methodology material
   reports positive next-week prediction from the residual component of
   weekly commodity returns. The full text was inaccessible, and no missing
   table, coefficient, return, or parameter is reconstructed.

Neither source tests a WTI-only split-week agreement state, exact Monday CFD
entry, fixed Friday exit, ATR stop, fixed-dollar risk, or the QM portfolio.
Moskowitz, Ooi, and Pedersen use monthly rolled-futures excess returns; Zhao
et al. use an investor-position decomposition that is unavailable to the QM
runtime. The two disjoint completed-return segments, strict agreement gate,
exact broker-week clock, continuous-CFD mapping, 180-minute restart boundary,
fixed risk, ATR stop, spread cap, and Friday lifecycle are transparent QM
falsification choices. No source return, alpha, coefficient, significance,
trade density, cost, drawdown, WTI-only efficacy, CFD equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

On each new `XTIUSD.DWX` D1 bar:

1. Repair or close malformed, duplicated, stale, or out-of-lifecycle owned
   exposure before applying entry-only gates.
2. Admit an entry decision only when the broker clock is Monday. Support only
   the governed native same-day energy label or one uniform `+1` calendar-day
   normalization when the raw D1 label is 24-48 hours behind broker time.
   Apply no other offset, holiday shift, or bar substitution.
3. Require the six immediately preceding completed normalized D1 bars,
   newest first, to be the prior Friday, Thursday, Wednesday, Tuesday,
   Monday, and the preceding Friday, exactly 3, 4, 5, 6, 7, and 10 calendar
   days before the current Monday. A holiday-broken sequence consumes the
   current Monday flat.
4. Persist the exact current Monday `yyyymmdd` attempt before history,
   signal, news, spread, quote, ATR, sizing, or order gates. Never retry the
   Monday. A first observation more than 180 minutes after the executable D1
   session open consumes the attempt flat and may not be backfilled.
5. Require positive finite completed closes and compute:
   - `opening_return = log(PriorTuesdayClose / PrecedingFridayClose)`; and
   - `closing_return = log(PriorFridayClose / PriorTuesdayClose)`.
   The intervals share only the completed Tuesday endpoint and do not use the
   current Monday bar.
6. BUY only when both returns are strictly positive and SELL only when both
   are strictly negative. Exact zero, invalid arithmetic, or sign
   disagreement consumes the week flat. Signal magnitude never scales risk.
7. Open at most one WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a
   frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point entry
   spread ceiling.
8. Enable framework Friday close at broker hour 21. Close stale exposure on
   the first later broker-week boundary, after seven calendar days, or when
   ownership is malformed. Both news axes remain OFF; the framework kill
   switch and frozen broker hard stop remain authoritative.

The exact six-bar weekday sequence, two disjoint completed-return endpoints,
strict sign agreement, Monday clock, no-late-entry and no-retry rules, fixed
risk, stop, spread, and Friday exit are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_AND_ACCESS_RISK`: one named peer-reviewed JFE paper
  with DOI, complete-paper receipt, durable retrieval hash, and explicit WTI
  membership, plus one named 2026 SSRN working paper whose accessible bounded
  material supports weekly commodity continuation. The unavailable full text
  and untested split-week agreement translation are explicit.
- R2 `PASS`: exact weekday sequence, completed endpoints, sign agreement,
  decision clock, attempt state, direction, risk, stop, spread, and exits are
  deterministic and locked before Q02.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history supplies every runtime input;
  the EA does not attempt the Zhao et al. investor-position decomposition.
- R4 `PASS`: deterministic native calendar, price, logarithm, ATR, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,509 EA-registry rows and 605 root
cards. It found no exact match and raised the expected fuzzy family matches
to `wti-wopen-mom` and `wti-wclose-mom`. Manual review fixes the material
boundaries:

- `QM5_41019_wti-wopen-mom` measures the current week's Friday-to-Tuesday
  opening segment, enters Wednesday from that one sign, and exits Friday.
  This candidate observes the completed prior week's opening and closing
  segments, requires both signs to agree, enters the following Monday, and
  never owns the signal week.
- `QM5_41020_wti-wclose-mom` uses only the prior Tuesday-to-Friday closing
  sign, enters Monday, and exits Wednesday. This candidate adds the disjoint
  preceding-Friday-to-Tuesday opening sign as a load-bearing agreement gate
  and holds the admitted package through Friday.
- `QM5_41021_wti-mdual-mom` combines one completed broker-month return with a
  nested final-five-session return and owns the next month's first five
  sessions. This candidate uses two disjoint within-week segments, an exact
  six-bar weekday sequence, and weekly Friday flattening.
- `QM5_13049_xti-1w-mom-vol` uses a rolling five-D1 magnitude threshold, a
  rolling realized-volatility rank, any-new-day evaluation, and reversal/time
  exits. This candidate is exact-calendar, sign-only, agreement-gated, and
  has no magnitude or volatility filter.
- `QM5_21521_wti-flow-switch` classifies non-overlapping tick-volume tails and
  switches between continuation and reversal. This candidate reads no volume
  and always remains flat when its two price segments disagree.
- `QM5_12965_wti-week-orb` and related weekly-range EAs use highs, lows,
  breakout geometry, and range filters. This candidate uses completed closes
  and no breakout level.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers. This candidate is a fixed-clock direct-WTI
  continuation rule without an oscillator or cross-carrier allocator.

Verdict:
`CLEAN_WTI_DISJOINT_SPLIT_WEEK_AGREEMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately 20-35 completed positions per full
post-warm-up year. Q02 must retire on zero trades, below five completed
positions per full year, a wrong or holiday-shifted weekday sequence,
current-bar leakage, late or repeated entries, a disagreement-side trade,
wrong Friday lifecycle, invalid risk mode, nondeterminism, or nonpositive
governed economics. Short-horizon translation, futures/CFD basis, spread,
gaps, financing, roll construction, and later book correlation are
first-order risks. Q09 alone may establish realized correlation with the
certified book.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.
