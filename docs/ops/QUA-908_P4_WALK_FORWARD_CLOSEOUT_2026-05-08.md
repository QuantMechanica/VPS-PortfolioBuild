# QUA-908 Closeout — P4 Walk-Forward Driver

Date: 2026-05-08  
Issue: QUA-908  
Owner: CTO

## Deliverable

Implemented `framework/scripts/p4_walk_forward.py` and wired supporting artifacts for deterministic P4 gate execution.

## Acceptance mapping

- 6 folds across 2017-2022: enforced (`>=6`, coverage start/end checks).
- DEV->HO embargo check: enforced per fold (`dev_end < oos_start`).
- Fold consistency aggregation: enforced (anchored window checks and monotonic fold progression).
- Verdict CSV/JSON consumed by classifiers:
  - JSON: `P4_<ea>_result.json`
  - CSV: `report.csv`
  - log: `phase_runner_log.jsonl`
- Docs updated with exact command:
  - `docs/ops/06 Infrastructure/Tools and Scripts.md`
  - `docs/ops/03 Pipeline/P4 Walk-Forward.md`

## Commit evidence

- Commit: `1c552848`
- Message: `QUA-908: add P4 walk-forward runner and docs`

## Verification evidence

- Command:
  - `python -m unittest framework/scripts/tests/test_p4_walk_forward.py framework/scripts/tests/test_phase_runners_idempotence.py`
- Result: `OK` (2 tests passed)

## Touched files

- `framework/scripts/p4_walk_forward.py`
- `framework/scripts/tests/fixtures/p4_walk_forward.csv`
- `framework/scripts/tests/test_p4_walk_forward.py`
- `framework/scripts/tests/test_phase_runners_idempotence.py`
- `framework/scripts/phase_orchestrator.py`
- `framework/scripts/README.md`
- `docs/ops/03 Pipeline/P4 Walk-Forward.md`
