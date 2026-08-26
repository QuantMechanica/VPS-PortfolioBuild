# QM5_41168 XAU/XAG monthly Cox-Stuart paired-sign source-build handoff

Date: 2026-08-26

Branch: `agents/board-advisor`

Outcome: `SOURCE_BUILD_COMMITTED_COMPILE_HELD_Q02_NOT_ENQUEUED_CPU_CEILING`

## Delivered edge

`QM5_41168_xauxag-mcoxstuart-rv` is a low-frequency XAU/XAG relative-value
package. At the first synchronized D1 boundary of a broker month, it reconstructs
fourteen consecutive completed monthly
`ln(XAUUSD.DWX)-ln(XAGUSD.DWX)` endpoints. It forms the seven fixed Cox-Stuart
half-sample differences `s[i+7]-s[i]`. Five or more positive signs open short
XAU/long XAG; five or more negative signs open long XAU/short XAG. Any exact tie
or a 4/3 split consumes the month flat.

The two legs are opposite-side and equal-target-notional, subject to a 20%
maximum post-rounding mismatch. Frozen `3.5 * ATR(20)` hard stops share one
aggregate `RISK_FIXED=1000` budget. The package exits in the next broker month,
with a forty-day stale repair. There are no ML or banned indicators, targets,
trailing stops, grids, scale-ins, retries, or live presets.

Realized portfolio correlation is not claimed at build time; Q09 owns that
conclusion. The intended distinct factor is the market-neutral-style
gold/silver ratio, rather than another outright gold, index, or gas direction.

## Governance and non-duplication

- Reputable lineage: Schweikert, *Journal of Banking & Finance* (2018), DOI
  `10.1016/j.jbankfin.2017.11.010`; official CME Gold & Silver Ratio Spread;
  Cox and Stuart, *Biometrika* (1955), DOI `10.1093/biomet/42.1-2.80`; and the
  complete public NIST Dataplot Cox-Stuart pairing description. The paywalled
  Cox-Stuart paper body is not represented as completely read.
- The fail-closed canonical dedup scan covered 4,667 EA registry identities,
  1,318 cards, and 45 Strategy Wiki nodes and returned `CLEAN`.
- Two locked counterexample paths separate the seven paired signs from endpoint
  direction, Mann-Kendall direction, quarterly voting, and robust-slope
  neighbors.
- The source approval, G0-approved card, and source build are committed as
  `d5e5a0c79`, `9b3df2775`, and `55bf1ace6`.

## Build and validation state

- EA ID: `41168`.
- Magic slot 0: `XAUUSD.DWX`, `411680000`.
- Magic slot 1: `XAGUSD.DWX`, `411680001`.
- Logical Q02 symbol: `QM5_41168_XAU_XAG_MCOXSTUART_RV_D1`, following the
  validated `QM5_12533` basket-manifest recipe.
- Three backtest-only setfiles lock `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`; no live setfile exists.
- Card schema lint, G0 lint, SPEC lint, the build prerequisite guard, and build
  guardrails all pass with zero findings.
- Nine independent arithmetic/static reference tests pass, including the 5/2
  threshold, 4/3 and tie flats, contrarian side orientation, year rollover,
  endpoint synchronization contracts, functional separation, source locks,
  manifest locks, and fixed-risk setfile locks.
- The approved card and build-local card are byte-identical at SHA-256
  `1DB0EB17B8E699EAE6A1D9A7223AFF3C1D5694F2B556FB94C773CB522C000B13`.
- No `.ex5` exists, so Q01 has no compile PASS.

The strict local build check was refused before MetaEditor execution by
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no running terminal was disturbed. The
governed fallback created compile work item
`830c8cb9-d45e-450b-a90e-a750e8886dd5`. It remains pending under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`, with neither a compile PASS nor a compile
failure.

## Mandatory CPU stop

The five one-second whole-host CPU samples were `99.90`, `100.00`, `98.64`,
`99.61`, and `99.42` percent. Average CPU was `99.51%` and maximum CPU was
`100.00%`; both bind the `>=97%` ceiling. Seven `metatester64` processes and
eight governed factory terminals were observed.

Accordingly, Q02 was not enqueued or dispatched. The next safe action is to let
the governed compile item reach strict PASS, then resample host capacity; only
below the ceiling may the single logical Q02 item be enqueued.

No portfolio gate, T_Live manifest, T_Live terminal state, AutoTrading state,
or tester reservation was changed. Concurrent unrelated worktree changes were
preserved.

Machine-readable evidence:
`artifacts/qm5_41168_xauxag_cox_stuart_paired_sign_source_build_cpu_ceiling_20260826T144026Z.json`.
