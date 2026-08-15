# WTI Day-of-Month Counter-Regime — Source Approval

Date: 2026-08-15

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue authority is not authority to dispatch
a manual tester or exceed the active factory resource ceiling.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requests one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, requires reputable-source criteria and `RISK_FIXED`
backtests, and forbids live and portfolio mutations.

## Candidate Identity

- proposed slug: `wti-dom-ctrreg`
- proposed strategy ID: `BOROWSKI-MOP-WTI-DOMCOUNTER-2026_S01`
- proposed source ID: `BOROWSKI-MOP-WTI-DOMCOUNTER-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1
- decision clock: the first executable tick of an actual broker D1 bar dated
  exactly the 8th or 26th of a month
- signal: trade Borowski's WTI numbered-day direction only when it opposes the
  sign of WTI's completed 252-D1 own-price return
- lifecycle: at most one exact-date attempt, one position, and a next-D1 exit

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The following complete governed repository evidence was read before this
decision:

1. Krzysztof Borowski (2016), "Analysis of Selected Seasonality Effects in
   Markets of Future Contracts with the Following Underlying Instruments:
   Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle,
   Live Cattle, Lean Hogs and Lumber," *Journal of Management and Financial
   Sciences*, issue 26, pages 27-44. The complete-paper review, method,
   sample, limitations, and WTI numbered-day results are preserved at
   `strategy-seeds/sources/BOROWSKI-WTI-DOM26-2016/source.md`, with the
   positive day-8 direction and reported `p=0.0430` preserved in
   `strategy-seeds/cards/approved/QM5_20036_wti-dom8-long_card.md`. The same
   WTI table reports day 26 negative with `p=0.0424`.
2. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete 23-page published-paper
   review is preserved at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`; its retrieved PDF
   SHA-256 is
   `7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
3. `strategy-seeds/sources/BOROWSKI-MOP-WTI-DOMTREND-2026/source.md`, the
   governed prior composite, records the exact-date execution boundary and
   the complete-read relationship between those two parent lineages.

Borowski supplies the day-8 long and day-26 short calendar directions.
Moskowitz, Ooi, and Pedersen supply the completed own-return sign as a slow
state, not the counter-regime conjunction. Neither paper tests this
interaction, a continuous Darwinex CFD, the exact broker calendar, an ATR
stop, fixed-dollar risk, transaction costs, or the QM portfolio. No source
return, profit factor, drawdown, trade density, CFD equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

On every new `XTIUSD.DWX` D1 bar:

1. Close owned exposure if the current D1 bar differs from the entry bar, if
   the position side is malformed, or if one calendar day has elapsed. This
   management path runs before all entry-only gates.
2. Admit an entry decision only when the broker-calendar day is exactly 8 or
   26 and the first observed tick is within five minutes of that D1 bar's
   opening timestamp. Never shift a missing weekend or holiday date.
3. Persist the exact `yyyymmdd` attempt before history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry the date.
4. Compute `slow_return = log(Close[1] / Close[253])` from exactly 253
   positive finite completed D1 closes. Current-bar prices never enter the
   state.
5. On exact day 8, BUY only when `slow_return < 0`. On exact day 26, SELL only
   when `slow_return > 0`. Exact zero, invalid history, or the other
   date/sign combinations consume the date flat.
6. Open at most one WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a
   frozen `2.75 * ATR(20,D1)` hard stop, no target, and a 2,500-point spread
   ceiling. Signal magnitude never scales risk.
7. Close at the first following D1 boundary. Framework Friday close remains
   enabled at broker hour 21 as a fail-safe; both news axes remain OFF.

The exact dates, source directions, opposing completed-return state, completed
endpoints, no-shift rule, attempt ledger, one-session hold, risk, stop, spread,
and lifecycle are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_MULTIPLE_TESTING_RISK`: one named peer-reviewed commodity-
  seasonality paper with a complete governed review and exact WTI table
  locations, plus one peer-reviewed JFE paper with a complete-paper receipt,
  DOI, and retrieval hash. The untested conjunction and Borowski's many-cell
  search are explicit.
- R2 `PASS`: dates, calendar handling, completed endpoints, strict sign map,
  attempt state, direction, risk, stop, spread, and exit are deterministic and
  locked before Q02.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history supplies every runtime input.
- R4 `PASS`: deterministic native calendar, price, logarithm, and ATR
  arithmetic only; no trained output, banned signal indicator, external feed,
  grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,504 EA-registry rows and 600 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review fixes
the semantic boundaries:

- `QM5_20036_wti-dom8-long` buys every eligible exact day 8 and has no slow
  state or day-26 arm.
- `QM5_20027_wti-dom26-short` sells every eligible exact day 26 and has no
  slow state or day-8 arm.
- `QM5_20215_wti-dom-trend` buys day 1 only in a positive 252-D1 state and
  sells day 26 only in a negative state. This candidate uses the significant
  day-8 long arm and requires the opposite state on both arms; its shared
  day-26 signals are mutually exclusive with that build.
- `QM5_12603_wti-tsmom12m` renews a symmetric directional WTI position on a
  monthly clock and has no exact-date or one-session calendar object.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback rather than
  an exact numbered-day/slow-state conjunction.

Verdict:
`CLEAN_WTI_EXACT_DAY8_DAY26_COUNTER_REGIME_CALENDAR_AFTER_MANUAL_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately six to ten completed positions per full
post-warm-up year. Q02 must retire on zero trades, below five/year, a wrong or
shifted date, a non-opposing slow state, current-bar leakage, repeated
attempts, or nonpositive governed economics. Q09 alone may establish realized
correlation with the certified book; a WTI carrier is not proof of
decorrelation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.
