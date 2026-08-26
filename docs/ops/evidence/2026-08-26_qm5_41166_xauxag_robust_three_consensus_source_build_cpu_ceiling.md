# QM5_41166 XAU/XAG robust-three consensus source-build handoff

Date: 2026-08-26  
Branch: `agents/board-advisor`  
Outcome: `SOURCE_BUILD_COMMITTED_COMPILE_HELD_Q02_NOT_ENQUEUED_CPU_CEILING`

## Delivered edge

`QM5_41166_xauxag-mrobust3-agree-rv` is a low-frequency, market-neutral
commodity relative-value package. At the first synchronized D1 boundary of a
broker month it reconstructs thirteen completed monthly
`ln(XAUUSD.DWX)-ln(XAGUSD.DWX)` observations. It computes exact Theil-Sen,
finite profiled LAD, and Siegel repeated-median slopes over the same path and
fades the ratio only when all three slopes have one strict sign. Every zero or
disagreement consumes the month flat.

The two legs are opposite-side and equal-target-notional. Their frozen
`3.5 * ATR(20)` hard stops share one aggregate `RISK_FIXED=1000` budget. The
package exits in the next broker month, with a forty-day stale repair. There
are no ML or banned indicators, retries, targets, trailing stops, grids,
scale-ins, or live presets.

Realized portfolio correlation is not claimed here; Q09 owns that conclusion.
The intended different factor is the market-neutral gold/silver ratio, not
another outright XAU, index, or gas direction.

## Governance and non-duplication

- Reputable lineage: Schweikert, *Journal of Banking & Finance* (2018), DOI
  `10.1016/j.jbankfin.2017.11.010`; Koenker-Bassett LAD; Siegel,
  *Biometrika* (1982), DOI `10.1093/biomet/69.1.242`; official CME
  gold/silver ratio-spread lineage.
- The canonical dedup scan covered 4,665 EA registry rows, 1,316 cards, and 45
  Strategy Wiki nodes. Its only fuzzy hit was the newly built one-leg WTI
  robust-three continuation EA. The carrier, direction, package construction,
  and lifecycle differ materially.
- Existing XAU/XAG cards `QM5_41157`, `QM5_41160`, and `QM5_41164` use one
  estimator apiece. Two locked counterexample paths make one estimator disagree
  with the other two; this EA must stay flat where a single-estimator parent can
  trade.
- The source approval, approved G0 card, and source build are committed as
  `8978302cb`, `9304a6d68`, and `b2c6f725c`.

## Build and validation state

- EA ID: `41166`.
- Magic slot 0: `XAUUSD.DWX`, `411660000`.
- Magic slot 1: `XAGUSD.DWX`, `411660001`.
- Logical Q02 symbol: `QM5_41166_XAU_XAG_MROBUST3_AGREE_RV_D1`, using the
  validated `QM5_12533` basket-manifest recipe.
- Three backtest-only setfiles lock `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`; there are no live setfiles.
- Card schema lint, G0 lint, SPEC lint, build prerequisite guard, and the
  eleven-test independent arithmetic/static reference suite pass.
- The approved card and the build-local card are byte-identical.
- No `.ex5` exists and Q01 remains pending.

The strict compile command was refused before MetaEditor execution by
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`. The governed fallback created compile
work item `b70236ad-6e36-4f8f-9116-2f72786638ef`; it is pending under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`, with neither a compile PASS nor a compile
failure.

## Mandatory CPU stop

At `2026-08-26T10:56:10.5514815Z`, the required five one-second whole-host
samples were `99.20, 92.40, 98.93, 100.00, 99.71` percent. Average CPU was
`98.05%` and maximum CPU was `100.00%`; both bind the `>=97%` ceiling. Seven
`metatester64` processes and seven governed factory terminals were active.

Accordingly, Q02 was not enqueued or dispatched. The next safe action is to
let the governed compile item reach strict PASS, then re-sample host capacity;
only below the ceiling may the single logical Q02 item be enqueued.

No portfolio gate, T_Live manifest, T_Live terminal state, AutoTrading state,
or tester reservation was changed. Concurrent unrelated worktree changes were
preserved.

Machine-readable evidence:
`artifacts/qm5_41166_xauxag_robust_three_consensus_source_build_cpu_ceiling_20260826T105610Z.json`.
