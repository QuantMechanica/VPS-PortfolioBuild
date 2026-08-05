# QM5_11561 USDJPY Q01 Refresh and Q02 Exclusion

Date: 2026-08-05 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

`QM5_11561_singh-good-morning-asia-d1-usdjpy` was recovered from a stale
generation-1 build-result rework, refreshed to the current V5 Q08
instrumentation hook, compiled strictly, and smoke-validated on
`USDJPY.DWX` D1. The farm accepted the build result and closed the build task
as `done`.

Q02 was **not** enqueued. The deterministic recorder refused the setfile with
`requeue_excluded_q02` because `QM5_11561` is explicitly listed in
`D:/QM/strategy_farm/state/requeue_excluded_eas.txt`. That file is the governed
exclusion cohort for built FX cards with
`expected_trades_per_year_per_symbol > 100`; this approved card declares 200.
Removing the entry would have contradicted both that gate and this wake's
low-frequency constraint, so no bypass or manual work-item insertion was made.

## Selection and Farm Claim

The pending build inventory was checked through the shared farm claim guard.
Only two rows were claimable:

1. `QM5_11561`: USDJPY FX, D1, expected 200 trades/year/symbol.
2. `QM5_20012`: XAU/XAG relative-value metals, expected 8 packages/year.

`QM5_11561` was selected for instrument diversity because the current Q08
survivors are concentrated in indices, metals, and energy. That choice was
subsequently rejected at the enqueue boundary by the farm's explicit FX
high-frequency exclusion. The exclusion should be included in future backlog
selection preflight, before spending Q01 smoke capacity.

- Build task: `d1c384ae-35ca-4887-aff6-369121a731b2`.
- Agent claim: `51c83e3f-0601-4f27-83ab-af98eecc1280`.
- Claim owner: `codex` (`claimed_by=codex:agents/board-advisor`).
- Build generation: 1.
- Attempt token: `0f03e265-60fe-4b2b-9595-87c911f134ed`.
- Pre-claim online DB backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11561_claim_20260805T075445Z.sqlite`.
- Backup `PRAGMA quick_check`: `ok`.
- No open work item or competing managed build lease existed at claim time.

## Strategy and Build Scope

The approved Mario Singh card remains mechanically unchanged:

- compare the prior completed USDJPY D1 candle's close with its open;
- buy after a bullish prior day and sell after a bearish prior day;
- use the prior-day structure with a 30-pip minimum and 80-pip cap;
- take profit at 0.5 times final stop distance on the profit side;
- skip Friday entries and retain framework Friday close;
- one position per magic, no ML, grid, martingale, or adaptive inputs.

The source change is instrumentation-only:
`QM_FrameworkTrackOpenPositionMae()` is now the first `OnTick` statement, as
required by the current skeleton for complete Q08 floating-MAE evidence. Entry,
exit, sizing, filters, and order timing were not changed. The exact approved
card was copied to `docs/strategy_card.md`, and `SPEC.md` records the
instrumentation refresh.

The approved card contains a sign typo in its detailed TP formula (it puts the
long TP below entry and short TP above entry) while its concept and 0.5R
description clearly specify a profit-side target. The existing EA retains the
profit-side interpretation; this ambiguity is also recorded in the build
result's `open_questions`.

## Q01 Evidence

- `validate_spec_doc.py`: PASS, 1/1.
- Farm prebuild validation: PASS, no errors or warnings.
- Strict build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260805_080258.json`.
- Post-setfile build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260805_080436.json`.
- Standalone strict compile: PASS, 0 errors and 0 warnings:
  `D:/QM/reports/compile/20260805_080350/summary.csv`.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260805_080350/QM5_11561_singh-good-morning-asia-d1-usdjpy.compile.log`.
- Backtest setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, slot 0, `USDJPY.DWX`, D1.

One governed `-Terminal any -SmokeMode` invocation was admitted to T4 while
six factory terminals were active, below the seven-terminal ceiling. It ran
Model 4 over calendar year 2024. Both deterministic runs produced 180 trades,
PF 0.68, net -24,538.47, and drawdown 25,433.88 (25.21%). Reports were
stable, the source and deployed EX5/setfile hashes matched, and there was no
OnInit failure, timeout, or log bomb. Q01 smoke tests execution, not economics;
the negative performance is recorded without reinterpretation.

- Smoke result: PASS.
- Summary: `D:/QM/reports/smoke/QM5_11561/20260805_080515/summary.json`.
- Framework evidence:
  `D:/QM/reports/framework/22/20260805_080515_QM5_11561_T4_USDJPY_DWX_run_smoke.md`.

## Artifact Identities

| Artifact | SHA-256 |
|---|---|
| MQ5 | `c2537b7e376d279f78a1c614d669d9aebe6d54c319ccb019740973e77649ca42` |
| EX5 | `360ef696bb96a4ec88b1b858680f0ce62583b773198390e6bf4453c18ca89f36` |
| SPEC | `c5cd2fe0fd9a28d7abd0b340c36fce5dd4a4c3b5c41497e06cc4320952a22084` |
| Approved-card copy | `bb50a3fac3451ebd0dba13dcd632633994840b17ce513daac3dcccda396a21ae` |
| Backtest setfile | `2336061f76901c535a2554368c6125f45b764581bbd54de7344fee961b70d338` |
| Build result | `2198ebe649622332d2afc895d24cb4abb2c85ec82d073eb9a3964848575b6a4a` |
| Smoke summary | `17e3b69283ad58c529495b783d590e427005be1ca19d897fe093223f85336374` |

The deterministic farm dirty guard committed the EX5 and setfile as commit
`35f09256b4538fa99bb120fc6a32929e02fe427d`. The source, SPEC, approved-card
copy, and this evidence are committed together in the scoped completion commit.

## Farm Close State

`farmctl record-build` accepted the immutable generation/token-bound result:

- build task status: `done`;
- smoke result: `passed`;
- build-result SHA-256:
  `2198ebe649622332d2afc895d24cb4abb2c85ec82d073eb9a3964848575b6a4a`;
- Q02 enqueued: 0;
- Q02 skipped: `requeue_excluded_q02`;
- `QM5_11561` work-item count after recording: 0.

The next paced wake should select a constraint-qualified low-frequency card or
a diverse Q02/Q03 infrastructure repair; it should not re-claim this EA unless
the governed exclusion policy itself is changed by its authority owner.

## Safety Boundary

- No Q02 or other pipeline backtest was manually launched.
- No exclusion entry was removed or overridden.
- No registry row was added, removed, or changed.
- AutoTrading was not toggled.
- `T_Live`, the portfolio gate, deploy manifests, and the T_Live manifest were
  not touched.
