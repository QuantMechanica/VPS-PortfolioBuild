# QM5_41045 — WTI Standard-Wednesday Event / Slow-Trend Agreement

## Identity

- EA ID: `QM5_41045`
- slug: `wti-wed-trend-agree`
- strategy ID: `EIA-MOP-WTI-WEDTRENDAGREE-2026_S01`
- approved card:
  `strategy-seeds/cards/approved/QM5_41045_wti-wed-trend-agree_card.md`
- G0 decision:
  `decisions/2026-08-17_wti_wednesday_trend_agreement_g0.md`
- source approval:
  `decisions/2026-08-17_wti_wednesday_trend_agreement_source_approval.md`
- source approval commit: `ebe884e63`
- EA allocation commit: `4690bd83e`
- G0 approval commit: `1e61e1ae7`
- carrier: exact `XTIUSD.DWX`, D1, symbol slot 0
- allocated magic: `410450000`

## Locked Mechanic

At the first executable broker-Thursday tick after an exact uninterrupted
Monday-Tuesday-standard-Wednesday sequence:

1. Consume one durable Thursday attempt before every fallible entry gate.
2. Compute the completed event return as
   `ln(WednesdayClose / TuesdayClose)`.
3. Compute a non-overlapping slow state as
   `ln(TuesdayClose / Close252SessionsBeforeTuesday)`.
4. Require both returns finite, nonzero, and strictly equal in sign.
5. Buy on positive agreement or sell on negative agreement.
6. Freeze a `3.0 * ATR(20,D1)` hard stop, no target, and use fixed-dollar
   backtest risk only.
7. Close at the first later D1 boundary, ordinarily Friday open.

No inventory number, current-bar price, Wednesday contribution to the slow
state, magnitude threshold, oscillator, moving mean, range gate, external
feed, retry, scale-in, grid, martingale, pyramid, or second leg is authorized.

## Framework Contract

- framework inputs: `qm_ea_id=41045`, `qm_magic_slot_offset=0`
- risk: `RISK_PERCENT=0`, `RISK_FIXED=1000`, `PORTFOLIO_WEIGHT=1`
- news: temporal OFF, compliance NONE, legacy OFF
- Friday close: enabled at broker hour 21 as a fail-safe
- strategy: 180-minute Thursday grace, 252-D1 pre-event trend, ATR(20),
  3.0 ATR stop, three-day stale guard, 1,500-point spread ceiling
- one `XTIUSD.DWX` D1 backtest setfile only
- no live/demo/shadow/stress/optimization setfile

## Build State

Directory identity was established before magic allocation as required by the
V5 resolver ordering contract. Slot 0 is allocated to exact `XTIUSD.DWX` as
magic `410450000`. Source, binary, setfile, card copy, reference fixtures,
compile evidence, and Q01 evidence remain absent until the post-allocation
build preflight passes.

## Safety Boundary

Non-live build and backtest-pipeline handoff only. No manual tester dispatch or
control, AutoTrading, `T_Live`, deploy/T_Live manifest, portfolio-gate edit,
portfolio admission, decorrelation claim, or correlation waiver is authorized.
