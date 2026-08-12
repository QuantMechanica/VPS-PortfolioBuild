# QM5_20250 USDCHF/AUDJPY FX Cointegration Q02 Handoff

Date: 2026-08-06

Branch: `agents/board-advisor`

Status: Q01 PASS; one logical-basket Q02 work item PENDING

## Outcome

`QM5_20250_usdchf-audjpy` is a new, dedicated, low-frequency D1 FX
cointegration basket selected as rank 61 from the frozen sign-aware 66-pair
scan. Its source-backed approved Card, deterministic ID and two traded-symbol
magic rows, EA source and binary, two-leg basket manifest, and `RISK_FIXED`
backtest presets are committed on this branch.

Q02 work item `f3205711-11a3-4bf8-8e11-a4133159301a` was enqueued at
`2026-08-06T18:01:47Z` for logical symbol
`QM5_20250_USDCHF_AUDJPY_COINTEGRATION_D1`. Immediate verification found
exactly one row, pending and unclaimed. The physical `USDCHF.DWX` host preset
was deliberately skipped with reason
`basket_manifest_logical_setfile_preferred`.

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

USDCHF/AUDJPY is sign-aware rank 61 of 66:

| Measure | Frozen value |
|---|---:|
| DEV net Sharpe | -0.046223926559 |
| OOS net Sharpe | -0.498677810996 |
| OOS return | -4.919952558569% |
| OOS state changes | 15 |
| DEV beta | -0.027722525061 |
| Half-life | 97.105594983326 D1 bars |

Rank 60 USDJPY/EURGBP is already built as `QM5_20246`. The deterministic
dedup check found no exact USDCHF/AUDJPY slug or strategy-ID collision across
4,307 registry rows and 424 cards. Three fuzzy sibling hits share only one
leg. An exact traded-symbol manifest review found no dedicated two-leg basket,
and the Caldeira umbrella does not contain AUDJPY.

The mechanical method is bounded to the OWNER-ratified Tier-A extraction of
Ernest Chan's pair-trading examples in
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Chan supplies
the method, not a USDCHF/AUDJPY performance claim. Negative DEV and OOS
performance, the slow half-life, and cadence inferred below the binding Q02
floor are explicit adverse evidence. Economic or cadence failure retires this
exact sleeve; it does not authorize beta refit, filters, or parameter rescue.

## Mechanization

- Host and first traded leg: `USDCHF.DWX`, D1.
- Companion and second traded leg: `AUDJPY.DWX`.
- Conversion-only history: `AUDUSD.DWX` and `USDJPY.DWX`; no orders or magic
  slots.
- Frozen residual:
  `ln(USDCHF) - (-0.027722525061) * ln(AUDJPY)`.
- Entry: `abs(z) > 2.0` against the strictly prior 60 aligned closed-D1
  residuals.
- Exit: `abs(z) < 0.5`; each leg also has a `2.0 * ATR(20, D1)` hard stop.
- Negative beta makes long-spread packages long both pairs and short-spread
  packages short both pairs.
- Partial-entry failure and orphaned-leg states flatten the package.
- Backtest risk is `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Magic rows: `USDCHF.DWX` slot 0 / `202500000`; `AUDJPY.DWX` slot 1 /
  `202500001`.

No learned model, banned indicator, grid, martingale, online refit, live
setfile, or deployment artifact is present.

## Q01 evidence

- Strict compile: PASS, zero errors and zero warnings.
- Strict build check: PASS, zero failures and zero warnings.
- Build report:
  `D:\QM\reports\framework\21\build_check_20260806_175944.json`.
- Compile summary: `D:\QM\reports\compile\20260806_175945\summary.csv`.
- Strategy Card schema lint: PASS; zero missing sections and zero ML-ban hits.
- Basket-manifest regression suite: 42 passed.
- Manual smoke or backtest run: none.

Artifact SHA-256 values after the final strict build are:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `2F7483010DB91551DBCF90E74A3327322F5E2F028C7094B2F1B174129F8D800E` |
| EX5 | `3268C3BD26A9FB3745E65F4098258D1C2F130EFC340CFCCAFCB6A017E92C366F` |
| Basket manifest | `83E1EEBD6645F4ED92385233633F5FD04B3DBE274787722CAB673237CC24E321` |
| Logical Q02 setfile | `A0AB90CB8981EDD8AD1163376BF8684A7F3F0DE28BEEE0364D17B2538D644534` |
| Physical host setfile | `CB70FBAB960A3CF824C1616E24DA68D1C09E2709D79257C09FE4A69354BDBC30` |

## Q02 enqueue and fleet safety

The guarded dry run and apply used
`tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20250 --apply`.
Queue evidence is
`D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`; despite the
legacy filename, its embedded generation timestamp is
`2026-08-06T18:01:47Z`, `apply` is true, and it records one priority-track
logical insertion plus one physical-preset skip. The queue held 1,491 pending
rows before insertion against the separate 7,000-row queue ceiling.

The mandatory pre-enqueue sample at `2026-08-06T18:01:15Z` observed five
running factory terminals (`T2`, `T3`, `T5`, `T6`, and `T9`), below the
binding ceiling of seven. The verification sample at
`2026-08-06T18:02:52Z` observed the same five. `T_Live` and an unrelated FTMO
terminal were observed separately and excluded; neither was controlled.

No dispatch tick, terminal reservation, tester launch, terminal-control
action, AutoTrading action, portfolio-admission change, portfolio KPI change,
Q08-contribution change, live manifest edit, or deployment action was made.

## Commit chain

- `d55d6f2bd`: durable G0 authorization and source-backed Strategy Card.
- `61dbe2ac6`: atomic deterministic EA-ID reservation.
- `9fb0c5cac`: deterministic magic rows and regenerated resolver.
- `89943af54`: compiled basket build, manifest, fixed-risk presets, Card
  copies, regression coverage, and Q01 evidence.
- The following operations commit records the verified Q02-pending state and
  this handoff.
