# P4 Walk-Forward

## Runner

- Script: `framework/scripts/p4_walk_forward.py`
- Gate checks:
  - minimum 6 folds
  - 2017-2022 coverage
  - anchored fold structure
  - DEV->HO embargo
  - regime labels present
  - explicit clean OOS evidence

## Exact command

```bash
python framework/scripts/p4_walk_forward.py --ea QM5_1001 --walk-forward-csv framework/scripts/tests/fixtures/p4_walk_forward.csv
```

## Evidence artifacts

- `D:/QM/reports/pipeline/<ea>/P4/P4_<ea>_result.json`
- `D:/QM/reports/pipeline/<ea>/P4/report.csv`
- `D:/QM/reports/pipeline/<ea>/P4/phase_runner_log.jsonl`
