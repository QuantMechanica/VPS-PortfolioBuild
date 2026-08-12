# QM5_20255 USDCHF/EURJPY FX Cointegration Q02 Handoff

Date: 2026-08-06

Branch: `agents/board-advisor`

Status: Q01 PASS; one logical-basket Q02 work item PENDING

## Outcome

`QM5_20255_usdchf-eurjpy` is a new, dedicated, low-frequency D1 FX
cointegration basket selected as rank 64 from the frozen sign-aware 66-pair
scan. Its source-backed approved Card, deterministic ID and two traded-symbol
magic rows, EA source and binary, two-leg basket manifest, and `RISK_FIXED`
backtest presets are committed on this branch.

Q02 work item `72ca17ca-f9df-40d5-806d-1d815ee4ea08` was enqueued at
`2026-08-06T22:13:31Z` for logical symbol
`QM5_20255_USDCHF_EURJPY_COINTEGRATION_D1`. Immediate verification found
exactly one row, pending and unclaimed. The physical `USDCHF.DWX` host preset
was deliberately skipped with reason
`basket_manifest_logical_setfile_preferred`.

This handoff supersedes the no-mutation continuation in
`docs/research/FX_COINTEGRATION_USDCHF_EURJPY_PREFLIGHT_CPU_STOP_2026-08-06.md`:
the candidate remained unbuilt, and the fresh paced-fleet capacity check was
below the binding ceiling.

## Anchor triage

- `QM5_12532` has canonical logical-basket Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533` has canonical logical-basket Q02 PASS, followed by Q04 FAIL.
- Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

Re-enqueueing or modifying either anchor would duplicate completed funnel
work.

## Selection and source boundary

The fixed scan was reproduced with:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

USDCHF/EURJPY is sign-aware rank 64 of 66:

| Measure | Frozen value |
|---|---:|
| DEV net Sharpe | -0.045661686086 |
| OOS net Sharpe | -0.547994298753 |
| OOS return | -5.473566746133% |
| OOS state changes | 15 |
| DEV beta | -0.075286902527 |
| Half-life | 97.411859950023 D1 bars |

Rank 63 USDCHF/EURAUD is already built as `QM5_20252`. The deterministic
dedup check found no exact USDCHF/EURJPY slug or strategy-ID collision across
4,312 registry rows and 429 direct cards. No tracked dedicated two-leg
manifest or explicit umbrella pair slot implemented the relationship. Six
broad basket manifests contain both symbols only as unrelated universe
members.

The mechanical method is bounded to the OWNER-ratified Tier-A extraction of
Ernest Chan's pair-trading examples in
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Chan supplies
the method, not a USDCHF/EURJPY performance claim. Negative DEV and OOS
performance, the slow half-life, and cadence inferred below the binding Q02
floor are explicit adverse evidence. Economic or cadence failure retires this
exact sleeve; it does not authorize beta refit, filters, or parameter rescue.

## Mechanization

- Host and first traded leg: `USDCHF.DWX`, D1.
- Companion and second traded leg: `EURJPY.DWX`.
- Conversion-only history: `USDJPY.DWX`; no order or magic slot.
- Frozen residual:
  `ln(USDCHF) - (-0.075286902527) * ln(EURJPY)`.
- Entry: `abs(z) > 2.0` against the strictly prior 60 aligned closed-D1
  residuals.
- Exit: `abs(z) < 0.5`; each leg also has a `2.0 * ATR(20, D1)` hard stop.
- Negative beta makes long-spread packages long both pairs and short-spread
  packages short both pairs.
- Partial-entry failure and orphaned-leg states flatten the package.
- Backtest risk is `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Magic rows: `USDCHF.DWX` slot 0 / `202550000`; `EURJPY.DWX` slot 1 /
  `202550001`.

No learned model, banned indicator, grid, martingale, online refit, live
setfile, or deployment artifact is present.

## Q01 evidence

- Strict compile: PASS, zero errors and zero warnings.
- Strict build check: PASS, zero failures and zero warnings.
- Build report:
  `D:\QM\reports\framework\21\build_check_20260806_221156.json`.
- Compile summary: `D:\QM\reports\compile\20260806_221113\summary.csv`.
- Strategy Card schema lint: PASS; zero missing sections and zero ML-ban hits.
- Basket-manifest regression suite: 44 passed.
- Manual smoke or backtest run: none.

Artifact SHA-256 values after the final strict build are:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `67CCFBD144462D561DB675C706B7DFBEA795733F0FC6DF5E404E3EAE2785CD02` |
| EX5 | `B5DFB19D02B20C8754B9B5A400FE81750A315313580ECEE9931A619416846D53` |
| Basket manifest | `090EF3BE8E740003541BC911ABB691599B28C92AA09EFC557086FCC5F4FF5F17` |
| Logical Q02 setfile | `B4FB11D85874F8A382C3785C16783761EC791ADD216A89CB3DEE0A8308BF3EEC` |
| Physical host setfile | `6E071EF9C6F9A7678631FA4C51B6458A7E8B48769899C4A82FB971166A1851F4` |

## Q02 enqueue and fleet safety

The guarded dry run and apply used
`tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20255 --apply`.
Queue evidence is
`D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`; despite the
legacy filename, its embedded generation timestamp is
`2026-08-06T22:13:31Z`, `apply` is true, and it records one priority-track
logical insertion plus one physical-preset skip. The queue held 1,435 pending
rows before insertion against the separate 7,000-row queue ceiling.

The mandatory immediate pre-enqueue sample at `2026-08-06T22:13:28Z`
observed four running factory terminals (`T1`, `T2`, `T5`, and `T8`), below
the binding ceiling of seven. `T_Live` and an unrelated FTMO terminal were
observed separately and excluded; neither was controlled.

No dispatch tick, terminal reservation, tester launch, terminal-control
action, AutoTrading action, portfolio-admission change, portfolio KPI change,
Q08-contribution change, live manifest edit, or deployment action was made.

## Commit chain

- `d1b93853e`: durable G0 authorization and source-backed Strategy Card.
- `0b8be81c4`: atomic deterministic EA-ID reservation.
- `e75a0a769`: deterministic magic rows and regenerated resolver.
- `5bb9be7c0`: compiled basket build, manifest, fixed-risk presets, Card
  copies, regression coverage, and Q01 evidence.
- The following operations commit records the verified Q02-pending state and
  this handoff.
