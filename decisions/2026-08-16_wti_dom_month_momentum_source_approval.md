# WTI Day-of-Month / Prior-Month Momentum - Source Approval

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

- proposed slug: `wti-dom-mom1`
- proposed strategy ID: `BOROWSKI-MOP-WTI-DOMMOM1-2026_S01`
- proposed source ID: `BOROWSKI-MOP-WTI-DOMMOM1-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, symmetric long/short
- calendar clock: exact normalized broker day 8 long or day 26 short, with no
  missing-date substitution
- price state: sign of WTI's immediately completed broker-calendar-month
  return, measured from the two preceding consecutive month-end closes
- lifecycle: one fixed-risk WTI position closed at the first following D1
  boundary

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

Two already approved repository packets were read completely before this
decision:

1. `strategy-seeds/sources/BOROWSKI-WTI-DOM26-2016/source.md` preserves the
   complete review of Krzysztof Borowski (2016), "Analysis of Selected
   Seasonality Effects in Markets of Future Contracts with the Following
   Underlying Instruments: Crude Oil, Brent Oil, Heating Oil, Gas Oil,
   Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and Lumber,"
   *Journal of Management and Financial Sciences* 26, 27-44. The paper's WTI
   numbered-day table reports a positive day-8 anomaly (`p=0.0430`) and a
   negative day-26 anomaly (`p=0.0424`) in NYMEX data through 2016-03-31.
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md` preserves an end-to-end
   review of Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen
   (2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
   228-250, DOI `10.1016/j.jfineco.2011.11.003`. The author-hosted 23-page
   paper receipt has SHA-256
   `7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
   Section 3.2 defines direction from an instrument's own completed-return
   sign, Table 2 explicitly includes the `k=1`, `h=1` commodity family, and
   Appendix A includes NYMEX WTI.

Neither paper tests the exact conjunction below. Borowski does not condition
the numbered-day cells on a completed-month WTI state. Moskowitz, Ooi, and
Pedersen do not use exact calendar days or a one-D1 hold. The conjunction,
continuous-CFD carrier, broker-label normalization, 180-minute attachment
boundary, fixed cash risk, ATR stop, spread cap, and restart ledger are
transparent QM falsification choices. No source return, coefficient,
significance beyond the cited cells, trade density, cost, drawdown, CFD
equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

On each new `XTIUSD.DWX` D1 bar:

1. Repair or close malformed, duplicated, stale, or out-of-lifecycle owned
   exposure before applying entry-only gates.
2. Normalize the raw D1 label by only the governed native same-day or uniform
   `+1` calendar-day energy convention. Require the normalized date to equal
   the broker date and its calendar day to be exactly 8 or 26. A missing date
   is skipped and never shifted.
3. Require the first observed tick within 180 minutes of the executable D1
   session open. Persist the exact normalized `yyyymmdd` attempt before
   history, signal, news, spread, quote, ATR, sizing, or order gates. Never
   retry or backfill the date.
4. Reconstruct the newest completed D1 closes in the two broker months
   immediately before the current normalized month. Require positive finite
   prices, strict timestamp order, and exact consecutive month keys. Current-
   month bars and the live bar enter neither endpoint.
5. Compute `prior_month_return = log(PriorMonthEnd /
   PriorPriorMonthEnd)`. On exact day 8, BUY only when the return is strictly
   positive. On exact day 26, SELL only when it is strictly negative. Exact
   zero, invalid history, or a disagreeing sign consumes the date flat.
   Signal magnitude never scales risk.
6. Open at most one WTI position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `2.75 * ATR(20,D1)` hard stop, no target, and a 2,500-point entry-spread
   ceiling.
7. Close on the first following normalized D1 boundary, after five calendar
   days as a stale guard, or for malformed ownership. Framework Friday close
   remains enabled at broker hour 21; both news axes remain OFF.

The exact day-8/day-26 clock, completed-calendar-month endpoint identity,
agreement sign/direction map, no-shift/no-late-entry/no-retry rules, fixed
risk, hard stop, and one-D1 lifecycle are load-bearing. No day, horizon,
direction, stop, hold, or threshold sweep is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_AND_MULTIPLE_TESTING_RISK`: two named-author,
  peer-reviewed primary papers with complete repository reviews, DOI/hash
  evidence for MOP, explicit WTI membership, and exact Borowski WTI table
  cells; the untested conjunction, Borowski multiple testing, and post-2016
  decay are disclosed.
- R2 `PASS`: normalized date, month endpoints, return sign, direction,
  attempt state, entry grace, risk, stop, spread, and exit are deterministic
  and locked before Q02.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history supplies every runtime input.
  Its session offset is directly measured in
  `framework/registry/session_offset_minutes.csv`; no futures curve,
  inventory, event, analyst, CSV, or API feed is required.
- R4 `PASS`: deterministic native calendar, OHLC, logarithm, ATR, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,512 EA-registry rows and 608 root
cards. It found no exact match and raised only the expected fuzzy family match
to `wti-dom-ctrreg`. Manual semantic review fixes the material boundaries:

- `QM5_41017_wti-dom-ctrreg` uses the same exact days but admits day 8 only
  in a negative completed 252-D1 state and day 26 only in a positive state.
  This candidate instead requires agreement with the immediately completed
  calendar month. The shared-date signals are mutually exclusive whenever
  the 252-D1 and one-month signs agree.
- `QM5_20215_wti-dom-trend` uses day 1 long and day 26 short with a completed
  252-D1 state. This candidate replaces day 1 with Borowski's source-
  significant day 8 and uses exact consecutive calendar-month endpoints.
- `QM5_20036_wti-dom8-long` and `QM5_20027_wti-dom26-short` are unconditional
  parent cells. This candidate remains flat unless the independent
  completed-month state agrees.
- `QM5_20187_wti-tsmom1m` enters at a month boundary and owns a full monthly
  package. This candidate uses the month return only as a gate at two sparse
  physical-market calendar clocks and owns one D1 interval.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers. This candidate is direct WTI calendar/trend logic with
  no oscillator or cross-carrier allocator.

Verdict:
`CLEAN_WTI_DAY8_DAY26_PRIOR_MONTH_AGREEMENT_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately six to ten completed positions per full
post-warm-up year. Q02 must retire on zero trades, below five completed
positions per year, a wrong or shifted date, wrong month endpoints, current-
bar leakage, late or repeated entry, sign/direction mismatch, wrong lifecycle,
invalid risk mode, nondeterminism, or nonpositive governed economics.
Multiple testing, post-2016 decay, futures/CFD basis, broker-label mapping,
spread, gaps, financing, and later book correlation are first-order risks.
Q09 alone may establish realized correlation with the certified book.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.
