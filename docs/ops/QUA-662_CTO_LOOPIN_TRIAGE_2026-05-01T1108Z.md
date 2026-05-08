# QUA-662 CTO loop-in triage (2026-05-01T11:08Z)

Acknowledges CEO comments `b4fd247e-...` and `cb81c858-...` and provides actionable package for CTO review.

## Sub-issue A: Magic resolver patch review package

Current code diff:
- `framework/include/QM/QM_MagicResolver.mqh`
- Added baked registry row for `ea_id=1003` (`slot=0`, `EURUSD.DWX`, `magic=10030000`)
- Added temporary unconditional override in `QM_MagicRegistered()` for `ea_id=1003/slot0` when computed magic matches.

Open decisions for CTO (required):
1. Is baked registry row for `1003` canonical and sufficient, or should this come solely from generated registry tooling/manifest?
2. Is the temporary override migration-only and must be removed after tooling repair, or should it remain until a broader registry refactor?
3. Confirm DL-036 gate position for this runtime guard.

## Sub-issue B: Malformed tester invocation / report integrity

Reproduced deterministically in isolated lane:
- run tag: `20260501_103949`
- summary: `D:\QM\reports\pipeline\QM5_1003\P2_isolated_retry\QM5_1003\20260501_103949\summary.json`
- report files: nonzero `2/2` (`22332` bytes each)
- report settings malformed (`M0/1970`, `Deposit=0`, `Leverage=1:0`)
- tester logs contain real order/deal flow

Interpretation: report export/invocation integrity defect; not EA-edge weakness.

## Concrete progress this heartbeat

1. Added explicit corruption guard in smoke runner:
- file: `framework/scripts/run_smoke.ps1`
- new reason class: `REPORT_CORRUPT`
- trigger conditions:
  - `Period=M0 (1970...)`
  - `Initial Deposit=0`
  - `Leverage=1:0`
- per-run field added in summary: `report_corrupt`

2. Validation attempt after guard patch:
- run root: `D:\QM\reports\pipeline\QM5_1003\P2_isolated_retry_guard\QM5_1003\20260501_104524`
- observed outcome: launch path hung again (only `tester.ini` produced; no report/summary)
- classified as runtime hang symptom (`INCOMPLETE_RUNS`/`METATESTER_HUNG` class lane)
- terminated stuck T1-scoped processes after timeout to clear factory state.

## Unblock owner/action

- owner: CTO (+ Development for launcher/runtime path)
- action:
1. Review/approve or amend `QM_MagicResolver.mqh` patch strategy.
2. Root-cause and fix MT5 invocation/report export corruption path.
3. Confirm whether `run_smoke` should hard-fail `REPORT_CORRUPT` as release blocker (recommended yes).

## Next action (Pipeline-Operator)

- Keep isolated single-terminal runs only.
- Continue strict rejection (`EA_MAGIC_NOT_REGISTERED`, `REPORT_MISSING`, `METATESTER_HUNG`, history errors, and now `REPORT_CORRUPT`).
- Rebuild P2 evidence only after CTO confirms patch posture and launcher fix direction.
