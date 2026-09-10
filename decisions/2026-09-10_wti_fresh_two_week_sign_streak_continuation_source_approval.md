# WTI Fresh Two-Week Sign-Streak Continuation - Source Approval

Date: 2026-09-10

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced Q02 enqueue if tester and host-CPU ceilings permit.

Authority: the current explicit OWNER commodity/energy sleeve mission on the
`agents/board-advisor` branch. The mission requests one new, non-duplicate,
structural low-frequency commodity edge, expressly permits a direct WTI
carrier, requires fixed-risk backtests and reputable sources, and forbids live
and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-wstreak2-cont`
- proposed strategy ID: `MOP-WTI-WSTREAK2-CONT-20260910_S01`
- proposed source ID: `MOP-WTI-WSTREAK2-CONT-20260910`
- carrier: exact `XTIUSD.DWX` D1
- state: the newest two completed-week returns have one strict common sign and
  the immediately preceding weekly return has the strict opposite sign
- direction: follow the fresh two-week streak for one broker week
- lifecycle: one consumed attempt on the first tradable bar of each broker week

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

`strategy-seeds/sources/MOP-TSMOM-2012/source.md` was read completely before
this approval. It records the complete 23-page read of Moskowitz, Ooi, and
Pedersen (2012), *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, with PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
The committed packet's canonical SHA-256 is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The paper supports own-return continuation across liquid futures and names
NYMEX WTI in its commodity universe. It does not test a fresh two-week WTI
streak, a weekly horizon, Darwinex continuous CFDs, fixed-dollar ATR risk, or
this lifecycle. Those are disclosed QM choices. No efficacy, density, WTI-only
alpha, CFD equivalence, or decorrelation result transfers.

## Locked Mechanic

1. On the first tradable D1 bar of a new Monday-anchored broker week, persist
   the attempt before every fallible entry gate.
2. Reconstruct exactly four consecutive completed broker-week ending closes,
   each from a three-to-five-session week; exclude current-week data.
3. With newest-to-oldest endpoints `C0..C3`, compute
   `r0=ln(C0/C1)`, `r1=ln(C1/C2)`, and `r2=ln(C2/C3)`.
4. Require strict `r0>0,r1>0,r2<0` to buy, or strict
   `r0<0,r1<0,r2>0` to sell. Equality and every other path stay flat.
5. Use one `RISK_FIXED=1000` WTI position with `RISK_PERCENT=0`, one frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
6. Close at the first later Monday anchor or after ten elapsed days as stale
   repair. Never retry, trail, partially close, scale in, grid, martingale, or
   pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_SHORT_HORIZON_STATE_TRANSLATION_RISK`: named peer-reviewed
  research, DOI, complete-read evidence, and explicit WTI membership.
- R2 `PASS`: endpoints, signs, fresh-state rule, side, attempt, risk, stop,
  spread, and lifecycle are deterministic.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  XTIUSD.DWX D1 history supplies every runtime market input.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  indicator, ML, external runtime feed, grid, or martingale.

## Non-Duplicate Decision

`framework/scripts/research_dedup_check.py` scanned 4,899 registry rows, 1,509
repository cards, and 45 Strategy Wiki nodes. It found no exact or fuzzy
identity and returned `CLEAN` in
`artifacts/qm5_41419_dedup_preallocation_20260910.json`.

Manual review separates `QM5_41074`, which waits for a third same-sign week,
and `QM5_41415`, which fades that three-week state. `QM5_41406` and
`QM5_41404` require fixed summer or winter regimes and do not require the
opposite predecessor. Gold/silver `QM5_41418` uses the analogous topology on
a synchronized two-leg relative carrier; it is not direct WTI exposure.
Verdict: `DISTINCT_WTI_FRESH_TWO_WEEK_SIGN_STREAK_CONTINUATION`.

## Kill And Safety Boundary

Q02 must retire below five completed trades in any full post-warm-up year, at
zero trades or nonpositive governed economics, or on any label, adjacency,
direction, attempt, risk, lifecycle, or determinism defect. This approval
excludes manual backtests; live, demo, shadow, stress, and optimization
presets; terminal control; AutoTrading; `T_Live`; deploy/live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; and
decorrelation claims.
