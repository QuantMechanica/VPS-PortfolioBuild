# WTI Month-Closing Segment Momentum — G0 Decision

Date: 2026-08-15

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 enqueue.
This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch and durably recorded before extraction in
`decisions/2026-08-15_wti_mclose_momentum_source_approval.md` at commit
`3aa02c4f1`.

## Candidate

- EA: `QM5_41016_wti-mclose-mom`, allocated after source approval by the
  deterministic registry command
- slug: `wti-mclose-mom`
- strategy ID: `MOP-WTI-MCLOSE-MOM-2026_S01`
- source ID: `MOP-WTI-MCLOSE-MOM-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1
- planned magic: slot 0 `410160000`
- driver: sign of WTI's final five completed close-to-close intervals in the
  immediately prior broker month
- lifecycle: exact first-new-month entry and first-tick-of-sixth-bar exit

## Source Decision

The approved packet is
`strategy-seeds/sources/MOP-WTI-MCLOSE-MOM-2026/source.md`. It binds one
translation to the completely reviewed Moskowitz, Ooi, and Pedersen source
packet.

The peer-reviewed paper supplies own-return-sign continuation and explicit
WTI membership in its commodity-futures universe. It does not test the five-
session formation or hold, the exact month-boundary carrier, WTI alone,
Darwinex CFDs, fixed risk, costs, or the QM book. No efficacy or decorrelation
claim transfers.

## Locked Rule

1. Attach only within five minutes of the first `XTIUSD.DWX` D1 bar of a new
   broker month.
2. Persist the current month attempt before every fallible gate and never
   retry the month.
3. Require the six immediately preceding completed D1 bars to belong to the
   immediately prior broker month and compute
   `log(Close[1] / Close[6])`.
4. Buy on a positive return, sell on a negative return, and remain flat on
   exact zero or invalid state.
5. Use `RISK_FIXED=1000`, a frozen `3.5 * ATR(20,D1)` hard stop, no target,
   and a 1,500-point spread ceiling. Signal magnitude never scales risk.
6. Close at the first tick of the sixth D1 bar in the entry month, on a
   premature month change, after twelve calendar days, or on malformed
   exposure.
7. Keep Friday close and both news axes OFF for the fixed five-session hold.

The carrier, six-close endpoints, prior-month membership, sign, exact entry
clock, five-bar hold, attempt, risk, stop, spread, and exit are locked.

## Reputable-Source Criteria

- R1 `PASS`: peer-reviewed JFE paper, DOI, complete-paper evidence, durable
  retrieval hash, explicit WTI membership, and disclosed translation distance.
- R2 `PASS`: endpoints, month membership, clock, direction, attempt, risk,
  stop, spread, and exit are fixed.
- R3 `PASS`: registered native XTI D1 history supplies all runtime inputs.
- R4 `PASS`: deterministic native arithmetic only, without trained output,
  banned signal indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,503 registry rows and 599 root cards,
finding no exact match and one fuzzy source-family sibling:

- `QM5_41013_wti-mopen-mom` forms on current-month bars 1-5, enters at bar
  6, and holds the residual month. This card forms on the prior month's final
  five return intervals, enters at current-month bar 1, and exits at bar 6.
- `QM5_12983_wti-tom-mom` uses 63-D1 magnitude and a variable multi-day
  entry window with target/window exits.
- `QM5_13049_xti-1w-mom-vol` is a rolling weekly decision with return-size
  and realized-volatility gates.
- `QM5_20187_wti-tsmom1m` owns a full prior-month formation and full next-
  month hold.

Verdict:
`CLEAN_WTI_FINAL_FIVE_TO_FIRST_FIVE_SEGMENT_MOMENTUM_AFTER_MANUAL_REVIEW`.

## Allocation And Kill Boundary

The deterministic registry command allocated `QM5_41016` from the global
next-ID sequence; no ID was inferred or hand-edited. Expected cadence is
approximately twelve positions per full year. Q02 must retire on zero
positions, below five/year, late or repeated entry, wrong endpoints or hold
length, risk-mode mismatch, or nonpositive governed economics. Q09 alone may
establish realized book correlation.

## Safety Boundary

Create exactly one `XTIUSD.DWX` D1 backtest setfile with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This
decision excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio-gate edits; portfolio admission; and correlation waivers. Enqueue
once, but do not dispatch or control a tester when the factory resource
ceiling is binding.

