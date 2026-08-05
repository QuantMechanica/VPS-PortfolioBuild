# QM5_20225 EURUSD/GBPJPY FX Cointegration Q02 Handoff

Date: 2026-08-05
Branch: agents/board-advisor
Status: Q01 PASS; one logical-basket Q02 work item PENDING

## Outcome

`QM5_20225_eurusd-gbpjpy` is a new, dedicated, low-frequency D1 FX
cointegration basket selected from the frozen sign-aware 66-pair scan. The
source-backed Card, EA source and binary, two-leg basket manifest, magic
registrations, and RISK_FIXED backtest presets are committed on this branch.

Q02 work item `27b74f69-0e65-4c0e-b283-0be2c004ffc5` was enqueued at
2026-08-05T16:14:27Z for logical symbol
`QM5_20225_EURUSD_GBPJPY_COINTEGRATION_D1`. Immediate verification found it
pending and unclaimed. The physical `EURUSD.DWX` host preset was deliberately
skipped with reason `basket_manifest_logical_setfile_preferred`.

## Anchor triage

At selection time, `QM5_12532` had canonical Q02 PASS followed later by Q05
FAIL, and `QM5_12533` had canonical Q02 PASS followed later by Q04 FAIL.
Neither anchor had an open Q02 ONINIT or NO_HISTORY blocker, so repairing or
duplicating their Q02 work was unwarranted.

## Selection and source boundary

The fixed scan was reproduced with:

    python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges

EURUSD/GBPJPY is sign-aware rank 47 of 66:

| Measure | Frozen value |
|---|---:|
| DEV net Sharpe | 0.005489891159 |
| OOS net Sharpe | -0.128823692459 |
| OOS return | -1.095530948436% |
| OOS state changes | 19 |
| DEV beta | -0.242481865669 |
| Half-life | 135.604273551449 D1 bars |

Ranks 45 and 46 were already represented by `QM5_12768` and `QM5_20224`.
The deterministic dedup guard found no exact collision across 4,282 registry
rows and 398 cards. A separate unordered-symbol review of 246 tracked basket
manifests found no dedicated EURUSD/GBPJPY pair. The only fuzzy card hit was
the rank-46 EURUSD/EURJPY sibling, manually resolved as a different second
leg, residual, and logical basket.

The mechanical method is bounded to the OWNER-ratified Tier-A extraction of
Ernest Chan's pair-trading examples in
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Chan
supplies the method, not an EURUSD/GBPJPY performance claim. The negative OOS
result, long half-life, and frequency estimate at the Q02 floor are explicit
adverse evidence. Economic or cadence failure retires this exact sleeve; it
does not authorize a beta refit, filter, or parameter rescue.

## Mechanization

- Host and first traded leg: `EURUSD.DWX`, D1.
- Companion and second traded leg: `GBPJPY.DWX`.
- Conversion-only history: `USDJPY.DWX`; it receives no order or magic slot.
- Frozen residual: `ln(EURUSD) - (-0.242481866) * ln(GBPJPY)`.
- Entry: absolute z-score above 2.0, scored against the strictly prior 60
  aligned closed-D1 residuals.
- Exit: absolute z-score below 0.5; each leg also has a 2.0 ATR(20) stop.
- Negative beta makes long-spread packages long both pairs and short-spread
  packages short both pairs.
- Partial-entry failure and orphaned-leg states flatten the package.
- Backtest risk is `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- No learned, grid, martingale, online-refit, or banned-indicator component
  is present.

## Q01 evidence

- Strict compile: PASS, zero errors and zero warnings.
- Strict build check: PASS, zero failures and zero warnings.
- Build report:
  `D:\QM\reports\framework\21\build_check_20260805_155613.json`.
- Compile summary: `D:\QM\reports\compile\20260805_155614\summary.csv`.
- Strategy Card schema lint: PASS on all three canonical copies; zero missing
  sections and zero ML-ban hits.
- Spec validation: PASS.
- Symbol scope: BASKET_OK with zero violations.
- Basket-manifest regression: 40 passed; magic-resolver regressions: 5 passed.
- Magic rows: `EURUSD.DWX` slot 0 / 202250000 and `GBPJPY.DWX` slot 1 /
  202250001.
- Manual smoke or backtest run: none.

Artifact SHA-256 values after the strict build are:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `B65C927D0BD4775F2A52841B88577098C10B74FE9376AC9DB14ACDD231D7463A` |
| EX5 | `9476A9B597E8F9A5C17715D2874E63976C0DED71B948A0DF30ADBC41E06EFCF5` |
| basket manifest | `EB2EAF3593F55D940A032FE8F8B0AB4E7DB8536207D700A59CBA383BA07B00AD` |
| logical Q02 setfile | `B6E6D23636AF327339724D55D264A98B5A4AE190260FA142F764D89A1413D42F` |
| physical host setfile | `18AC70391398057C12BBBEFB81B555C6963F8823A5334EC1ECEBA1F5FEB33CC3` |

## Q02 enqueue and fleet safety

The guarded dry run and apply used
`tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20225`.
The canonical mutation lock was contended, then acquired normally; it was
never bypassed, removed, or manually reaped. The last pre-enqueue fleet
sample observed five running factory terminals, below the ceiling of seven.

Queue evidence is
`D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`; despite the
legacy filename, its embedded generation timestamp is
`2026-08-05T18:14:27+02:00`, `apply` is true, and it records one
priority-track logical insertion plus one physical-preset skip.

Final verification observed four running factory terminals
(`T1,T10,T6,T7`), still below the ceiling. No dispatch tick, terminal
reservation, tester launch, T_Live action, AutoTrading action, or
portfolio-gate edit was performed.

## Commit chain

- `2cc194124`: source-backed G0 approval and research decision.
- `3d38b33ac`: deterministic EA-ID reservation.
- `1c8aa724e`: canonical pump capture of magic rows, resolver, and initial
  setfiles.
- `59006fb61`: deterministic EA, binary, manifest, final presets, cards, and
  Q01 evidence.
- The following operations commit records the verified Q02-pending state and
  this handoff.

No portfolio admission/contribution gate and no T_Live manifest was changed.
