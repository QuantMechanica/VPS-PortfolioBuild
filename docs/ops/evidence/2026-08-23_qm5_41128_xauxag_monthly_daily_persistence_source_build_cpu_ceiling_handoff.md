# QM5_41128 XAU/XAG monthly daily-persistence reversion — source build and CPU-ceiling handoff

Date: 2026-08-23

Branch: `agents/board-advisor`

EA: `QM5_41128_xauxag-mdaily-persist-rv`

Outcome: **SOURCE BUILD COMMITTED; GOVERNED COMPILE RELEASED BUT PENDING; HARD CPU CEILING HIT; Q01 PENDING; Q02 NOT ENQUEUED**

## New market-neutral commodity edge

QM5_41128 is one low-frequency, opposite-leg gold/silver relative-value
package. On the first synchronized D1 boundary of a broker month it rebuilds
the immediately completed 17-to-23-session month from timestamp-identical
`XAUUSD.DWX` and `XAGUSD.DWX` closes plus one adjacent older boundary pair.

For chronological gold-minus-silver log-ratio returns ending on every session
in the completed month, the EA calculates:

```text
N   = sum(r[i])
mu  = N / n
S   = sum((r[i] - mu)^2)
A   = sum((r[i] - mu) * (r[i-1] - mu)), i=1..n-1
rho = A / S
J   = rho + 1/(n-1)
```

It requires finite arithmetic, endpoint identity, `S>0`, bounded `rho`, and
strict `J>0`. Positive `N` is faded with SELL XAU / BUY XAG; negative `N` is
faded with BUY XAU / SELL XAG. Both legs target equal absolute USD notionals,
share one aggregate `RISK_FIXED=1000` budget, use frozen
`3.5*ATR(20,D1)` stops, and normally close at the next broker month. The
attempt month is persisted before every fallible entry gate, so a flat,
blocked, or partially failed package cannot retry.

The opposite equal-notional carrier is designed to reduce common outright
metal direction relative to the certified directional XAU/SP500/NDX/XNG
book. It does not establish beta neutrality, profitability, or portfolio
decorrelation; unchanged Q09 alone owns realized overlap.

## Reputable source and non-duplicate boundary

The approved card binds peer-reviewed and exchange lineage:

- Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
  `10.1016/j.jbankfin.2017.11.010`;
- Mehlitz and Auer (2024), *The European Journal of Finance* 30(8), 773-802,
  DOI `10.1080/1351847X.2023.2220118`;
- CME Group, *Gold & Silver Ratio Spread*.

The bounded source packet is
`strategy-seeds/sources/SCHWEIKERT-MEHLITZ-CME-XAUXAG-MDAILY-PERSIST-RV-2026/source.md`.
The daily ratio horizon, fixed short-sample correction, contrarian direction,
CFD mapping, execution, and risk are explicitly disclosed QM translations;
no source result is transferred.

The approved card's canonical pre-allocation checker scanned 4,627 registry
identities, 1,296 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`.
Its manual family review distinguishes this centered adjacent-return
dependence score from rolling ratio/OLS/quantile/MAD centers, sign-count and
block-vote cards, sequence and range-location states, and the L1/L2 path
efficiency variants. It also differs from `QM5_41127` by using a synchronized
two-metal relative series, contrarian direction, and atomic equal-notional
basket rather than outright WTI momentum.

## Governed identity and build commit

- approved card: `strategy-seeds/cards/approved/QM5_41128_xauxag-mdaily-persist-rv_card.md`;
- EA-local byte-identical card: `framework/EAs/QM5_41128_xauxag-mdaily-persist-rv/docs/strategy_card.md`;
- G0 decision: `decisions/2026-08-23_qm5_41128_xauxag_monthly_daily_persistence_reversion_g0.md`;
- source approval: `decisions/2026-08-23_xauxag_monthly_daily_persistence_reversion_source_approval.md`;
- host slot 0: `XAUUSD.DWX`, magic `411280000`;
- companion slot 1: `XAGUSD.DWX`, magic `411280001`;
- logical tester symbol: `QM5_41128_XAU_XAG_MDAILY_PERSIST_RV_D1`;
- source build commit: `1eb68e110`;
- MQ5 SHA-256: `02D3ADAF0F1AF64BB48540F79B13DE4CF5EB76CEFD41C9FD3427E90495067AB6`;
- both card copies SHA-256: `0770589E3338ECFAFC95E9ECD33C51C32C4176305A19D4AD9F00970301B79490`.

The commit contains the MQL5 source, `SPEC.md`, a QM5_12533-style logical
`basket_manifest.json`, an independent deterministic reference suite, and one
backtest-only logical setfile. The setfile locks `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF, Friday close OFF,
and every card parameter. It deliberately keeps `build_hash=pending` because
no compiler output exists.

