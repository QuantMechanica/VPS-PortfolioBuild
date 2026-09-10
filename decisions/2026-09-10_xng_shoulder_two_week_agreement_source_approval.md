# XNG Shoulder Two-Week Agreement Continuation - Source Approval

Date: 2026-09-10

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced Q02 enqueue if tester and host-CPU ceilings permit.

Authority: the current explicit OWNER commodity/energy sleeve mission on a
dedicated agent branch. The mission requests one new, non-duplicate,
structural low-frequency commodity seasonal/trend idea, requires fixed-risk
backtests and reputable sources, and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xng-shoulder-w2agree`
- proposed strategy ID: `EIA-MOP-XNG-SHOULDER-W2AGREE-20260910_S01`
- proposed source ID: `EIA-MOP-XNG-SHOULDER-W2AGREE-20260910`
- carrier: exact `XNGUSD.DWX` D1
- state: two immediately completed adjacent broker weeks have the same strict
  open-to-close log-return sign
- calendar: Monday anchor in April, May, September, or October
- direction: continue the shared sign for one broker week

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The governed packets `strategy-seeds/sources/EIA-XNG-SHOULDER-2026/source.md`
and `strategy-seeds/sources/MOP-TSMOM-2012/source.md` were read completely
before this approval. Their committed SHA-256 values are respectively
`FF535FCCA77F1A79172D3B5A529378A434C5BF430D2B74E45F335666C7612813` and
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

EIA documents lower spring and autumn natural-gas demand between heating and
electric-generation peaks. Moskowitz, Ooi, and Pedersen (2012), *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, document own-return persistence across liquid
futures and include natural gas. Neither source tests this four-month weekly
XNG CFD conjunction. No source efficacy, density, CFD-equivalence, or
decorrelation result transfers.

## Locked Mechanic

1. At the first tradable D1 bar of each Monday-anchored broker week, persist
   the attempt before every fallible entry gate.
2. Continue only for April, May, September, and October anchor months.
3. Reconstruct exactly the two immediately completed adjacent broker weeks,
   each with three through five unique ordered sessions, and compute
   `ln(final_close / first_open)` for each.
4. Two strictly positive returns buy; two strictly negative returns sell.
   Disagreement, exact zero, malformed data, or nonfinite arithmetic stays
   flat and consumes the week.
5. Use one `RISK_FIXED=1000` position with `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
6. Close at the next normalized broker week or after ten elapsed days as stale
   repair. Never retry, trail, partially close, scale in, grid, martingale, or
   pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: official EIA
  seasonality context plus named peer-reviewed momentum research, DOI, and
  complete-read evidence.
- R2 `PASS`: calendar, weekly packages, sign rule, side, attempt, risk, stop,
  spread, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XNGUSD.DWX` D1 history supplies every runtime market input.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  indicator, ML, external runtime feed, grid, or martingale.

## Non-Duplicate Decision

`framework/scripts/research_dedup_check.py` scanned 4,900 registry rows, 1,510
repository cards, and 45 Strategy Wiki nodes. It returned `CLEAN` in
`artifacts/qm5_41420_dedup_preallocation_20260910.json`.

Manual review separates `QM5_41401`, which fades the identical shoulder state;
`QM5_41396`, which follows it only in June-August; `QM5_41402`, which follows
it only in November-March; and `QM5_12567`, which is a long-only cumulative-RSI
pullback. Verdict: `DISTINCT_XNG_SHOULDER_TWO_WEEK_AGREEMENT_CONTINUATION`.

## Kill And Safety Boundary

Q02 must retire below five completed trades in any full post-warm-up year, at
zero trades or nonpositive governed economics, or on any calendar, package,
direction, attempt, risk, lifecycle, or determinism defect. This approval
excludes manual backtests; live, demo, shadow, stress, and optimization
presets; terminal control; AutoTrading; `T_Live`; deploy/live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; and
decorrelation claims.
