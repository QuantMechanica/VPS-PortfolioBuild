# QM5_20224 EURUSD/EURJPY FX Cointegration Q02 Handoff

Date: 2026-08-05
Branch: agents/board-advisor
Status: Q01 PASS; one logical-basket Q02 work item PENDING; enqueued below the
CPU ceiling, then stopped when final verification observed 8/7 terminals

## Outcome

`QM5_20224_eurusd-eurjpy` is a new, dedicated, low-frequency D1 FX
cointegration basket. It is the first unbuilt exact pair after the already
mechanized frontier in the frozen sign-aware 66-pair scan. The approved Card,
EA source and binary, deterministic registry rows, two-traded-symbol basket
manifest, one conversion-history declaration, and RISK_FIXED presets are
committed on this branch.

Q02 work item `5d1cb89c-25ce-419c-869c-8c9f7afa10c1` was enqueued at
2026-08-05T14:39:23Z for logical symbol
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. It was pending and unclaimed at
verification. The physical `EURUSD.DWX` host preset was deliberately skipped
with reason `basket_manifest_logical_setfile_preferred`.

## Anchor triage

- `QM5_12532` has canonical Q02 PASS and Q04 PASS, followed by Q05 FAIL.
- `QM5_12533` has canonical Q02 PASS, followed by Q04 FAIL.
- Neither anchor has an open Q02 ONINIT or NO_HISTORY blocker. Repairing or
  duplicating either Q02 run was therefore unwarranted.

## Selection and source boundary

The fixed scan was reproduced with:

    python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges

EURUSD/EURJPY is sign-aware rank 46 of 66:

| Measure | Frozen value |
|---|---:|
| DEV net Sharpe | 0.473267021521 |
| OOS net Sharpe | -0.118542968988 |
| OOS return | -1.026393918359% |
| OOS state changes | 17 |
| DEV beta | -0.236324029087 |
| Half-life | 137.787962832189 D1 bars |

Rank 44 is already represented by `QM5_20223`, and rank 45 by
`QM5_12768`. The exact unordered EURUSD/EURJPY pair was absent from
dedicated cards, EA directories, registry rows, and two-symbol traded
manifests. The deterministic dedup guard returned CLEAN across 4,281 registry
rows and 397 cards for slug `eurusd-eurjpy`, strategy ID
`AI-CODEX-FX-COINT66-20260609-EURUSD-EURJPY`, and mechanic
`cointegration-pair-trade`.

The mechanical method is bounded to the CEO-ratified Tier-A extraction of
Ernest Chan's pair-trading examples in
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Chan
supplies the method, not a EURUSD/EURJPY performance claim. Negative OOS
performance, the long half-life, and cadence inferred below the binding Q02
floor are explicit adverse evidence. Economic or frequency failure retires
the sleeve; it does not authorize a beta refit, filter, or parameter rescue.

## Mechanization

- Host and first traded leg: `EURUSD.DWX`, D1.
- Companion and second traded leg: `EURJPY.DWX`.
- Conversion-only history: `USDJPY.DWX`; it receives no order or magic slot.
- Frozen residual: `ln(EURUSD) - (-0.236324029) * ln(EURJPY)`.
- Entry: absolute z-score above 2.0, scored against the strictly prior 60
  aligned closed-D1 residuals.
- Exit: absolute z-score below 0.5; each leg also has a 2.0 ATR(20) stop.
- Negative beta makes a long-spread package long both pairs and a short-spread
  package short both pairs.
- Partial entry failure and orphaned-leg states flatten the whole package.
- Backtest risk is `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The basket is regression-residual-neutral only; it retains EUR, USD, JPY,
  carry, and broad risk-sentiment exposures.

## Q01 evidence

- Strict compile: PASS, zero errors, zero warnings.
- Strict build check: PASS, zero failures, zero warnings.
- Build report:
  `D:\QM\reports\framework\21\build_check_20260805_143205.json`.
- Compile summary: `D:\QM\reports\compile\20260805_143205\summary.csv`.
- Strategy Card schema lint: PASS on draft, approved, and EA-local copies;
  zero missing sections and zero ML-ban hits.
- Spec validation: PASS.
- Symbol scope: BASKET_OK with zero violations.
- Combined basket-manifest and magic-resolver regressions: 45 passed.
- Magic rows: `EURUSD.DWX` slot 0 / 202240000 and `EURJPY.DWX` slot 1 /
  202240001.
- Manual smoke or backtest run: none.

Artifact SHA-256 values after the final strict build are:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `7EDA37AF63F23E00DCB930D71EB07AFE4BEF97E30875EC7F83BF5D234F668129` |
| EX5 | `D534838D2C9C993DB151500C836F4E38088D961B2FE90E820DEFB0D31A34AE5B` |
| basket manifest | `F7207377D90FB4FB3447425597F4EC4B2C2709838E0BD44CF4D851F70BB97725` |
| logical Q02 setfile | `397181311F649D5416044D36D6AA70023390EA8B14F97CB75E7FB8818B144254` |
| physical host setfile | `0E11A6F3E305529C0DAE1D5F30081BFE7F30887CCDAC21AEFBC9E54CF747451B` |

## Q02 enqueue and fleet safety

The guarded dry run and apply used
`tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20224`.
The canonical mutation lock was observed busy and never bypassed, removed, or
reaped. The successful acquisition occurred with four running factory
terminals (`T10,T6,T7,T9`), below the binding ceiling of seven.

Queue evidence is
`D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`; despite the
legacy filename, its embedded generation timestamp is
`2026-08-05T16:39:23+02:00`, `apply` is true, and it records one
priority-track logical insertion plus one physical-preset skip. The queue held
1,495 pending rows before insertion against the separate 7,000-row queue
ceiling.

Immediate verification found exactly one QM5_20224 row, Q02 PENDING and
unclaimed. The following path-aware scan observed eight running factory
terminals (`T1,T10,T3,T4,T6,T7,T8,T9`), above the binding ceiling of seven,
so work stopped without a dispatch tick, terminal reservation, tester launch,
T_Live action, AutoTrading action, or portfolio-gate edit.

## Commit chain

- `982b486e3`: source-backed G0 approval and research decision.
- `c25695fef`: deterministic EA-ID reservation (captured with other
  farm-generated artifacts by the canonical pump auto-commit).
- `6250fd139`: deterministic EA, binary, manifest, presets, magic registry,
  resolver, cards, and Q01 evidence.
- The following ops commit records the verified Q02-pending state and this
  handoff.

No portfolio admission/contribution gate and no T_Live manifest was changed.
