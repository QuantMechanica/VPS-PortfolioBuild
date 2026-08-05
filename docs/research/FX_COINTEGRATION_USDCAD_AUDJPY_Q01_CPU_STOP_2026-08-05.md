# QM5_20220 USDCAD/AUDJPY FX cointegration Q01 CPU-stop handoff

Date: 2026-08-05
Branch: agents/board-advisor
Status: Q01 PASS; Q02 deliberately not enqueued because the CPU ceiling was exceeded

## Outcome

QM5_20220_usdcad-audjpy is a new, dedicated, low-frequency D1 FX
cointegration basket. It is the first unbuilt exact pair after the already
mechanized ranks 40 and 41 in the frozen sign-aware 66-pair scan. The EA,
binary, two RISK_FIXED backtest setfiles, Strategy Card, deterministic
registry rows, magic resolver, and basket manifest are committed on this
branch.

Q01 passed. The guarded enqueue dry run selected exactly the logical-basket
setfile and skipped the physical host setfile with reason
`basket_manifest_logical_setfile_preferred`. No Q02 work item was inserted:
the sampled factory load was 9 running terminals against the binding
7-terminal CPU ceiling.

## Anchor triage

- QM5_12532 has canonical Q02 PASS and later Q05 FAIL.
- QM5_12533 has canonical Q02 PASS and later Q04 FAIL.
- Neither anchor has an open Q02 ONINIT or NO_HISTORY blocker, so no anchor
  repair or duplicate requeue was warranted.

## Selection and source boundary

The deterministic scan command was:

    python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges

USDCAD/AUDJPY is sign-aware rank 42 of 66:

| Measure | Frozen value |
|---|---:|
| DEV net Sharpe | 0.285291116943 |
| OOS net Sharpe | -0.060279270158 |
| OOS return | -0.374458523080% |
| OOS state changes | 15 |
| DEV beta | -0.186232670359 |
| Half-life | 73.379978960418 D1 bars |

Exact-pair card, EA, registry, and unordered traded-symbol manifest checks
found no prior dedicated USDCAD/AUDJPY fixed-beta D1 sleeve. The deterministic
dedup guard returned CLEAN for slug `usdcad-audjpy`, strategy ID
`AI-CODEX-FX-COINT66-20260609-USDCAD-AUDJPY`, and the
`cointegration-pair-trade` mechanic.

The method is bounded to the OWNER-ratified Tier-A extraction of Ernest
Chan's pair-trading examples in
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Chan supplies
the mechanical method, not a pair-specific performance claim. The frozen
internal scan supplies only the pair-specific evidence.

The negative OOS result and inferred cadence of roughly four completed
packages per year per symbol are adverse evidence. The binding Q02 floor
remains five trades per year per symbol. A terminal frequency or economic
failure retires this sleeve; it does not authorize a filter, beta refit, or
parameter rescue.

## Implementation contract

- Host and first traded leg: USDCAD.DWX, D1.
- Companion and second traded leg: AUDJPY.DWX.
- Conversion-only histories: AUDUSD.DWX and USDJPY.DWX.
- Fixed residual: ln(USDCAD) - (-0.186232670) * ln(AUDJPY).
- Entry: absolute z-score greater than 2.0 using a strictly prior 60-bar
  residual window.
- Exit: absolute z-score below 0.5; both legs also have 2.0 ATR(20) stops.
- Negative beta makes the long-spread package long both instruments and the
  short-spread package short both instruments.
- Partial entries and orphaned legs are flattened atomically.
- Backtest risk is RISK_FIXED=1000, RISK_PERCENT=0, PORTFOLIO_WEIGHT=1.
- The basket is residual-neutral only; it retains CAD, AUD, JPY, USD, carry,
  commodity-cycle, and broad risk-sentiment exposure.

## Q01 evidence

- Strict compile: PASS, zero errors, zero warnings.
- Strict build check: PASS, zero failures, zero warnings.
- Build report:
  `D:\QM\reports\framework\21\build_check_20260805_072937.json`.
- Compile summary:
  `D:\QM\reports\compile\20260805_072724\summary.csv`.
- Strategy Card schema lint: PASS on draft, approved, and EA-local copies.
- Spec validation: PASS.
- Symbol scope: BASKET_OK with zero violations.
- Basket manifest regression: 39 passed.
- Magic resolver regression: 5 passed.
- Magic rows: USDCAD.DWX slot 0 / 202200000 and AUDJPY.DWX slot 1 /
  202200001.
- Manual smoke or backtest run: none.

Key SHA-256 values:

| Asset | SHA-256 |
|---|---|
| MQ5 | `7F5C593178F99F667B9318DC7AFD962CA02613B69AEB9F64177F3A5AB884F67D` |
| EX5 | `464B198B76C21106A5CC89B61802855C3DEAE4F3D3D12FA77A8A0EFAF83690CA` |
| basket_manifest.json | `F018B19DAAD14C135618C09D23B4F3186E5FF103C904AFA8C15B12976FB65203` |
| logical setfile | `EBCE89CFEB15844170F6B7AC558786E7C0D4312543767A4EB8305C6EAC39EC09` |
| physical setfile | `5DF5C5B08E036EFFB87A4385AC5CD9739D4AE0348CC70E54D66F36898E43C546` |

## Q02 readiness and enforced stop

The dry-run sweep at 2026-08-05T07:31:05Z identified exactly one would-be
priority-track work item for logical symbol
`QM5_20220_USDCAD_AUDJPY_COINTEGRATION_D1`, using setfile
`QM5_20220_usdcad-audjpy_QM5_20220_USDCAD_AUDJPY_COINTEGRATION_D1_D1_backtest.set`.
The physical USDCAD.DWX setfile was correctly skipped in favor of the basket
manifest's logical setfile. Dry-run evidence is at
`D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`; despite the
legacy filename, its embedded generation timestamp is 2026-08-05T07:31:05Z
and `apply` is false.

At 2026-08-05T07:31:35Z, `farmctl.py mt5-slots` reported nine running factory
terminals: T1, T3, T4, T5, T6, T7, T8, T9, and T10. That exceeds the binding
seven-terminal ceiling. The queue contained 1,576 pending and 10 active work
items. A direct read-only query found zero work items for QM5_20220.

Accordingly, no apply-mode enqueue, dispatch tick, terminal reservation,
tester launch, terminal stop, T_Live action, or AutoTrading action was
performed. The next paced operator may enqueue the one logical item only
after a fresh capacity check is below the ceiling:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20220

## Commit chain

- `9ace93e4a`: source-backed G0 approval and research decision.
- `336bdceee`: deterministic allocation, basket implementation, compiled
  binary, registries, manifest, setfiles, and regression test.

No portfolio admission/contribution gate and no T_Live manifest was changed.
