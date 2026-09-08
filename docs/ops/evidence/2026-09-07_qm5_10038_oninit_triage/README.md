# QM5_10038 Vein-1 Q02 OnInit triage

- Router task: `83efd045-8aea-43b8-b09f-e7699c0c9b72`
- Scope: read the failed Q02 receipts, classify the refusal, audit the Vein-1
  cohort, and close the missing-diagnostic archive defect.
- Branch: `agents/board-advisor`
- Operator phases: Q-only

## Verdict

`FIX_FRAMEWORK_AND_REBUILD_STALE_BINARY`; do not retire QM5_10038 and do not
blind-requeue any of the failed rows.

The representative USDCAD receipt used EX5 SHA-256
`61833c537bb10b731ea9c63717ccea8b720d91cf8c671fa469d2ebe06a313891`,
whose canonical file timestamp is 2026-06-21. The USDCAD slot-10 registry row
was added on 2026-08-23. The copied tester journal records:

`EA_MAGIC_NOT_REGISTERED: ea_id=10038 slot=10 magic=100380010`

The same binary therefore cannot authenticate registry slots 4-12 added after
it was built. This is a stale embedded resolver/build-identity defect, not an
EA strategy defect. The representative setfile remains compliant:
`RISK_FIXED=1000`, `RISK_PERCENT=0`; the run receipt reports news calendar
`status=OK`, age 11 hours, and maximum age 336 hours. No guardrail was relaxed.

Primary receipt:
`D:/QM/reports/work_items/901d3f05-d4f6-4ff4-a6c3-34fa45b54b6c/QM5_10038/20260907_144322/summary.json`.
Its archived tester journal is
`raw/run_01/20260907.log`, line 174256 in the copied daily file.

## Vein-1 cohort

A read-only query of `work_items.payload_json` found nine Vein-1 rows whose
stored reason contains `ONINIT_FAILED`; every row is already terminal
`done/INFRA_FAIL` and was left unchanged.

| EA | Symbols | Rows | Journal diagnosis |
|---|---|---:|---|
| `QM5_10038` | AUDUSD, NZDUSD, USDCAD, USDCHF | 4 | stale embedded resolver; slots 4/10/11 observed |
| `QM5_10069` | AUDUSD, NZDUSD, USDCAD, USDCHF | 4 | stale embedded resolver; slots 4/7/10/11 observed |
| `QM5_10116` | AUDUSD | 1 | stale embedded resolver; slot 4 observed |

The QM5_10038/NZDUSD receipt exposed a second defect. Its copied shared daily
journal contains the preceding AUDUSD run's slot-4 OnInit failure, while the
NZDUSD attempt itself ended before an exact test-start marker with
`authorization failed (Invalid parameters)`. The old current-run extractor
fell back to the whole tail when no marker matched, so that receipt inherited
the prior run's OnInit classification. It is not independent evidence of an
NZDUSD OnInit refusal.

## Repair

1. `QM_FrameworkInitCoreAfterRuntimeStateArmed` now arms the structured per-EA
   logger with magic zero before any fail-closed validation. Runtime-state,
   EA-ID, portfolio-weight, risk-input, and magic-resolution refusals emit a
   structured `FRAMEWORK_INIT_FAILED` reason. After the registry binding is
   authenticated, the logger receives the resolved magic. A future genuine
   OnInit refusal can therefore be retained by run_smoke's existing logger
   delta archive instead of existing only as a tester `Print()` line.
2. `Get-TesterLogCurrentRunText` now accepts the expected expert, symbol, and
   date window. If the copied shared journal has no exact start marker, it
   returns no classifying text. The full journal remains archived, but an older
   run can no longer drive `ONINIT_FAILED` for the current item.

Files changed:

- `framework/include/QM/QM_Common.mqh`
- `framework/scripts/run_smoke.ps1`
- `tools/strategy_farm/tests/test_framework_init_diagnostics.py`

## Verification

- PowerShell parser on `run_smoke.ps1`: PASS.
- `Test-CompileOneIncludeTargets.ps1`: PASS.
- Focused pytest set covering framework-init diagnostics, Q02 evidence binding,
  and factory canary behavior: 15 tests selected after the final assertion
  correction.
- `git diff --check` on the three implementation/test files: PASS (Git emitted
  only the repository's normal LF-to-CRLF working-copy notices).

No terminal was started manually, no T1-T10 run was interrupted, and T_Live /
AutoTrading were untouched. The task explicitly forbids an agent requeue, and
there was no pending QM5_10038 work item that could supply a factory-owned
claim. Consequently no new smoke row was invented. A governed smoke must
follow reviewer acceptance, a current-resolver rebuild, and an explicitly
authorized append-only successor; pipeline verdict authority remains with the
resulting pipeline evidence.
