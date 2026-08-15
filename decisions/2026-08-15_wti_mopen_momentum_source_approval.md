# WTI Month-Opening Momentum — Source Approval

Date: 2026-08-15

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue authority is not authority to dispatch
a manual tester or to exceed the active factory resource ceiling.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requests one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, requires reputable-source criteria and `RISK_FIXED`
backtests, and forbids live and portfolio mutations.

## Candidate Identity

- proposed slug: `wti-mopen-mom`
- proposed strategy ID: `MOP-WTI-MOPEN-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MOPEN-MOM-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1
- decision clock: first processed WTI D1 bar after exactly five completed D1
  bars exist in the new broker month
- signal: follow the sign of the return from the prior completed broker-month
  end through the fifth completed D1 close of the current month
- lifecycle: hold the package only through the residual broker month

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The complete governed packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` was read before this
decision. It records a complete read of Moskowitz, Ooi, and Pedersen (2012),
"Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`. The retrieved 23-page published-paper
SHA-256 is
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The paper supplies the structural own-return-sign continuation family,
monthly renewal, and explicit WTI membership in its commodity-futures
universe. It does not test a five-D1-bar formation interval, a fixed
month-opening decision clock, a residual-month hold, WTI alone, or a
Darwinex continuous CFD.

The five completed current-month bars, prior-month-end anchor, exact broker
calendar, one consumed attempt, continuous-CFD mapping, fixed risk, ATR stop,
spread cap, and restart lifecycle are disclosed QM translations. No source
return, Sharpe ratio, coefficient, significance, density, cost, drawdown,
WTI-only efficacy, decorrelation, or portfolio result transfers.

## Locked Mechanic

On each new `XTIUSD.DWX` D1 bar:

1. Close any owned package whose entry broker month differs from the current
   broker month. Retry the close until flat; do not suspend this management
   path for news or entry gates.
2. Count completed D1 bars in the current broker month. If the count is below
   five, wait. If it is above five and the current month has no durable attempt
   record, consume the month flat; never make a late entry after restart.
3. When the count is exactly five, persist the current `yyyymm` attempt before
   history, signal, news, spread, quote, sizing, or order gates. Never retry the
   same month.
4. Require those five bars to be the first five positive, finite completed D1
   closes of the current broker month and require the immediately preceding
   positive, finite completed D1 close to belong to the prior broker month.
5. Compute `log(close_fifth / close_prior_month_end)`. Buy WTI when it is
   strictly positive, sell WTI when it is strictly negative, and stay flat on
   exact zero or invalid state.
6. Open at most one WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a
   frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread
   ceiling. Signal magnitude never scales risk.
7. Close on the first D1 bar of the next broker month, after thirty-five
   calendar days, or when owned exposure is malformed. Friday close and both
   news axes are OFF for the source-aligned residual-month hold.

The carrier, six-bar endpoint construction, exact first-five count, prior-
month anchor, return sign, no-late-entry rule, one-attempt state, direction,
risk, stop, spread, and month-renewal lifecycle are load-bearing.

## Reputable-Source Criteria

- R1 `PASS`: exactly one governed source ID, backed by a named peer-reviewed
  JFE paper, DOI, complete-paper review evidence, and a durable retrieval hash.
  The untested horizon and calendar translation are explicit.
- R2 `PASS`: endpoints, bar count, decision clock, direction, attempt, risk,
  stop, spread, and exit are deterministic and locked before Q02.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history supplies every runtime input.
- R4 `PASS`: deterministic native price/calendar arithmetic only; no trained
  output, banned signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,500 EA-registry rows and 596 root-card files
and returned `CLEAN`, with no exact or fuzzy match. Manual review separates:

- `QM5_12810_wti-month-orb`: first-five-bar high/low box, later breakout,
  SMA/range/location filters, and variable trigger time; the proposed rule
  uses only the signed opening-segment return and enters at one fixed clock;
- `QM5_13049_xti-1w-mom-vol`: rolling five-D1 return magnitude plus a realized-
  volatility regime and five-day hold; the proposed rule is once per broker
  month, has no magnitude/volatility gate, and holds only the residual month;
- `QM5_20187_wti-tsmom1m`: prior complete broker-month formation and next full-
  month hold; the proposed formation is inside the current month and never
  crosses the decision boundary; and
- `QM5_20008_wti-month-ch3`: completed-month close versus three prior monthly
  extrema; the proposed mechanic has no channel or multi-month formation.

Verdict:
`CLEAN_WTI_FIXED_MONTH_OPENING_SEGMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately twelve completed packages per full year
after minimal warm-up. Q02 must retire on zero trades, fewer than five
completed packages per full year, nondeterministic endpoint construction, or
nonpositive governed economics. Q09 alone may establish realized correlation
with the certified book; a crude-oil carrier is not proof of decorrelation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.
