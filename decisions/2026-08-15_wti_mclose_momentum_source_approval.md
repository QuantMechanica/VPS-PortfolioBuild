# WTI Month-Closing Segment Momentum — Source Approval

Date: 2026-08-15

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue authority is not authority to dispatch
a tester or exceed the active factory resource ceiling.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requests one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, requires reputable-source criteria and `RISK_FIXED`
backtests, and forbids live and portfolio mutations.

## Candidate Identity

- proposed slug: `wti-mclose-mom`
- proposed strategy ID: `MOP-WTI-MCLOSE-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MCLOSE-MOM-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1
- decision clock: first executable tick of the first D1 bar in a new broker
  month
- signal: follow the sign of WTI's final five completed close-to-close return
  intervals of the immediately prior broker month
- lifecycle: hold through exactly the first five completed D1 bars of the new
  broker month, then flatten at the first tick of its sixth D1 bar

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

The paper supplies the structural own-return-sign continuation family and
explicit WTI membership in its commodity-futures universe. It reports
monthly formation and holding experiments, including `k=1, h=1`, but it does
not test a final-five-session formation, an exact first-new-month decision,
a five-session hold, WTI alone, or a Darwinex continuous CFD.

The six-close endpoint reconstruction, final-five return intervals, exact
broker-month boundary, opening grace, one consumed monthly attempt,
continuous-CFD mapping, fixed risk, ATR stop, spread cap, and restart
lifecycle are disclosed QM translations. No source return, Sharpe ratio,
coefficient, significance, density, cost, drawdown, WTI-only efficacy,
decorrelation, or portfolio result transfers.

## Locked Mechanic

On each new `XTIUSD.DWX` D1 bar:

1. Require the current bar to be the first positive, finite D1 bar of a new
   broker month and require attachment within five minutes of its opening
   timestamp. A late attachment consumes the month flat.
2. Persist the current `yyyymm` attempt before history, signal, news, spread,
   quote, sizing, or order gates. Never retry the same month.
3. Require the six immediately preceding completed D1 bars to belong to the
   same, immediately prior broker month. Their newest close must be the final
   completed close before the current month boundary.
4. Compute `formation_return = log(Close[1] / Close[6])`, which contains the
   final five completed close-to-close return intervals of that prior month.
5. BUY WTI when `formation_return > 0`, SELL WTI when it is below zero, and
   remain flat on exact zero or invalid arithmetic.
6. Open at most one WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a
   frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread
   ceiling. Signal magnitude never scales risk.
7. Close at the first tick of the sixth D1 bar in the entry broker month,
   after twelve calendar days as a stale guard, or when owned exposure is
   malformed. A premature month change also closes immediately. Friday close
   and both news axes are OFF to preserve the fixed five-session carrier.

The carrier, six-close endpoint construction, prior-month membership,
return sign, exact first-bar clock, five-completed-bar hold, one-attempt
state, direction, risk, stop, spread, and exit are load-bearing.

## Reputable-Source Criteria

- R1 `PASS`: exactly one governed source ID, backed by a named peer-reviewed
  JFE paper, DOI, complete-paper review evidence, and a durable retrieval hash.
  The untested horizon and calendar translation are explicit.
- R2 `PASS`: endpoints, month membership, decision clock, direction, attempt,
  risk, stop, spread, and five-bar exit are deterministic and locked before
  Q02.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history supplies every runtime input.
- R4 `PASS`: deterministic native price/calendar arithmetic only; no trained
  output, banned signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,503 EA-registry rows and 599 root-card files.
It found no exact match and one expected fuzzy sibling,
`QM5_41013_wti-mopen-mom`. Manual review fixes the material boundaries:

- `QM5_41013_wti-mopen-mom` forms on the first five current-month sessions,
  enters on the sixth session, and holds the residual month. This proposal
  forms on the final five prior-month intervals, enters on the first current-
  month session, and exits exactly where `QM5_41013` becomes eligible. Signal
  endpoints, owned return stream, and lifecycle do not coincide.
- `QM5_12983_wti-tom-mom` uses a 63-D1 return with a magnitude threshold and
  may enter anywhere inside a multi-day turn window; it also uses a target and
  window exit. This proposal uses only a five-interval sign, one exact entry
  tick, no target, and one exact five-session hold.
- `QM5_13049_xti-1w-mom-vol` evaluates rolling five-D1 moves, requires a
  return-size threshold and realized-volatility rank, and may decide weekly.
  This proposal evaluates once per broker month without a magnitude or
  volatility gate.
- `QM5_20187_wti-tsmom1m` forms on a complete prior broker month and holds a
  complete next month. This proposal owns only the first five sessions after
  a non-monthly five-interval formation.
- WTI calendar, breakout, reversal, event, roll, cross-asset, and medium-term
  trend builds do not own this exact segment-to-segment clock.

Verdict:
`CLEAN_WTI_FINAL_FIVE_TO_FIRST_FIVE_SEGMENT_MOMENTUM_AFTER_MANUAL_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately twelve completed WTI packages per full
post-warm-up year. Q02 must retire on zero trades, fewer than five completed
packages per full year, nondeterministic month segmentation, late or repeated
entries, wrong hold length, or nonpositive governed economics. Q09 alone may
establish realized correlation with the certified book; a crude-oil carrier
is not proof of decorrelation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.
