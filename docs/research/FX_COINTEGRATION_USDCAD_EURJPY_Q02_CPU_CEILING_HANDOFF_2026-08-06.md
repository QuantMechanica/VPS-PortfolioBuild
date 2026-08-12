# QM5_20238 USDCAD/EURJPY Q02 CPU-Ceiling Handoff

Date: 2026-08-06

Branch: `agents/board-advisor`

Status: new non-duplicate FX basket built and Q01 PASS; Q02 not enqueued because the binding backtest CPU ceiling was exceeded

## Outcome

`QM5_20238_usdcad-eurjpy` is a new, dedicated, low-frequency D1 FX
cointegration basket selected as rank 57 from the frozen sign-aware 66-pair
scan. Its source-backed approved Card, deterministic ID and magic rows, EA
source and binary, two-leg basket manifest, and `RISK_FIXED` backtest presets
are committed on this branch.

Q02 was deliberately not enqueued. The mandatory path-anchored sample at
`2026-08-06T03:03:20Z` found eight running factory terminals:

```text
T1, T2, T4, T5, T7, T8, T9, T10
```

Eight exceeds the paced-fleet seven-terminal backtest ceiling. No non-factory
MT5 terminal was present in the sample. Per the mission stop rule, no queue
mutation, dispatch tick, terminal reservation, tester launch, terminal-control
action, or AutoTrading action followed.

## Anchor triage

- `QM5_12532` has canonical logical-basket Q02 PASS and later Q05 FAIL.
- `QM5_12533` has canonical logical-basket Q02 PASS and later Q04 FAIL.
- Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

Re-enqueueing either anchor would duplicate terminal Q02 work.

## Selection and source boundary

The current exact-pair audit found no pre-existing USDCAD/EURJPY Strategy
Card, dedicated EA, registry row, or exact two-leg traded-symbol manifest.
`QM5_11055_pst-assettrend` only mentions both symbols inside a broad trend
universe and does not duplicate this frozen residual or package.

The fixed scan was reproduced with:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

| Measure | Frozen value |
|---|---:|
| Sign-aware rank | 57 of 66 |
| DEV net Sharpe | -0.006562345356 |
| OOS net Sharpe | -0.403385422796 |
| OOS return | -2.696283405216% |
| OOS state changes | 13 |
| DEV beta | -0.243266890557 |
| Half-life | 66.784057177571 D1 bars |

The reputable structural method is bounded to the OWNER-ratified Tier-A
extraction of Ernest Chan's pair-trading examples at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Chan supplies
the mechanical method, not a USDCAD/EURJPY performance claim. The adverse
scan result and sub-floor inferred cadence make Q02 a one-shot retirement
gate; they do not authorize beta refit, filters, or parameter rescue.

## Mechanization

- Host and first traded leg: `USDCAD.DWX`, D1.
- Companion and second traded leg: `EURJPY.DWX`.
- Conversion-only history: `USDJPY.DWX`; no order or magic slot.
- Frozen residual: `ln(USDCAD) - (-0.243266890557) * ln(EURJPY)`.
- Entry: `abs(z) > 2.0` against the strictly prior 60 aligned closed-D1
  residuals.
- Exit: `abs(z) < 0.5`; each leg also has a `2.0 * ATR(20, D1)` hard stop.
- Negative beta makes long-spread packages long both pairs and short-spread
  packages short both pairs.
- Partial-entry failure and orphaned-leg states flatten the package.
- Backtest risk is `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Magic rows: `USDCAD.DWX` slot 0 / `202380000`; `EURJPY.DWX` slot 1 /
  `202380001`.

No learned model, banned indicator, grid, martingale, online refit, live
setfile, or deployment artifact is present.

## Q01 evidence

- Strict compile: PASS, zero errors and zero warnings.
- Strict build check: PASS, zero failures and zero warnings.
- Build report:
  `D:\QM\reports\framework\21\build_check_20260806_030058.json`.
- Compile summary: `D:\QM\reports\compile\20260806_025916\summary.csv`.
- Strategy Card schema lint: PASS on all three canonical copies.
- Spec validation: PASS.
- Targeted basket and magic-resolver tests: 22 passed.
- Manual smoke or backtest run: none.

Artifact SHA-256 values after the strict build are:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `9B359E39CE56D480F5F46165FC9A6E47902776A094B690046C0B308244AE28F0` |
| EX5 | `1FF7CBABAD8113FABC3044884E219F5AECFEB5BE8AF1AB1EF4EAF176F62D2364` |
| Basket manifest | `8ECE7B02E3DBBCCAE32FC1ED7C79BA28B011C902F886264FB7D6EF3A89DD9098` |
| Logical Q02 setfile | `58B5564EDD4F9E151DB023DA595A4AEFC6FF5A45B7ACCB192EED5ECEBB997A73` |
| Physical host setfile | `3B3110C730D228358DF518990CB73D49B6F72216706D5B419E2E7E7F9866AB93` |

## Next paced action

After a fresh path-anchored sample is below the seven-terminal ceiling, use a
guarded dry run and exact apply of
`tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20238`, verify that
the logical basket preset is selected and the physical host preset is skipped,
and enqueue exactly one Q02 work item. Do not dispatch or launch a tester as
part of that handoff.

## Commit chain and safety

- `9fbec5726`: durable G0 authorization and source-backed Card.
- `f6be906b5`: deterministic EA-ID allocation.
- `67ffdfc20`: compiled basket build, presets, Card copies, and magic rows.

No portfolio-admission, portfolio KPI, Q08-contribution, `T_Live` manifest,
live deployment, or AutoTrading state was changed.
