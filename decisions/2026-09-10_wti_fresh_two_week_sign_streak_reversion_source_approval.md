# WTI Fresh Two-Week Sign-Streak Reversion - Source Approval

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

- proposed slug: `wti-wstreak2-fade`
- proposed strategy ID: `YANG-WTI-WSTREAK2-FADE-20260910_S01`
- proposed source ID: `YANG-WTI-WSTREAK2-FADE-20260910`
- carrier: exact `XTIUSD.DWX` D1
- state: the newest two completed-week returns have one strict common sign and
  the immediately preceding weekly return has the strict opposite sign
- direction: fade the fresh two-week streak for one broker week
- lifecycle: one consumed attempt on the first tradable bar of each broker week

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following committed records were read completely before this approval:

1. `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, SHA-256
   `52DBFDAC58E6444D14AACFC97D26E4F8FA0010B6A10F0768DBE56067055ED7F7`;
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`;
3. `strategy-seeds/sources/MOP-WTI-WSTREAK2-CONT-20260910/source.md`, SHA-256
   `BF9D587A046E40C6FCA88A71CD29298751014A2AD10B7D4AB482F7522B58009E`.

Yang, Goncu, and Pantelous supply academic commodity-futures reversal lineage.
Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, supply a complete published-paper record,
own-return-sign methodology, and explicit NYMEX WTI universe membership. The
two-week continuation packet fixes the completed-week clock and exact fresh
two-week path used by the directionally opposite sibling.

No source establishes a fresh two-week WTI streak fade, weekly-horizon alpha,
continuous-CFD equivalence, fixed-dollar ATR risk, or portfolio decorrelation.
Those are disclosed pre-result QM choices; no efficacy or density result
transfers.

## Locked Mechanic

1. On the first tradable D1 bar of a new Monday-anchored broker week, persist
   the attempt before every fallible entry gate.
2. Reconstruct exactly four consecutive completed broker-week ending closes,
   each from a three-to-five-session week; exclude current-week data.
3. With newest-to-oldest endpoints `C0..C3`, compute
   `r0=ln(C0/C1)`, `r1=ln(C1/C2)`, and `r2=ln(C2/C3)`.
4. Require strict `r0>0,r1>0,r2<0` to sell, or strict
   `r0<0,r1<0,r2>0` to buy. Equality and every other path stay flat.
5. Use one `RISK_FIXED=1000` WTI position with `RISK_PERCENT=0`, one frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
6. Close at the first later Monday anchor or after ten elapsed days as stale
   repair. Never retry, trail, partially close, scale in, grid, martingale, or
   pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_SHORT_HORIZON_REVERSAL_TRANSLATION_RISK`: academic commodity
  reversal lineage plus named peer-reviewed research, DOI, complete-read
  evidence, and explicit WTI membership.
- R2 `PASS`: endpoints, signs, fresh-state rule, opposite side, attempt, risk,
  stop, spread, and lifecycle are deterministic.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  XTIUSD.DWX D1 history supplies every runtime market input.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  indicator, ML, external runtime feed, grid, or martingale.

## Non-Duplicate Decision

`framework/scripts/research_dedup_check.py` scanned 4,903 registry rows, 1,513
repository cards, and 45 Strategy Wiki nodes. It found no exact identity and
returned one fuzzy family match in
`artifacts/qm5_next_wti_wstreak2_fade_dedup_preallocation_20260910.json`.

Manual review separates `QM5_41415_wti-wstreak3-fade`, which requires three
newest same-sign returns and five completed endpoints. This candidate requires
only two newest same-sign returns and four endpoints. A fresh two-week event
will be consumed flat by the three-week sibling, while a fresh three-week event
is no longer fresh under this candidate's shifted predecessor rule; their
strict admitted states are disjoint. `QM5_41419_wti-wstreak2-cont` uses the
identical two-week state but takes the economically opposite side. Seasonal
WTI two-week cards impose month gates and do not require an older opposite
predecessor. Verdict: `DISTINCT_WTI_FRESH_TWO_WEEK_SIGN_STREAK_REVERSION`.

## Kill And Safety Boundary

Q02 must retire below five completed trades in any full post-warm-up year, at
zero trades or nonpositive governed economics, or on any label, adjacency,
direction, attempt, risk, lifecycle, or determinism defect. This approval
excludes manual backtests; live, demo, shadow, stress, and optimization
presets; terminal control; AutoTrading; `T_Live`; deploy/live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; and
decorrelation claims.
