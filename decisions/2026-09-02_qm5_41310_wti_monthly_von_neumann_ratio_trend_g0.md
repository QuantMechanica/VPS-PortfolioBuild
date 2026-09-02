# QM5_41310 WTI Monthly Raw von Neumann Ratio Trend - G0 Authorization

Date: 2026-09-02

Decision: `APPROVED` at G0 for source-bounded card extraction, governed magic
allocation, one branch-only non-live V5 build, strict Q01 validation, and one
paced Q02 enqueue. G0 does not pre-approve efficacy, cadence, economics,
robustness, independence, portfolio admission, or live use.

Authority: current explicit OWNER commodity/energy sleeve mission on branch
`agents/board-advisor`.

## Identity And Source Binding

- EA ID: `QM5_41310`, reserved atomically in commit `01807343fe`
- slug: `wti-mvnratio-tr`
- strategy ID: `AI-CODEX-WTI-MVNRATIO-TREND-20260902_S01`
- source ID: `AI-CODEX-WTI-MVNRATIO-TREND-20260902`
- source approval: commit `fa3b33f98e`
- source packet SHA-256:
  `C30EAC1402E532BEB68AC95B408A7559A355710914AD3E46991821B508529797`
- exact carrier: `XTIUSD.DWX`, D1, slot 0, magic `413100000`

The source packet combines the official NIST mean-successive-differences
formula and interpretation, original von Neumann peer-reviewed provenance,
and the existing complete governed read of Moskowitz-Ooi-Pedersen for monthly
own-return continuation and explicit WTI membership. The exact conjunction is
identified as a new QM hypothesis, not a transferred source result.

## Approved Mechanical Contract

At the first executable D1 tick after a genuine broker-month change, consume
the normalized month before every fallible gate. Reconstruct twenty-one
consecutive completed month-end closes and form twenty adjacent chronological
log returns. Let `V` be their centered sum of squares and `D` the sum of
nineteen squared successive return differences. Qualify strictly when
`V>1e-18` and `eta=D/V<2.0`; follow the newest twelve-month cumulative return
sign outside a symmetric `1e-12` tie band. Invalid or nonqualifying states
consume flat.

The one authorized baseline uses `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` broker hard stop, no target,
a 1,500-point spread ceiling, next-month renewal, and forty-day stale exit.
Both news axes, legacy news, Friday close, and stress rejection are OFF.

No p-value, critical-value table, normalization, rank substitution,
alternative sample, magnitude sizing, optimizer output, prior PnL, external
feed, or intramonth retry is authorized.

## R1-R4 And Duplicate Review

- R1 `PASS_WITH_SYNTHESIS_BOUNDARY`: official complete NIST method page,
  original method provenance, and a complete governed peer-reviewed WTI
  trading-paper read.
- R2 `PASS`: exact clock, endpoints, return orientation, mean, numerator,
  denominator, threshold, direction, attempt, risk, and lifecycle.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 and MT5
  execution state supply every runtime input.
- R4 `PASS`: deterministic arithmetic and framework state only; no trained
  output or banned signal mechanism.

The deterministic dedup receipt is
`artifacts/qm5_wti_mvnratio_tr_preallocation_dedup_20260902.json`, SHA-256
`8539B7F5E61A88376EA0E2BA0CE1AF42E7EB2B7028C0356A3C7BB1C663D09142`.
It scanned 4,795 registry rows, 1,424 cards, and 45 wiki nodes and returned
`CLEAN`.

Manual review distinguishes the candidate from `QM5_41170`: that EA ranks
thirteen price levels and discards magnitude before applying the Bartels
successive-rank ratio. `QM5_41310` applies the raw ratio to twenty monthly log
return magnitudes. It also differs from net/absolute path efficiency,
multi-q variance ratios, entropy, LZ76, sign-run, regression, calendar, event,
and channel systems.

## Cadence, Kill, And Safety Boundary

The market-free fixed-seed null receipt qualified 49.9715% of 200,000 samples,
about six monthly packages/year. This is a cadence prior only. Q02 must retire
at zero trades, below five completed trades in any full post-warm-up year, on
nonpositive governed economics, or on a deterministic contract defect. No
failed result may be repaired by changing any locked rule.

This authorization excludes manual backtests; live/demo/shadow/stress or
optimization setfiles; manual dispatch; terminal control; AutoTrading;
`T_Live`; deploy or T_Live manifests; portfolio-gate edits; portfolio
admission; and correlation waivers. If the active factory resource ceiling
binds before compile or enqueue, stop and report it.
