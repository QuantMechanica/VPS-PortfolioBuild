# QM5_20228 USDCAD/GBPJPY FX Cointegration Q02 Handoff

Date: 2026-08-05
Branch: agents/board-advisor
Status: Q01 PASS; one logical-basket Q02 work item PENDING

## Outcome

`QM5_20228_usdcad-gbpjpy` is a new, dedicated, low-frequency D1 FX
cointegration basket selected from the frozen sign-aware 66-pair scan. The
source-backed Card, EA source and binary, two-leg basket manifest, deterministic
registries, and RISK_FIXED backtest presets are committed on this branch.

Q02 work item `41722d88-1113-4e08-ac39-832b4708ee2d` was enqueued at
2026-08-05T17:59:15Z for logical symbol
`QM5_20228_USDCAD_GBPJPY_COINTEGRATION_D1`. Immediate verification found it
pending and unclaimed. The physical `USDCAD.DWX` host preset was deliberately
skipped with reason `basket_manifest_logical_setfile_preferred`.

## Anchor triage

- `QM5_12532` has canonical logical-basket Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533` has canonical logical-basket Q02 PASS, followed by Q04 FAIL.
- Direct queue-state inspection found zero pending or active Q02 rows for both
  anchors and no current ONINIT or NO_HISTORY blocker.

Historical physical-leg or predecessor NO_HISTORY rows are superseded by the
logical-basket passes. Repairing or duplicating either anchor was unwarranted.

## Selection and source boundary

The fixed scan was reproduced with:

    python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges

USDCAD/GBPJPY is sign-aware rank 50 of 66:

| Measure | Frozen value |
|---|---:|
| DEV net Sharpe | 0.011529211278 |
| OOS net Sharpe | -0.194853220842 |
| OOS return | -1.353675266917% |
| OOS state changes | 15 |
| DEV beta | -0.231842927371 |
| Half-life | 65.506779483043 D1 bars |

Ranks 48 and 49 are already represented by `QM5_12770` (EURUSD/EURGBP) and
`QM5_12772` (GBPJPY/AUDJPY). The deterministic dedup guard found no exact
slug or strategy-ID collision across 4,285 registry rows and 401 cards. Two
fuzzy sibling hits were manually resolved as different exact pairs. A separate
unordered-symbol review of 247 tracked basket manifests found no dedicated
USDCAD/GBPJPY two-leg basket.

The mechanical method is bounded to the OWNER-ratified Tier-A extraction of
Ernest Chan's pair-trading examples in
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Chan supplies
the method, not a USDCAD/GBPJPY performance claim. Negative OOS performance,
the slow half-life, and cadence inferred below the binding Q02 floor are
explicit adverse evidence. Economic or cadence failure retires this exact
sleeve; it does not authorize beta refit, filters, or parameter rescue.

## Mechanization

- Host and first traded leg: `USDCAD.DWX`, D1.
- Companion and second traded leg: `GBPJPY.DWX`.
- Conversion-only history: `USDJPY.DWX`; no order or magic slot.
- Frozen residual: `ln(USDCAD) - (-0.231842927) * ln(GBPJPY)`.
- Entry: absolute z-score above 2.0 against the strictly prior 60 aligned
  closed-D1 residuals.
- Exit: absolute z-score below 0.5; each leg also has a 2.0 ATR(20) hard stop.
- Negative beta makes long-spread packages long both pairs and short-spread
  packages short both pairs.
- Partial-entry failure and orphaned-leg states flatten the package.
- Backtest risk is `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- No learned, grid, martingale, online-refit, or banned-indicator component is
  present.

## Q01 evidence

- Strict compile: PASS, zero errors and zero warnings.
- Strict build check: PASS, zero failures and zero warnings.
- Build report:
  `D:\QM\reports\framework\21\build_check_20260805_175800.json`.
- Compile summary: `D:\QM\reports\compile\20260805_175800\summary.csv`.
- Strategy Card schema lint: PASS on all three canonical copies; zero missing
  sections and zero ML-ban hits.
- Spec validation: PASS.
- Symbol scope: BASKET_OK with zero violations.
- Basket-manifest and magic-resolver regressions: 45 passed.
- Magic rows: `USDCAD.DWX` slot 0 / 202280000 and `GBPJPY.DWX` slot 1 /
  202280001.
- Manual smoke or backtest run: none.

Artifact SHA-256 values after the final strict build are:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `1675651B00AA75803CDA7E581A55D5BFB2FF2D7E3140557A942B4C98428FF948` |
| EX5 | `5C96776EBDD0D30DB739774946B1D53BB36374AC795E3DE90413C04AD10F54A2` |
| basket manifest | `8D8A4D7C94EFC2D373CAA9F8C97FE1FD4EE493CD0FDE9D4B440D265AEC341BB8` |
| logical Q02 setfile | `17FFC468871ACCAE43EAD206BDF97F5A32C3AA8BC314E608E666C46C154C67E7` |
| physical host setfile | `7520198010B3EC59345C0D30DB126D7B0D6B49E95E64122BB4C65EF03165AF87` |

## Q02 enqueue and fleet safety

The guarded dry run and apply used
`tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20228`.
The pre-enqueue path-aware sample observed five running factory terminals
(`T3,T4,T5,T8,T9`), below the binding ceiling of seven.

Queue evidence is
`D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`; despite the
legacy filename, its embedded generation timestamp is
`2026-08-05T19:59:15+02:00`, `apply` is true, and it records one priority-track
logical insertion plus one physical-preset skip. The queue held 1,538 pending
rows before insertion against the separate 7,000-row queue ceiling.

Immediate verification found exactly one QM5_20228 row, Q02 PENDING and
unclaimed. The final sample reached the binding seven-terminal ceiling
(`T2,T4,T5,T6,T8,T9,T10`), so work stopped without a dispatch tick, terminal
reservation, tester launch, `T_Live` action, AutoTrading action, or
portfolio-gate edit.

## Commit chain

- `89763db67`: source-backed G0 approval and Strategy Card.
- `a9e5cbd79`: atomic deterministic EA-ID reservation.
- `04852f120`: deterministic EA, binary, manifest, presets, magic rows,
  resolver, approved cards, and initial Q01 evidence.
- `9cd7f2b76`: final zero-warning Q01 compile and hash-clean artifacts.
- The following operations commit records the verified Q02-pending state and
  this handoff.

No portfolio admission/contribution gate and no `T_Live` manifest was changed.
