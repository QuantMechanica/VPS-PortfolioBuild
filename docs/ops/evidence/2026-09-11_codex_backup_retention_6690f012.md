# Codex backup-retention closeout — 2026-09-11

Task: `6690f012-162c-44ce-830a-6da8d165245d`

## Result

The existing `QM_StrategyFarm_ContinuousRetention_45min` single-pass runner now
rotates only `D:/QM/strategy_farm/state/backups/farm_state_before_*.sqlite`.
It retains every matching snapshot newer than 24 hours plus the newest five
overall. The live `farm_state.sqlite` and non-matching SQLite files are not
eligible. The scheduled retention path was reused; no scheduled task was
created.

Applied run: `20260911T083906Z`

- DB `PRAGMA quick_check`: `ok`
- Deleted: 18 files, 13,271,830,528 bytes (12.36 GiB decimal display)
- Retained: 15 matching snapshots
- Pre-delete archive list and receipt:
  `D:/QM/reports/state/continuous_retention/20260911T083906Z/20260911T083906Z_backup_delete.json`
- Every receipt entry contains name, byte size, mtime, and SHA-256 captured
  before the atomic quarantine move and unlink.
- No work-item evidence, live DB, custom history, terminal, T_Live, or
  AutoTrading state was touched.

## Top D: consumers

Read-only recursive file-size measurement at closeout:

| rank | path | bytes | GiB |
|---:|---|---:|---:|
| 1 | `D:/QM/mt5` | 958,983,591,572 | 893.12 |
| 2 | `D:/QM/strategy_farm` | 190,339,420,765 | 177.27 |
| 3 | `D:/QM/reports` | 82,684,218,895 | 77.01 |
| 4 | `D:/QM/archive` | 44,231,653,718 | 41.19 |
| 5 | `D:/QM/data` | 3,157,197,108 | 2.94 |
| 6 | `D:/QM/tmp` | 2,173,825,705 | 2.02 |
| 7 | `D:/QM/venvs` | 444,123,196 | 0.41 |
| 8 | `D:/QM/ftmo` | 259,460,212 | 0.24 |
| 9 | `D:/QM/exports` | 129,216,896 | 0.12 |
| 10 | `D:/QM/scratch` | 85,441,042 | 0.08 |

## Verification

- `python -m pytest tools/strategy_farm/tests/test_continuous_retention_runner.py -q`
  → `10 passed`
- The retention runner completed with `status=PASS` and `free_after=70.47 GiB`.