## Source-level validation

- approved and EA-local card schema/ML lint: PASS;
- deterministic reference suite: 8/8 PASS;
- SPEC validator: PASS;
- build guardrail validator: PASS, zero findings across source and setfile;
- symbol-scope validator: `BASKET_OK`, zero violations, exactly XAU and XAG;
- post-commit `git show --check`: one non-functional blank line at MQ5 EOF;
  preserved byte-for-byte because the governed compile row is already bound
  to the recorded MQ5 SHA;
- registry and generated resolver contain both 41128 execution identities.

Reference coverage includes 17/20/23 acceptance and 16/24 rejection, exact
paired timestamps and adjacent month boundary, every month-ending relative
return once, endpoint identity, positive and negative persistent paths,
alternating and zero-variance flats, fixed `1/(n-1)` adjustment, strict
threshold equality, adjacency-order sensitivity, year rollover, durable
attempt state, equal-notional rounding, and aggregate fixed-risk containment.

## Governed compile handoff

The direct strict compile stopped before compilation at the live-factory
include-mirror guard:

- result: `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` / `INCLUDE_MIRROR_REFUSED`;
- retry bypass: none;
- log: `framework/build/compile/20260823_094028/QM5_41128_xauxag-mdaily-persist-rv.compile.log`;
- summary: `D:/QM/reports/compile/20260823_094028/summary.csv`.

The prescribed governed compile path then created exactly one utility row:

- work item: `1fba43ee-aa57-4ee8-ba97-827467710cbd`;
- source-bound SHA: `02d3adaf0f1af64bb48540f79b13de4cf5eb76cefd41c9fd3427e90495067ab6`;
- target-only release dry-run: expected SHA equals actual SHA;
- activation hold released at `2026-08-23T09:42:41Z` through the reviewed
  bounded release ceremony;
- online backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260823T094228Z_9fd0eea6.sqlite`;
- status at stop: `pending`, attempt count 0, unclaimed, no verdict;
- EX5: absent;
- build-check result: absent;
- Q01: pending.

No worker, terminal, or tester was manually launched, stopped, restarted, or
target-claimed. The resident fleet remains the only compile executor.

## Hard CPU-ceiling stop and Q02 state

Five consecutive whole-host `Processor(_Total)\% Processor Time` samples at
`2026-08-23T09:49:33.3968013Z` were:

`97.79, 98.94, 98.55, 99.90, 99.53`

Average CPU was **98.94%** and maximum CPU was **99.90%**. Both exceed the
explicit 97% paced-fleet ceiling under the binding
`average_or_maximum_at_or_above_97_percent` rule. The nearby process sample
saw two path-anchored T1-T10 `terminal64.exe` processes and two
`metatester64.exe` processes; CPU, not an inferred process count, owns the
stop verdict.

This is the mission's binding stop condition. The work-item inventory for
QM5_41128 contains only the pending `COMPILE_EA` row. No Q02 preview, Q02 work
item, dispatcher tick, terminal reservation, manual smoke, or backtest was
created. Q02 is additionally gated by the absent EX5, strict build-check
result, final build-hash binding, and Q01 PASS.

## Safe continuation and safety boundary

Once the resident compile row completes under sustained CPU below 97%, require
zero compiler errors and warnings, non-empty EX5, build-check PASS, final
setfile hash binding, and Q01 PASS. Take a fresh capacity sample, then enqueue
exactly one logical-basket Q02 row through the canonical setfile/manifest path.
Q02 must retire the unchanged baseline below five completed packages in any
full post-warm-up year rather than tune or rescue it.

No portfolio gate, `T_Live` manifest, `T_Live` file/process, AutoTrading
state, deploy artifact, live preset, portfolio admission, correlation waiver,
or decorrelation claim was touched.

Machine-readable companion:
`artifacts/qm5_41128_xauxag_mdaily_persist_rv_source_build_cpu_ceiling_handoff_20260823T094933Z_board_advisor.json`.
